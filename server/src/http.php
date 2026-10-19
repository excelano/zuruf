<?php
// http.php
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

declare(strict_types=1);

function send(int $status, array $body): void {
    http_response_code($status);
    header('Content-Type: application/json');
    header('Cache-Control: no-store');
    echo json_encode($body, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
}

function respond(int $status, array $body = []): never {
    send($status, $body);
    exit;
}

function fail(int $status, string $error): never {
    respond($status, ['error' => $error]);
}

// Lets work that follows a response, such as pushes, run without the client waiting.
function finishRequest(): void {
    ignore_user_abort(true);
    if (function_exists('litespeed_finish_request')) {
        litespeed_finish_request();
    } elseif (function_exists('fastcgi_finish_request')) {
        fastcgi_finish_request();
    } else {
        flush();
    }
}

function isHttps(): bool {
    return ($_SERVER['HTTPS'] ?? '') === 'on'
        || ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https';
}

function requestPath(): string {
    return parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
}

function bearerToken(): ?string {
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    return preg_match('/^Bearer\s+(\S+)$/i', $header, $match) ? $match[1] : null;
}

function jsonBody(): array {
    $body = json_decode(file_get_contents('php://input') ?: '', true);
    if (!is_array($body)) {
        fail(400, 'invalid_json');
    }
    return $body;
}

function requireDevice(): array {
    $token = bearerToken();
    $device = $token === null ? false : query(
        'SELECT d.*, u.display_name FROM devices d JOIN users u ON u.id = d.user_id WHERE d.api_token_hash = ?',
        [tokenHash($token)]
    )->fetch();
    if (!$device) {
        fail(401, 'unauthorized');
    }
    return $device;
}

function requireAdmin(): void {
    $token = bearerToken();
    if (ADMIN_TOKEN === '' || $token === null || !hash_equals(ADMIN_TOKEN, $token)) {
        fail(401, 'unauthorized');
    }
}

// A trimmed single-line string of 1 to $max characters, counted as UTF-8
// without mbstring.
function textField(array $body, string $key, int $max): string {
    $value = trim((string)($body[$key] ?? ''));
    if (!preg_match('/^[^\p{C}]{1,' . $max . '}$/u', $value)) {
        fail(422, 'invalid_' . $key);
    }
    return $value;
}

function idField(array $body, string $key): string {
    $value = (string)($body[$key] ?? '');
    if (!preg_match('/^[0-9a-f]{32}$/', $value)) {
        fail(422, 'invalid_' . $key);
    }
    return $value;
}
