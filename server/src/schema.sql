-- schema.sql
-- Author: David M. Anderson
-- Built with AI assistance (Claude, Anthropic)

CREATE TABLE settings (
    key   TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE users (
    id           TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    is_bot       INTEGER NOT NULL DEFAULT 0,
    created_at   INTEGER NOT NULL
);

CREATE TABLE devices (
    id             TEXT PRIMARY KEY,
    user_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    api_token_hash TEXT NOT NULL UNIQUE,
    apns_token     TEXT,
    apns_env       TEXT CHECK (apns_env IN ('sandbox', 'production')),
    created_at     INTEGER NOT NULL,
    updated_at     INTEGER NOT NULL
);

CREATE TABLE invites (
    code_hash   TEXT PRIMARY KEY,
    created_at  INTEGER NOT NULL,
    expires_at  INTEGER NOT NULL,
    redeemed_by TEXT REFERENCES users(id) ON DELETE SET NULL,
    redeemed_at INTEGER
);

CREATE TABLE groups (
    id         TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE group_members (
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (group_id, user_id)
);

CREATE TABLE clips (
    id                TEXT PRIMARY KEY,
    sender_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sender_device_id  TEXT REFERENCES devices(id) ON DELETE SET NULL,
    recipient_user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    group_id          TEXT REFERENCES groups(id) ON DELETE CASCADE,
    duration_ms       INTEGER NOT NULL,
    created_at        INTEGER NOT NULL,
    expires_at        INTEGER NOT NULL,
    CHECK ((recipient_user_id IS NULL) <> (group_id IS NULL))
);

CREATE INDEX clips_by_recipient ON clips(recipient_user_id);
CREATE INDEX clips_by_group ON clips(group_id);
CREATE INDEX clips_by_sender ON clips(sender_id);
CREATE INDEX clips_by_device ON clips(sender_device_id, created_at);
CREATE INDEX clips_by_expiry ON clips(expires_at);

CREATE TABLE clip_receipts (
    clip_id   TEXT NOT NULL REFERENCES clips(id) ON DELETE CASCADE,
    user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    played_at INTEGER NOT NULL,
    PRIMARY KEY (clip_id, user_id)
);

-- A recipient who deleted a clip; its audio goes once every recipient has.
CREATE TABLE clip_deletions (
    clip_id    TEXT NOT NULL REFERENCES clips(id) ON DELETE CASCADE,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    deleted_at INTEGER NOT NULL,
    PRIMARY KEY (clip_id, user_id)
);
