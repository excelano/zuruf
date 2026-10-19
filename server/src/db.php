<?php
// db.php
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

declare(strict_types=1);

function getDb(): PDO {
    static $db = null;
    if ($db !== null) {
        return $db;
    }

    $path = DATA_DIR . '/zuruf.db';
    $isNew = !file_exists($path);
    @mkdir(DATA_DIR, 0700, true);
    $db = new PDO('sqlite:' . $path);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $db->exec('PRAGMA journal_mode=WAL');
    $db->exec('PRAGMA foreign_keys=ON');
    $db->exec('PRAGMA busy_timeout=5000');

    if ($isNew) {
        $db->exec(file_get_contents(dirname(__DIR__) . '/src/schema.sql'));
    }

    return $db;
}

function query(string $sql, array $params = []): PDOStatement {
    $stmt = getDb()->prepare($sql);
    $stmt->execute($params);
    return $stmt;
}

function getSetting(string $key): ?string {
    $value = query('SELECT value FROM settings WHERE key = ?', [$key])->fetchColumn();
    return $value === false ? null : $value;
}

function setSetting(string $key, string $value): void {
    query(
        'INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        [$key, $value]
    );
}

function randomId(): string {
    return bin2hex(random_bytes(16));
}

function tokenHash(string $token): string {
    return hash('sha256', $token);
}

function serverId(): string {
    $id = getSetting('server_id');
    if ($id === null) {
        $id = randomId();
        setSetting('server_id', $id);
    }
    return $id;
}
