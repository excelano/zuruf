#!/usr/bin/env bash
# smoke.sh
# Author: David M. Anderson
# Built with AI assistance (Claude, Anthropic)
#
# Runs the API end to end on PHP's built-in server with a throwaway data
# directory. Needs php (pdo_sqlite, openssl), curl, jq and ffmpeg.
set -euo pipefail

server=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
port=${PORT:-8099}
base=http://127.0.0.1:$port
admin=test-admin-token
failures=0

export ZURUF_CONFIG=$server/tests/config.php ZURUF_DATA_DIR=$work/data ZURUF_REVIEW_CODE=REVIEW-2026
php -S 127.0.0.1:$port -t "$server/public" "$server/public/index.php" > "$work/server.log" 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null; rm -rf "$work"' EXIT
sleep 0.5

ffmpeg -loglevel error -f lavfi -i sine=frequency=440:duration=3 -ac 1 -c:a aac "$work/short.m4a"
ffmpeg -loglevel error -f lavfi -i sine=frequency=440:duration=62 -ac 1 -c:a aac -b:a 16k "$work/long.m4a"
echo "not audio" > "$work/bogus.m4a"

# call METHOD PATH TOKEN [curl args...]: prints the body, leaves the status in $status.
call() {
    local method=$1 path=$2 token=$3
    shift 3
    local out
    out=$(curl -s -w '\n%{http_code}' -X "$method" ${token:+-H "Authorization: Bearer $token"} "$@" "$base$path")
    status=${out##*$'\n'}
    body=${out%$'\n'*}
}

json() { call "$1" "$2" "$3" -H 'Content-Type: application/json' -d "$4"; }

expect() {
    local want=$1 label=$2
    if [[ $status == "$want" ]]; then
        echo "ok   $label"
    else
        echo "FAIL $label: expected $want, got $status: $body"
        failures=$((failures + 1))
    fi
}

check() {
    local label=$1 condition=$2
    if jq -e "$condition" <<< "$body" > /dev/null; then
        echo "ok   $label"
    else
        echo "FAIL $label: $condition on $body"
        failures=$((failures + 1))
    fi
}

json POST /v1/admin/invites "" '{}'
expect 401 "admin endpoints require the admin token"

json POST /v1/admin/invites $admin '{}'
expect 201 "create invite"
alice_code=$(jq -r .code <<< "$body")
json POST /v1/admin/invites $admin '{"expires_days": 2}'
bob_code=$(jq -r .code <<< "$body")

json POST /v1/invites/redeem "" "{\"code\": \"${alice_code,,}\", \"display_name\": \"Alice\"}"
expect 201 "redeem invite, code case and dash ignored"
alice=$(jq -r .token <<< "$body")
alice_id=$(jq -r .user_id <<< "$body")
check "redeem returns a server id" '.server_id | test("^[0-9a-f]{32}$")'

json POST /v1/invites/redeem "" "{\"code\": \"$alice_code\", \"display_name\": \"Mallory\"}"
expect 403 "invite is single-use"
json POST /v1/invites/redeem "" '{"code": "AAAAA-AAAAA", "display_name": "Mallory"}'
expect 403 "unknown invite"
json POST /v1/invites/redeem "" '{"code": "review-2026", "display_name": "Reviewer"}'
expect 201 "the review code redeems"
first_reviewer=$(jq -r .token <<< "$body")
json POST /v1/invites/redeem "" '{"code": "REVIEW-2026", "display_name": "Second reviewer"}'
expect 201 "the review code redeems again"
second_reviewer=$(jq -r .token <<< "$body")
call DELETE /v1/account $first_reviewer
call DELETE /v1/account $second_reviewer
json POST /v1/invites/redeem "" "{\"code\": \"$bob_code\", \"display_name\": \"\"}"
expect 422 "display name required"

json POST /v1/invites/redeem "" "{\"code\": \"$bob_code\", \"display_name\": \"Bob\"}"
bob=$(jq -r .token <<< "$body")
bob_id=$(jq -r .user_id <<< "$body")

call GET /v1/contacts ""
expect 401 "contacts require a token"
call GET /v1/contacts bogus-token
expect 401 "unknown token"
call PUT /v1/contacts $alice
expect 405 "wrong method"
call GET /v1/nothing $alice
expect 404 "unknown path"

json POST /v1/devices $alice "{\"apns_token\": \"$(printf 'ab%.0s' {1..32})\", \"apns_env\": \"sandbox\"}"
expect 200 "register APNs token"
json POST /v1/devices $alice '{"apns_token": "xyz", "apns_env": "sandbox"}'
expect 422 "reject malformed APNs token"
json POST /v1/devices $alice "{\"apns_token\": \"$(printf 'ab%.0s' {1..32})\", \"apns_env\": \"staging\"}"
expect 422 "reject unknown APNs environment"

call GET /v1/contacts $alice
expect 200 "list contacts"
check "contacts are Bob and the echo bot" '[.users[].display_name] == ["Bob", "Echo"]'
echo_id=$(jq -r '.users[] | select(.is_bot) | .id' <<< "$body")

call POST /v1/clips $alice -F "to_user=$bob_id" -F "audio=@$work/short.m4a"
expect 201 "upload clip"
check "duration read from the file" '.duration_ms > 2900 and .duration_ms < 3200'
clip=$(jq -r .id <<< "$body")

call POST /v1/clips $alice -F "to_user=$bob_id" -F "audio=@$work/bogus.m4a"
expect 415 "reject a file that is not m4a"
call POST /v1/clips $alice -F "to_user=$bob_id" -F "audio=@$work/long.m4a"
expect 422 "reject a clip over 60 seconds"
call POST /v1/clips $alice -F "audio=@$work/short.m4a"
expect 422 "recipient required"
call POST /v1/clips $alice -F "to_user=$alice_id" -F "audio=@$work/short.m4a"
expect 404 "cannot send to yourself"

call GET /v1/clips $bob
check "Bob has one unplayed clip from Alice" '.received | length == 1 and .[0].sender_name == "Alice" and .[0].played_at == null'
call GET "/v1/clips/$clip/audio" $bob -o "$work/fetched.m4a"
expect 200 "recipient downloads audio"
cmp -s "$work/short.m4a" "$work/fetched.m4a" && echo "ok   audio bytes match" || { echo "FAIL audio bytes differ"; failures=$((failures + 1)); }
call GET "/v1/clips/$clip/audio" $alice
expect 404 "sender cannot download"

call POST "/v1/clips/$clip/played" $bob
expect 200 "mark played"
call GET /v1/clips $alice
check "Alice sees Bob's played receipt" ".sent[0].played_by[0].user_id == \"$bob_id\""

call DELETE "/v1/clips/$clip" $alice
expect 404 "sender cannot delete a sent clip"
call DELETE "/v1/clips/$clip" $bob
expect 200 "recipient deletes a clip"
call GET /v1/clips $bob
check "the deleted clip leaves Bob's inbox" ".received | all(.id != \"$clip\")"
call GET "/v1/clips/$clip/audio" $bob
expect 404 "deleted clip's audio is gone for Bob"
[[ ! -e "$work/data/clips/$clip.m4a" ]] && echo "ok   the last recipient's delete removes the audio" || { echo "FAIL deleted clip's audio remains"; failures=$((failures + 1)); }
call GET /v1/clips $alice
check "Alice still sees the clip in Sent" ".sent | any(.id == \"$clip\")"

json POST /v1/admin/groups $admin '{"name": "Family"}'
expect 201 "create group"
group=$(jq -r .id <<< "$body")
call POST /v1/clips $alice -F "to_group=$group" -F "audio=@$work/short.m4a"
expect 404 "non-member cannot send to a group"
json POST "/v1/admin/groups/$group/members" $admin "{\"user_id\": \"$alice_id\"}"
json POST "/v1/admin/groups/$group/members" $admin "{\"user_id\": \"$bob_id\"}"
expect 200 "add group members"
call POST /v1/clips $alice -F "to_group=$group" -F "audio=@$work/short.m4a"
expect 201 "send to group"
group_clip=$(jq -r .id <<< "$body")
call GET /v1/clips $bob
check "Bob receives the group clip" ".received[0].id == \"$group_clip\" and .received[0].group_name == \"Family\""
call GET /v1/contacts $bob
check "group listed with members" '.groups[0].name == "Family" and (.groups[0].member_ids | length == 2)'

call POST /v1/clips $alice -F "to_user=$echo_id" -F "audio=@$work/short.m4a"
expect 201 "send to echo bot"
call GET /v1/clips $alice
check "echo bot replied to Alice" '.received | any(.sender_name == "Echo")'

for _ in 1 2 3 4 5 6; do call POST /v1/clips $bob -F "to_user=$alice_id" -F "audio=@$work/short.m4a"; done
expect 201 "uploads under the rate limit"
for _ in 1 2 3 4; do call POST /v1/clips $bob -F "to_user=$alice_id" -F "audio=@$work/short.m4a"; done
call POST /v1/clips $bob -F "to_user=$alice_id" -F "audio=@$work/short.m4a"
expect 429 "eleventh upload in a minute is rate limited"

sqlite3 "$work/data/zuruf.db" "UPDATE clips SET expires_at = 0 WHERE id = '$clip'"
call GET "/v1/clips/$clip/audio" $bob
expect 404 "expired clip is gone"
php "$server/cron.php" > /dev/null
[[ ! -e "$work/data/clips/$clip.m4a" ]] && echo "ok   cron deletes expired clip files" || { echo "FAIL expired file remains"; failures=$((failures + 1)); }

json POST /v1/admin/invites $admin '{}'
carol_code=$(jq -r .code <<< "$body")
json POST /v1/invites/redeem "" "{\"code\": \"$carol_code\", \"display_name\": \"Carol\"}"
carol=$(jq -r .token <<< "$body")
carol_id=$(jq -r .user_id <<< "$body")
call POST /v1/clips $carol -F "to_user=$alice_id" -F "audio=@$work/short.m4a"
carol_clip=$(jq -r .id <<< "$body")
call DELETE /v1/account $carol
expect 200 "delete own account"
call GET /v1/contacts $carol
expect 401 "deleted account's token stops working"
[[ ! -e "$work/data/clips/$carol_clip.m4a" ]] && echo "ok   deleting an account deletes its clip files" || { echo "FAIL clip file remains after account deletion"; failures=$((failures + 1)); }
call GET /v1/contacts $alice
check "deleted account leaves the contact list" "[.users[].id] | index(\"$carol_id\") == null"

call DELETE "/v1/admin/groups/$group/members/$bob_id" $admin
expect 200 "remove group member"
json PATCH "/v1/admin/groups/$group" $admin '{"name": "Crew"}'
expect 200 "rename group"
call GET /v1/contacts $alice
check "the group has its new name" '.groups[0].name == "Crew"'
json PATCH "/v1/admin/groups/$group" $admin '{"name": ""}'
expect 422 "group name required"
json PATCH "/v1/admin/groups/$(printf '0%.0s' {1..32})" $admin '{"name": "Nobody"}'
expect 404 "rename unknown group"
call DELETE "/v1/admin/groups/$group" $admin
expect 200 "delete group"
[[ ! -e "$work/data/clips/$group_clip.m4a" ]] && echo "ok   deleting a group deletes its clip files" || { echo "FAIL group clip file remains"; failures=$((failures + 1)); }
call GET /v1/contacts $alice
check "the deleted group leaves the contact list" '.groups == []'
call DELETE "/v1/admin/groups/$group" $admin
expect 404 "delete unknown group"
call DELETE "/v1/admin/users/$bob_id" $admin
expect 200 "delete user"
call GET /v1/contacts $bob
expect 401 "deleted user's token stops working"

if grep -q -i -E "fatal|warning|deprecated|notice" "$work/server.log"; then
    echo "FAIL PHP reported problems:"
    grep -i -E "fatal|warning|deprecated|notice" "$work/server.log"
    failures=$((failures + 1))
fi

echo
[[ $failures == 0 ]] && echo "all checks passed" || { echo "$failures failed"; exit 1; }
