# Zuruf

Zuruf is a walkie-talkie for Apple Watch: hold a button, say something, and it plays on the other person's wrist a moment later, over Wi-Fi or cellular at any distance. It replaces Apple's Walkie-Talkie app for a family or another small group, and it needs no iPhone app. Each group runs its own small server, so clips pass through nothing but that server and Apple's push service, which carries only a short alert.

Messages are stored and forwarded rather than streamed. The watch records a clip and uploads it, the server sends a push to everyone it is addressed to, and each watch downloads the clip and plays it as the notification arrives. Clips can go to one person or to a group, the sender sees who has played them, and the server deletes them after a set number of days.

Zuruf is invite-only. An account comes from a single-use invite code that the server's operator creates, so an app build is useless without an invitation to a server. Push notifications reach only an app signed by the developer account that holds the APNs key, which is why a group that wants its own server also builds its own copy of the app.

This repository holds the watch app, in `watch/`, and the server, in `server/`.

## The watch app

The app is watch-only SwiftUI with a notification service extension. Joining takes the server's address, an invite code and a display name. From then on the app lists the people and groups on the server; choosing one opens a talk button that records while it is held and sends on release, keeping a clip on the watch and retrying until the server accepts it. A notification service extension downloads each incoming clip before its alert appears, and the notification plays it as soon as it shows, unless Play automatically is turned off in Settings or the watch is on silent, in which case the notification's Play button plays it. The inbox keeps recent clips for replay, with a reply to the sender or the group, and shows who has played each clip you sent.

The identity a fork changes, meaning the team id, the bundle id, the display name and the default server, lives in `watch/Config/Zuruf.xcconfig`, and the version in `watch/Config/Version.xcconfig`.

## The server

The server is a small PHP application backed by SQLite, written to run on ordinary cPanel shared hosting with nothing to keep running between requests. It needs PHP with the `pdo_sqlite`, `curl` and `openssl` extensions, and a curl built with HTTP/2, which APNs requires. This prints `true` when the host's curl qualifies:

```bash
php -r 'var_dump((bool)(curl_version()["features"] & CURL_VERSION_HTTP2));'
```

```
server/public/       The document root: index.php routes every request.
server/src/          Accounts and invites, clips, the APNs sender, the echo bot, admin.
server/cron.php      Hourly cleanup of expired clips and invites.
server/config.php    Your settings, copied from config.example.php. Never committed.
server/keys/         Your APNs keys. Never committed.
server/data/         The database and clip files, created on first request.
```

Only `public/` is reachable from the web. Everything else sits beside it, so the configuration, keys, database and audio stay outside the web root without depending on rewrite rules.

## Running your own

You need an Apple Developer account, and your own build of the watch app with your identity in `Zuruf.xcconfig`. In Certificates, Identifiers & Profiles, register an App ID for the watch app with Push Notifications enabled, then create an APNs key for each environment, restricted to that App ID's topic. Development builds installed from Xcode use the sandbox key; TestFlight and App Store builds use the production key. Apple lets you download each `.p8` file once.

Point a hostname's document root at `server/public/` and upload the `server/` directory. If your host will not move a document root, upload the contents of `public/` into the document root it gave you and the rest of `server/` into a folder named `zuruf-server` beside it; `index.php` looks there when it finds no server beside itself. The server must sit at the root of its hostname, and it refuses plain HTTP. Copy `config.example.php` to `config.php`, fill in your team id, the watch app's bundle id, both key ids, and a long random admin token, and put the `.p8` files in `keys/`. Then add an hourly cron job:

```bash
php /path/to/server/cron.php
```

The admin token manages the server through its `/v1/admin` endpoints. Create an invite for each person and give them the code:

```bash
curl -s -X POST https://zuruf.example.com/v1/admin/invites \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H 'Content-Type: application/json' -d '{}'
```

Groups are created and filled the same way, from `/v1/admin/groups` and `/v1/admin/groups/{id}/members`, and `/v1/admin/users` lists who has joined. The built-in Echo contact sends back any clip it receives, which makes it the quickest check that recording, upload, push and playback all work. Set `ECHO_BOT_ENABLED` to false to hide it.

## Testing

`server/tests/smoke.sh` runs the API end to end against PHP's built-in server with a throwaway database, and needs `curl`, `jq` and `ffmpeg` besides PHP. It does not send pushes; those are checked on a real watch.

## License

MIT. See [LICENSE](LICENSE).
