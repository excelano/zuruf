<?php
// accounts.php
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

declare(strict_types=1);

// Unambiguous characters only, since codes are typed on a watch.
const INVITE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const INVITE_LENGTH = 10;

function newInviteCode(): string {
    $code = '';
    for ($i = 0; $i < INVITE_LENGTH; $i++) {
        $code .= INVITE_ALPHABET[random_int(0, strlen(INVITE_ALPHABET) - 1)];
    }
    return $code;
}

function normalizeInviteCode(string $code): string {
    return preg_replace('/[^A-Z0-9]/', '', strtoupper($code));
}

function createInvite(int $ttlDays): array {
    $code = newInviteCode();
    $now = time();
    $expiresAt = $now + $ttlDays * 86400;
    query(
        'INSERT INTO invites (code_hash, created_at, expires_at) VALUES (?, ?, ?)',
        [tokenHash($code), $now, $expiresAt]
    );
    return ['code' => substr($code, 0, 5) . '-' . substr($code, 5), 'expires_at' => $expiresAt];
}

function isReviewCode(string $code): bool {
    return REVIEW_INVITE_CODE !== '' && hash_equals(normalizeInviteCode(REVIEW_INVITE_CODE), $code);
}

function redeemInvite(array $body): never {
    $code = normalizeInviteCode((string)($body['code'] ?? ''));
    $codeHash = tokenHash($code);
    $name = textField($body, 'display_name', 40);
    $now = time();
    $userId = randomId();
    $deviceId = randomId();
    $token = bin2hex(random_bytes(32));

    $db = getDb();
    $db->beginTransaction();
    query('INSERT INTO users (id, display_name, created_at) VALUES (?, ?, ?)', [$userId, $name, $now]);
    $claimed = isReviewCode($code) || query(
        'UPDATE invites SET redeemed_by = ?, redeemed_at = ? WHERE code_hash = ? AND redeemed_at IS NULL AND expires_at > ?',
        [$userId, $now, $codeHash, $now]
    )->rowCount() === 1;
    if (!$claimed) {
        $db->rollBack();
        fail(403, 'invalid_invite');
    }
    query(
        'INSERT INTO devices (id, user_id, api_token_hash, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [$deviceId, $userId, tokenHash($token), $now, $now]
    );
    $db->commit();

    respond(201, [
        'user_id' => $userId,
        'device_id' => $deviceId,
        'token' => $token,
        'server_id' => serverId(),
    ]);
}

// Gives the paired watch or phone its own device under the same account, from
// the credentials the other one passed it.
function linkDevice(array $device): never {
    $deviceId = randomId();
    $token = bin2hex(random_bytes(32));
    $now = time();
    query(
        'INSERT INTO devices (id, user_id, api_token_hash, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [$deviceId, $device['user_id'], tokenHash($token), $now, $now]
    );
    respond(201, [
        'user_id' => $device['user_id'],
        'device_id' => $deviceId,
        'token' => $token,
        'server_id' => serverId(),
    ]);
}

function updateDevice(array $device, array $body): never {
    $apnsToken = strtolower((string)($body['apns_token'] ?? ''));
    $apnsEnv = (string)($body['apns_env'] ?? '');
    $platform = (string)($body['platform'] ?? 'watchos');
    if (!preg_match('/^[0-9a-f]{64,200}$/', $apnsToken)) {
        fail(422, 'invalid_apns_token');
    }
    if (!in_array($apnsEnv, ['sandbox', 'production'], true)) {
        fail(422, 'invalid_apns_env');
    }
    if (!in_array($platform, ['watchos', 'ios'], true)) {
        fail(422, 'invalid_platform');
    }

    // A watch that redeems a second invite keeps its APNs token; only the newest device row should receive pushes.
    query('UPDATE devices SET apns_token = NULL WHERE apns_token = ? AND id <> ?', [$apnsToken, $device['id']]);
    query(
        'UPDATE devices SET apns_token = ?, apns_env = ?, platform = ?, updated_at = ? WHERE id = ?',
        [$apnsToken, $apnsEnv, $platform, time(), $device['id']]
    );
    respond(200, ['device_id' => $device['id']]);
}

// Removes the user, their devices and every clip sent by or to them.
function deleteUser(string $userId): bool {
    $clipIds = query(
        'SELECT id FROM clips WHERE sender_id = ? OR recipient_user_id = ?', [$userId, $userId]
    )->fetchAll(PDO::FETCH_COLUMN);
    if (query('DELETE FROM users WHERE id = ?', [$userId])->rowCount() === 0) {
        return false;
    }
    deleteClipFiles($clipIds);
    return true;
}

function deleteAccount(array $device): never {
    deleteUser($device['user_id']);
    respond(200, ['deleted' => $device['user_id']]);
}

function listContacts(array $device): never {
    echoBotId();
    $users = query(
        'SELECT id, display_name, is_bot FROM users WHERE id <> ? ORDER BY display_name COLLATE NOCASE',
        [$device['user_id']]
    )->fetchAll();
    $groups = query(
        'SELECT g.id, g.name FROM groups g JOIN group_members m ON m.group_id = g.id
         WHERE m.user_id = ? ORDER BY g.name COLLATE NOCASE',
        [$device['user_id']]
    )->fetchAll();
    foreach ($groups as &$group) {
        $group['member_ids'] = query('SELECT user_id FROM group_members WHERE group_id = ?', [$group['id']])
            ->fetchAll(PDO::FETCH_COLUMN);
    }
    unset($group);

    respond(200, [
        'users' => array_map(fn($u) => [
            'id' => $u['id'],
            'display_name' => $u['display_name'],
            'is_bot' => (bool)$u['is_bot'],
        ], $users),
        'groups' => $groups,
    ]);
}
