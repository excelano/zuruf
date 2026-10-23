<?php
// config.php
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

define('ADMIN_TOKEN', 'test-admin-token');
define('APNS_TEAM_ID', 'TEAMID');
define('APNS_APPS', [
    'watchos' => [
        'topic' => 'com.example.zuruf.watchkitapp',
        'keys' => ['sandbox' => ['id' => '', 'path' => ''], 'production' => ['id' => '', 'path' => '']],
    ],
    'ios' => [
        'topic' => 'com.example.zuruf',
        'keys' => ['sandbox' => ['id' => '', 'path' => ''], 'production' => ['id' => '', 'path' => '']],
    ],
]);
define('DATA_DIR', getenv('ZURUF_DATA_DIR'));
define('MAX_CLIP_SECONDS', 60);
define('MAX_CLIP_BYTES', 2_000_000);
define('CLIP_TTL_DAYS', 7);
define('INVITE_TTL_DAYS', 7);
define('REVIEW_INVITE_CODE', getenv('ZURUF_REVIEW_CODE') ?: '');
define('UPLOADS_PER_MINUTE', 10);
define('ECHO_BOT_ENABLED', true);
define('ECHO_DELAY_SECONDS', 1);
define('REQUIRE_HTTPS', false);
