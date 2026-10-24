<?php
// clips.php
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

declare(strict_types=1);

function clipPath(string $id): string {
    return DATA_DIR . '/clips/' . $id . '.m4a';
}

function findClip(string $id): ?array {
    $clip = query('SELECT * FROM clips WHERE id = ? AND expires_at > ?', [$id, time()])->fetch();
    return $clip ?: null;
}

function clipRecipientIds(array $clip): array {
    if ($clip['recipient_user_id'] !== null) {
        return [$clip['recipient_user_id']];
    }
    return query(
        'SELECT user_id FROM group_members WHERE group_id = ? AND user_id <> ?',
        [$clip['group_id'], $clip['sender_id']]
    )->fetchAll(PDO::FETCH_COLUMN);
}

// Reads the movie duration from the mvhd box, so the length limit does not
// depend on what the client claims.
function m4aDurationMs(string $path): ?int {
    $data = file_get_contents($path);
    if ($data === false || substr($data, 4, 4) !== 'ftyp') {
        return null;
    }
    $at = strpos($data, 'mvhd');
    if ($at === false || strlen($data) < $at + 40) {
        return null;
    }
    $fields = ord($data[$at + 4]) === 1
        ? unpack('Ntimescale/Jduration', substr($data, $at + 24, 12))
        : unpack('Ntimescale/Nduration', substr($data, $at + 16, 8));
    if ($fields['timescale'] === 0) {
        return null;
    }
    return intdiv($fields['duration'] * 1000, $fields['timescale']);
}

function storeClip(string $senderId, ?string $senderDeviceId, ?string $toUser, ?string $toGroup, int $durationMs): string {
    $id = randomId();
    $now = time();
    query(
        'INSERT INTO clips (id, sender_id, sender_device_id, recipient_user_id, group_id, duration_ms, created_at, expires_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [$id, $senderId, $senderDeviceId, $toUser, $toGroup, $durationMs, $now, $now + CLIP_TTL_DAYS * 86400]
    );
    return $id;
}

function createClip(array $device): never {
    $file = $_FILES['audio'] ?? null;
    if ($file === null && (int)($_SERVER['CONTENT_LENGTH'] ?? 0) > 0 && empty($_POST)) {
        fail(413, 'too_large');
    }
    if ($file === null || is_array($file['error'])) {
        fail(400, 'audio_missing');
    }
    if (in_array($file['error'], [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true) || $file['size'] > MAX_CLIP_BYTES) {
        fail(413, 'too_large');
    }
    if ($file['error'] !== UPLOAD_ERR_OK) {
        fail(400, 'audio_missing');
    }
    $durationMs = m4aDurationMs($file['tmp_name']);
    if ($durationMs === null) {
        fail(415, 'not_m4a');
    }
    // Encoders pad the last AAC frame, so allow a little over the limit.
    if ($durationMs > MAX_CLIP_SECONDS * 1000 + 500) {
        fail(422, 'too_long');
    }

    $senderId = $device['user_id'];
    $toUser = isset($_POST['to_user']) ? idField($_POST, 'to_user') : null;
    $toGroup = isset($_POST['to_group']) ? idField($_POST, 'to_group') : null;
    if (($toUser === null) === ($toGroup === null)) {
        fail(422, 'one_recipient_required');
    }
    if ($toUser !== null && ($toUser === $senderId || !query('SELECT 1 FROM users WHERE id = ?', [$toUser])->fetch())) {
        fail(404, 'unknown_recipient');
    }
    if ($toGroup !== null && !query(
        'SELECT 1 FROM group_members WHERE group_id = ? AND user_id = ?', [$toGroup, $senderId]
    )->fetch()) {
        fail(404, 'unknown_recipient');
    }

    $recent = (int)query(
        'SELECT COUNT(*) FROM clips WHERE sender_device_id = ? AND created_at > ?',
        [$device['id'], time() - 60]
    )->fetchColumn();
    if ($recent >= UPLOADS_PER_MINUTE) {
        fail(429, 'rate_limited');
    }

    $id = storeClip($senderId, $device['id'], $toUser, $toGroup, $durationMs);
    @mkdir(DATA_DIR . '/clips', 0700, true);
    if (!move_uploaded_file($file['tmp_name'], clipPath($id))) {
        query('DELETE FROM clips WHERE id = ?', [$id]);
        fail(500, 'store_failed');
    }
    chmod(clipPath($id), 0600);

    $clip = findClip($id);
    send(201, clipJson($clip));
    finishRequest();
    pushClip($clip);
    if ($toUser !== null && $toUser === echoBotId()) {
        echoClip($clip);
    }
    exit;
}

function clipJson(array $clip): array {
    return [
        'id' => $clip['id'],
        'sender_id' => $clip['sender_id'],
        'to_user' => $clip['recipient_user_id'],
        'to_group' => $clip['group_id'],
        'duration_ms' => (int)$clip['duration_ms'],
        'created_at' => (int)$clip['created_at'],
        'expires_at' => (int)$clip['expires_at'],
    ];
}

function listClips(array $device): never {
    $me = $device['user_id'];
    $now = time();
    $received = query(
        'SELECT c.*, u.display_name AS sender_name, g.name AS group_name, r.played_at
         FROM clips c
         JOIN users u ON u.id = c.sender_id
         LEFT JOIN groups g ON g.id = c.group_id
         LEFT JOIN clip_receipts r ON r.clip_id = c.id AND r.user_id = :me
         WHERE c.expires_at > :now AND c.sender_id <> :me
           AND (c.recipient_user_id = :me OR c.group_id IN (SELECT group_id FROM group_members WHERE user_id = :me))
           AND NOT EXISTS (SELECT 1 FROM clip_deletions d WHERE d.clip_id = c.id AND d.user_id = :me)
         ORDER BY c.created_at DESC, c.rowid DESC LIMIT 100',
        ['me' => $me, 'now' => $now]
    )->fetchAll();
    $sent = query(
        'SELECT * FROM clips WHERE sender_id = :me AND expires_at > :now ORDER BY created_at DESC, rowid DESC LIMIT 100',
        ['me' => $me, 'now' => $now]
    )->fetchAll();
    $receipts = query(
        'SELECT r.clip_id, r.user_id, r.played_at FROM clip_receipts r JOIN clips c ON c.id = r.clip_id
         WHERE c.sender_id = :me AND c.expires_at > :now',
        ['me' => $me, 'now' => $now]
    )->fetchAll();
    $playedBy = [];
    foreach ($receipts as $receipt) {
        $playedBy[$receipt['clip_id']][] = ['user_id' => $receipt['user_id'], 'played_at' => (int)$receipt['played_at']];
    }

    respond(200, [
        'received' => array_map(fn($c) => clipJson($c) + [
            'sender_name' => $c['sender_name'],
            'group_name' => $c['group_name'],
            'played_at' => $c['played_at'] === null ? null : (int)$c['played_at'],
        ], $received),
        'sent' => array_map(fn($c) => clipJson($c) + ['played_by' => $playedBy[$c['id']] ?? []], $sent),
    ]);
}

function requireAudibleClip(array $device, string $id): array {
    $clip = findClip($id);
    if ($clip === null || !in_array($device['user_id'], clipRecipientIds($clip), true) || query(
        'SELECT 1 FROM clip_deletions WHERE clip_id = ? AND user_id = ?', [$id, $device['user_id']]
    )->fetch()) {
        fail(404, 'not_found');
    }
    return $clip;
}

// Served to its recipients and to its sender, whose phone transcribes it.
function streamClipAudio(array $device, string $id): never {
    $clip = findClip($id);
    if ($clip === null || $clip['sender_id'] !== $device['user_id']) {
        $clip = requireAudibleClip($device, $id);
    }
    $path = clipPath($clip['id']);
    if (!is_file($path)) {
        fail(404, 'not_found');
    }
    header('Content-Type: audio/mp4');
    header('Content-Length: ' . filesize($path));
    header('Cache-Control: private, no-store');
    readfile($path);
    exit;
}

function markPlayed(array $device, string $id): never {
    $clip = requireAudibleClip($device, $id);
    query(
        'INSERT OR IGNORE INTO clip_receipts (clip_id, user_id, played_at) VALUES (?, ?, ?)',
        [$clip['id'], $device['user_id'], time()]
    );
    $playedAt = query(
        'SELECT played_at FROM clip_receipts WHERE clip_id = ? AND user_id = ?', [$clip['id'], $device['user_id']]
    )->fetchColumn();
    respond(200, ['played_at' => (int)$playedAt]);
}

// Removes the clip from this recipient's inbox. The sender keeps it in Sent
// until it expires, but its audio is deleted once every recipient has deleted it.
function deleteReceivedClip(array $device, string $id): never {
    $clip = requireAudibleClip($device, $id);
    query(
        'INSERT INTO clip_deletions (clip_id, user_id, deleted_at) VALUES (?, ?, ?)',
        [$clip['id'], $device['user_id'], time()]
    );
    $deletedBy = query('SELECT user_id FROM clip_deletions WHERE clip_id = ?', [$clip['id']])->fetchAll(PDO::FETCH_COLUMN);
    if (array_diff(clipRecipientIds($clip), $deletedBy) === []) {
        deleteClipFiles([$clip['id']]);
    }
    respond(200, ['deleted' => $clip['id']]);
}

function deleteClipFiles(array $ids): void {
    foreach ($ids as $id) {
        @unlink(clipPath($id));
    }
}

function deleteExpiredClips(): int {
    $now = time();
    $ids = query('SELECT id FROM clips WHERE expires_at <= ?', [$now])->fetchAll(PDO::FETCH_COLUMN);
    deleteClipFiles($ids);
    query('DELETE FROM clips WHERE expires_at <= ?', [$now]);
    return count($ids);
}
