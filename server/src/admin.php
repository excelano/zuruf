<?php
// admin.php
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

declare(strict_types=1);

function adminCreateInvite(array $body): never {
    $days = (int)($body['expires_days'] ?? INVITE_TTL_DAYS);
    if ($days < 1 || $days > 30) {
        fail(422, 'invalid_expires_days');
    }
    respond(201, createInvite($days));
}

function adminListUsers(): never {
    $users = query(
        'SELECT u.id, u.display_name, u.is_bot, u.created_at, COUNT(d.id) AS devices, MAX(d.updated_at) AS last_seen
         FROM users u LEFT JOIN devices d ON d.user_id = u.id
         GROUP BY u.id ORDER BY u.display_name COLLATE NOCASE'
    )->fetchAll();
    $groups = query('SELECT id, name FROM groups ORDER BY name COLLATE NOCASE')->fetchAll();
    foreach ($groups as &$group) {
        $group['member_ids'] = query('SELECT user_id FROM group_members WHERE group_id = ?', [$group['id']])
            ->fetchAll(PDO::FETCH_COLUMN);
    }
    unset($group);
    respond(200, ['users' => $users, 'groups' => $groups]);
}

function adminDeleteUser(string $userId): never {
    $clipIds = query(
        'SELECT id FROM clips WHERE sender_id = ? OR recipient_user_id = ?', [$userId, $userId]
    )->fetchAll(PDO::FETCH_COLUMN);
    if (query('DELETE FROM users WHERE id = ?', [$userId])->rowCount() === 0) {
        fail(404, 'not_found');
    }
    deleteClipFiles($clipIds);
    respond(200, ['deleted' => $userId]);
}

function adminCreateGroup(array $body): never {
    $id = randomId();
    query('INSERT INTO groups (id, name, created_at) VALUES (?, ?, ?)', [$id, textField($body, 'name', 40), time()]);
    respond(201, ['id' => $id]);
}

function adminAddMember(string $groupId, array $body): never {
    $userId = idField($body, 'user_id');
    if (!query('SELECT 1 FROM groups WHERE id = ?', [$groupId])->fetch()
        || !query('SELECT 1 FROM users WHERE id = ?', [$userId])->fetch()) {
        fail(404, 'not_found');
    }
    query('INSERT OR IGNORE INTO group_members (group_id, user_id) VALUES (?, ?)', [$groupId, $userId]);
    respond(200, ['group_id' => $groupId, 'user_id' => $userId]);
}

function adminRemoveMember(string $groupId, string $userId): never {
    query('DELETE FROM group_members WHERE group_id = ? AND user_id = ?', [$groupId, $userId]);
    respond(200, ['group_id' => $groupId, 'user_id' => $userId]);
}
