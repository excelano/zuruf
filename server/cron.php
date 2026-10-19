<?php
// cron.php
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Run hourly from cPanel cron: php /path/to/server/cron.php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    exit(1);
}

require getenv('ZURUF_CONFIG') ?: __DIR__ . '/config.php';
require __DIR__ . '/src/db.php';
require __DIR__ . '/src/clips.php';

$clips = deleteExpiredClips();
$invites = query('DELETE FROM invites WHERE redeemed_at IS NULL AND expires_at <= ?', [time()])->rowCount();
echo date('c') . " deleted $clips expired clips and $invites expired invites\n";
