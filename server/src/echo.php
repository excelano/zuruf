<?php
// echo.php
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

declare(strict_types=1);

function echoBotId(): ?string {
    if (!ECHO_BOT_ENABLED) {
        return null;
    }
    $id = getSetting('echo_bot_user_id');
    if ($id !== null && query('SELECT 1 FROM users WHERE id = ?', [$id])->fetch()) {
        return $id;
    }
    $id = randomId();
    query('INSERT INTO users (id, display_name, is_bot, created_at) VALUES (?, ?, 1, ?)', [$id, 'Echo', time()]);
    setSetting('echo_bot_user_id', $id);
    return $id;
}

// Runs after the sender's upload response has been sent.
function echoClip(array $clip): void {
    $botId = echoBotId();
    sleep(ECHO_DELAY_SECONDS);
    query(
        'INSERT OR IGNORE INTO clip_receipts (clip_id, user_id, played_at) VALUES (?, ?, ?)',
        [$clip['id'], $botId, time()]
    );
    $replyId = storeClip($botId, null, $clip['sender_id'], null, (int)$clip['duration_ms']);
    if (!copy(clipPath($clip['id']), clipPath($replyId))) {
        query('DELETE FROM clips WHERE id = ?', [$replyId]);
        error_log("zuruf: echo of clip {$clip['id']} failed");
        return;
    }
    chmod(clipPath($replyId), 0600);
    pushClip(findClip($replyId));
}
