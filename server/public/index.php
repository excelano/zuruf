<?php
// index.php
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

declare(strict_types=1);

$root = dirname(__DIR__);
require getenv('ZURUF_CONFIG') ?: $root . '/config.php';
require $root . '/src/db.php';
require $root . '/src/http.php';
require $root . '/src/accounts.php';
require $root . '/src/clips.php';
require $root . '/src/apns.php';
require $root . '/src/echo.php';
require $root . '/src/admin.php';

header('X-Content-Type-Options: nosniff');
header_remove('X-Powered-By');

if (REQUIRE_HTTPS && !isHttps()) {
    fail(403, 'https_required');
}

$id = '([0-9a-f]{32})';
$routes = [
    ['POST', '/v1/invites/redeem', fn() => redeemInvite(jsonBody())],
    ['POST', '/v1/devices', fn() => updateDevice(requireDevice(), jsonBody())],
    ['GET', '/v1/contacts', fn() => listContacts(requireDevice())],
    ['POST', '/v1/clips', fn() => createClip(requireDevice())],
    ['GET', '/v1/clips', fn() => listClips(requireDevice())],
    ['GET', "/v1/clips/$id/audio", fn($clipId) => streamClipAudio(requireDevice(), $clipId)],
    ['POST', "/v1/clips/$id/played", fn($clipId) => markPlayed(requireDevice(), $clipId)],
    ['POST', '/v1/admin/invites', function () { requireAdmin(); adminCreateInvite(jsonBody()); }],
    ['GET', '/v1/admin/users', function () { requireAdmin(); adminListUsers(); }],
    ['DELETE', "/v1/admin/users/$id", function ($userId) { requireAdmin(); adminDeleteUser($userId); }],
    ['POST', '/v1/admin/groups', function () { requireAdmin(); adminCreateGroup(jsonBody()); }],
    ['POST', "/v1/admin/groups/$id/members", function ($groupId) { requireAdmin(); adminAddMember($groupId, jsonBody()); }],
    ['DELETE', "/v1/admin/groups/$id/members/$id", function ($groupId, $userId) {
        requireAdmin();
        adminRemoveMember($groupId, $userId);
    }],
];

$path = requestPath();
$pathMatched = false;
foreach ($routes as [$method, $pattern, $handler]) {
    if (!preg_match('#^' . $pattern . '$#', $path, $params)) {
        continue;
    }
    $pathMatched = true;
    if ($method === $_SERVER['REQUEST_METHOD']) {
        $handler(...array_slice($params, 1));
    }
}
fail($pathMatched ? 405 : 404, $pathMatched ? 'method_not_allowed' : 'not_found');
