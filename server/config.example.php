<?php
// config.example.php
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Copy to config.php beside this file and fill in the values for your server.
// config.php is outside the web root and never committed.

// Long random string that authorizes the /v1/admin endpoints.
define('ADMIN_TOKEN', '');

// Apple Developer team id and the watch app's bundle id (the APNs topic).
define('APNS_TEAM_ID', '');
define('APNS_TOPIC', 'com.example.zuruf.watchkitapp');

// One topic-specific APNs key per environment. Development builds installed
// from Xcode register sandbox tokens; TestFlight and App Store builds register
// production tokens. Leave an environment's id empty if you have no key for it.
define('APNS_KEYS', [
    'sandbox' => ['id' => '', 'path' => __DIR__ . '/keys/AuthKey_SANDBOX.p8'],
    'production' => ['id' => '', 'path' => __DIR__ . '/keys/AuthKey_PRODUCTION.p8'],
]);

// The database and clip files. Must not be under public/.
define('DATA_DIR', __DIR__ . '/data');

define('MAX_CLIP_SECONDS', 60);
define('MAX_CLIP_BYTES', 2_000_000);
define('CLIP_TTL_DAYS', 7);
define('INVITE_TTL_DAYS', 7);
define('UPLOADS_PER_MINUTE', 10);

// An invite code that never expires and can be redeemed any number of times,
// for a demo server such as the one App Review uses. Leave empty everywhere else.
define('REVIEW_INVITE_CODE', '');

// A built-in contact that sends every clip it receives back to its sender.
define('ECHO_BOT_ENABLED', true);
define('ECHO_DELAY_SECONDS', 3);

// Refuse plain HTTP. Turn off only for local testing.
define('REQUIRE_HTTPS', true);
