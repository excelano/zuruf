# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately through GitHub Security Advisories at https://github.com/excelano/zuruf/security/advisories/new. If you would rather not use GitHub, email david.anderson@excelano.com instead. I aim to respond within seven days.

Please do not open public issues for security problems.

## Supported versions

The Zuruf server is built from source and self-hosted by each operator. Security fixes ship through `main`; pull and redeploy to apply them. There are no maintained release branches.

## Security model

**Access comes only from an invitation.** There is no sign-up. An operator creates a single-use invite code that expires, and redeeming it creates an account and issues that watch an API token. Invite codes and API tokens are stored only as SHA-256 hashes, so the database alone cannot be used to sign in.

**A clip is readable only by the people it was sent to.** The audio endpoint serves a clip to its recipient, or to the members of its group, and to no one else, the sender included. Clip ids are random. Clip files live outside the web root and leave the server only through that authenticated endpoint.

**Clips do not last.** Each clip carries an expiry, the server stops serving it once that passes, and the hourly cron deletes the file and its record. Removing a user deletes their devices and every clip sent by or to them.

**Apple carries alerts, not audio.** A push holds the sender's name, the clip id and the server id. The watch fetches the audio from the server directly.

**Uploads are checked.** The server rejects files that are not MPEG-4 audio, reads the clip's length from the file rather than trusting the client, and enforces the size cap, the length cap and a per-device upload rate.

## Operator responsibilities

**Serve over HTTPS.** The server refuses plain HTTP, but the certificate is yours to keep valid.

**Keep the document root at `server/public/`.** That is what keeps `config.php`, the APNs keys, the database and the clip files off the web. Pointing the document root at `server/` would expose all of them.

**Guard the admin token and the APNs keys.** The admin token can create accounts and remove users. A topic-restricted APNs key can push only to your app, but it can push anything to every device that has registered with it.

**Hand out invites directly.** An invite code works for whoever types it first. Failed redemptions are not rate-limited; the code's length and short life are what make guessing impractical, so do not lengthen invite lifetimes beyond what you need.
