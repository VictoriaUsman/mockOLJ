-- =============================================================================
-- Centralized Property Management Data System
-- Schema: Hostaway · OpenPhone · Gmail · Discord
--
-- Design notes:
--   SCD Type 2 — guests and properties are slowly-changing dimensions.
--     Each row represents one version of a record. When a field changes
--     (e.g., guest updates their email), the old row is expired
--     (valid_to set, is_current = 0) and a new row is inserted.
--     Stable natural/business keys (guest_key, property_key) stay the same
--     across all versions, enabling cross-version queries.
--
--   Surrogate keys (id INTEGER PK AUTOINCREMENT) are version-specific.
--     Operational tables (reservations, SMS, calls) reference the surrogate
--     that was current at the time of the event — this preserves the exact
--     snapshot of who the guest was when an interaction occurred.
--
--   Cascading — child operational records cascade-delete when their parent
--     is removed (e.g., deleting a call removes its transcript lines;
--     deleting a reservation removes its Hostaway conversation thread).
--     Dimension FKs (guest, property) are RESTRICT to prevent orphaning
--     reservation history when expiring SCD versions.
--
--   Partial unique indexes enforce the SCD Type 2 "only one active version"
--     rule at the database level (WHERE is_current = 1).
-- =============================================================================

PRAGMA foreign_keys = ON;

-- -----------------------------------------------------------------------------
-- DIMENSION: GUESTS  (SCD Type 2)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS guests (
    id              INTEGER  PRIMARY KEY AUTOINCREMENT,  -- surrogate key (version-specific)
    guest_key       TEXT     NOT NULL,                   -- stable business key, e.g. 'G-001'
    first_name      TEXT     NOT NULL,
    last_name       TEXT     NOT NULL,
    primary_email   TEXT,
    primary_phone   TEXT,                                -- E.164 format, e.g. +14155557821
    valid_from      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_to        DATETIME,                            -- NULL = this is the active version
    is_current      INTEGER  NOT NULL DEFAULT 1 CHECK(is_current IN (0, 1)),
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Guarantees exactly one active version per guest at the DB level
CREATE UNIQUE INDEX IF NOT EXISTS ux_guests_one_active
    ON guests(guest_key) WHERE is_current = 1;

-- Convenience view: always returns the live guest record
CREATE VIEW IF NOT EXISTS current_guests AS
    SELECT * FROM guests WHERE is_current = 1;

-- -----------------------------------------------------------------------------
-- DIMENSION: PROPERTIES  (SCD Type 2)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS properties (
    id                      INTEGER  PRIMARY KEY AUTOINCREMENT,
    property_key            TEXT     NOT NULL,           -- stable business key, e.g. 'PROP-001'
    name                    TEXT     NOT NULL,           -- e.g. "Cottage 3"
    address                 TEXT,
    hostaway_property_id    TEXT,                        -- Hostaway's platform ID (same across versions)
    valid_from              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_to                DATETIME,
    is_current              INTEGER  NOT NULL DEFAULT 1 CHECK(is_current IN (0, 1)),
    created_at              DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_properties_one_active
    ON properties(property_key) WHERE is_current = 1;

-- Partial unique index: Hostaway ID is globally unique among active properties
CREATE UNIQUE INDEX IF NOT EXISTS ux_properties_hostaway_active
    ON properties(hostaway_property_id) WHERE is_current = 1 AND hostaway_property_id IS NOT NULL;

CREATE VIEW IF NOT EXISTS current_properties AS
    SELECT * FROM properties WHERE is_current = 1;

-- -----------------------------------------------------------------------------
-- RESERVATIONS (from Hostaway)
-- References surrogate guest_id and property_id — captures the exact versions
-- that were active when the reservation was created (historical accuracy).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reservations (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    hostaway_reservation_id TEXT    UNIQUE,
    guest_id                INTEGER NOT NULL
                                REFERENCES guests(id)
                                ON DELETE RESTRICT
                                ON UPDATE RESTRICT,
    property_id             INTEGER NOT NULL
                                REFERENCES properties(id)
                                ON DELETE RESTRICT
                                ON UPDATE RESTRICT,
    check_in                DATE    NOT NULL,
    check_out               DATE    NOT NULL,
    status                  TEXT    NOT NULL DEFAULT 'confirmed'
                                    CHECK(status IN ('inquiry','confirmed','checked_in','checked_out','cancelled')),
    channel                 TEXT,              -- booking source: 'airbnb', 'vrbo', 'direct', etc.
    total_amount            REAL,
    notes                   TEXT,
    created_at              DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- HOSTAWAY — Conversations & Messages
-- Cascades: deleting a reservation removes its conversations;
--           deleting a conversation removes its messages.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hostaway_conversations (
    id                          INTEGER PRIMARY KEY AUTOINCREMENT,
    hostaway_conversation_id    TEXT    UNIQUE,
    reservation_id              INTEGER
                                    REFERENCES reservations(id)
                                    ON DELETE CASCADE
                                    ON UPDATE CASCADE,
    channel                     TEXT,
    created_at                  DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS hostaway_messages (
    id              INTEGER  PRIMARY KEY AUTOINCREMENT,
    conversation_id INTEGER  NOT NULL
                                REFERENCES hostaway_conversations(id)
                                ON DELETE CASCADE
                                ON UPDATE CASCADE,
    sender_type     TEXT     NOT NULL CHECK(sender_type IN ('host', 'guest', 'system')),
    body            TEXT     NOT NULL,
    sent_at         DATETIME NOT NULL
);

-- -----------------------------------------------------------------------------
-- OPENPHONE — Calls, Transcripts, SMS
-- Cascades: deleting a call removes its transcript lines.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS openphone_calls (
    id                  INTEGER  PRIMARY KEY AUTOINCREMENT,
    openphone_call_id   TEXT     UNIQUE,
    guest_id            INTEGER
                            REFERENCES guests(id)
                            ON DELETE SET NULL
                            ON UPDATE CASCADE,
    guest_phone         TEXT     NOT NULL,
    our_phone           TEXT     NOT NULL,
    direction           TEXT     NOT NULL CHECK(direction IN ('inbound', 'outbound')),
    duration_seconds    INTEGER,
    started_at          DATETIME NOT NULL,
    ended_at            DATETIME,
    recording_url       TEXT,
    summary             TEXT
);

CREATE TABLE IF NOT EXISTS openphone_call_transcripts (
    id                          INTEGER  PRIMARY KEY AUTOINCREMENT,
    call_id                     INTEGER  NOT NULL
                                            REFERENCES openphone_calls(id)
                                            ON DELETE CASCADE
                                            ON UPDATE CASCADE,
    speaker                     TEXT     NOT NULL DEFAULT 'unknown'
                                         CHECK(speaker IN ('host', 'guest', 'unknown')),
    text                        TEXT     NOT NULL,
    timestamp_offset_seconds    INTEGER
);

CREATE TABLE IF NOT EXISTS openphone_sms_messages (
    id                  INTEGER  PRIMARY KEY AUTOINCREMENT,
    openphone_sms_id    TEXT     UNIQUE,
    guest_id            INTEGER
                            REFERENCES guests(id)
                            ON DELETE SET NULL
                            ON UPDATE CASCADE,
    guest_phone         TEXT     NOT NULL,
    our_phone           TEXT     NOT NULL,
    direction           TEXT     NOT NULL CHECK(direction IN ('inbound', 'outbound')),
    body                TEXT     NOT NULL,
    sent_at             DATETIME NOT NULL
);

-- -----------------------------------------------------------------------------
-- GMAIL — Threads & Emails
-- Cascade: deleting a thread removes all its email messages.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gmail_threads (
    id              INTEGER  PRIMARY KEY AUTOINCREMENT,
    gmail_thread_id TEXT     UNIQUE NOT NULL,
    subject         TEXT,
    guest_id        INTEGER
                        REFERENCES guests(id)
                        ON DELETE SET NULL
                        ON UPDATE CASCADE,
    reservation_id  INTEGER
                        REFERENCES reservations(id)
                        ON DELETE SET NULL
                        ON UPDATE CASCADE,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS gmail_emails (
    id                  INTEGER  PRIMARY KEY AUTOINCREMENT,
    gmail_message_id    TEXT     UNIQUE NOT NULL,
    thread_id           INTEGER  NOT NULL
                                    REFERENCES gmail_threads(id)
                                    ON DELETE CASCADE
                                    ON UPDATE CASCADE,
    from_email          TEXT     NOT NULL,
    to_email            TEXT     NOT NULL,
    cc_email            TEXT,
    subject             TEXT,
    body_text           TEXT,
    sent_at             DATETIME NOT NULL,
    labels              TEXT     -- JSON array, e.g. '["inbox","reservation"]'
);

-- -----------------------------------------------------------------------------
-- DISCORD — Channels & Messages
-- Cascade: deleting a channel removes all its messages.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS discord_channels (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    discord_channel_id  TEXT    UNIQUE NOT NULL,
    channel_name        TEXT    NOT NULL,
    server_name         TEXT,
    property_id         INTEGER
                            REFERENCES properties(id)
                            ON DELETE SET NULL
                            ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS discord_messages (
    id                  INTEGER  PRIMARY KEY AUTOINCREMENT,
    discord_message_id  TEXT     UNIQUE NOT NULL,
    channel_id          INTEGER  NOT NULL
                                    REFERENCES discord_channels(id)
                                    ON DELETE CASCADE
                                    ON UPDATE CASCADE,
    author_username     TEXT     NOT NULL,
    author_display_name TEXT,
    content             TEXT     NOT NULL,
    sent_at             DATETIME NOT NULL,
    reservation_id      INTEGER
                            REFERENCES reservations(id)
                            ON DELETE SET NULL
                            ON UPDATE CASCADE
);

-- -----------------------------------------------------------------------------
-- UNIFIED COMMUNICATIONS VIEW
-- Flattens all four sources into a single queryable timeline.
--
-- Includes guest_key (stable, cross-version) alongside guest_id (surrogate,
-- version-specific). Consumers should filter by guest_key when they want all
-- interactions with a guest across SCD versions; filter by guest_id when they
-- need the exact snapshot linked to a specific event.
-- -----------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS unified_communications AS

    -- Hostaway messages (linked via reservation → guest)
    SELECT
        'hostaway'      AS source,
        hm.id           AS source_row_id,
        hm.sent_at,
        hm.body         AS content,
        hm.sender_type  AS direction,
        g.guest_key,
        r.guest_id,
        r.property_id,
        r.id            AS reservation_id
    FROM hostaway_messages hm
    JOIN hostaway_conversations hc ON hm.conversation_id = hc.id
    JOIN reservations r            ON hc.reservation_id  = r.id
    JOIN guests g                  ON r.guest_id          = g.id

UNION ALL

    -- OpenPhone SMS
    SELECT
        'openphone_sms' AS source,
        sms.id,
        sms.sent_at,
        sms.body,
        sms.direction,
        g.guest_key,
        sms.guest_id,
        NULL            AS property_id,
        NULL            AS reservation_id
    FROM openphone_sms_messages sms
    LEFT JOIN guests g ON sms.guest_id = g.id

UNION ALL

    -- OpenPhone calls (one summary row per call)
    SELECT
        'openphone_call' AS source,
        c.id,
        c.started_at,
        COALESCE(c.summary,
            c.direction || ' call · ' || c.duration_seconds || 's') AS content,
        c.direction,
        g.guest_key,
        c.guest_id,
        NULL,
        NULL
    FROM openphone_calls c
    LEFT JOIN guests g ON c.guest_id = g.id

UNION ALL

    -- Gmail
    SELECT
        'gmail'         AS source,
        ge.id,
        ge.sent_at,
        '[' || ge.subject || '] ' || COALESCE(ge.body_text, '') AS content,
        CASE WHEN ge.from_email = 'host@propertymgmt.com' THEN 'outbound'
             ELSE 'inbound' END AS direction,
        g.guest_key,
        gt.guest_id,
        NULL            AS property_id,
        gt.reservation_id
    FROM gmail_emails ge
    JOIN gmail_threads gt ON ge.thread_id = gt.id
    LEFT JOIN guests g    ON gt.guest_id  = g.id

UNION ALL

    -- Discord (property-level, no guest_id)
    SELECT
        'discord'       AS source,
        dm.id,
        dm.sent_at,
        '@' || dm.author_display_name || ': ' || dm.content AS content,
        'internal'      AS direction,
        NULL            AS guest_key,
        NULL            AS guest_id,
        dc.property_id,
        dm.reservation_id
    FROM discord_messages dm
    JOIN discord_channels dc ON dm.channel_id = dc.id;

-- -----------------------------------------------------------------------------
-- INDEXES
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_guests_guest_key          ON guests(guest_key);
CREATE INDEX IF NOT EXISTS idx_guests_valid_from         ON guests(valid_from);
CREATE INDEX IF NOT EXISTS idx_properties_property_key   ON properties(property_key);
CREATE INDEX IF NOT EXISTS idx_reservations_check_in     ON reservations(check_in);
CREATE INDEX IF NOT EXISTS idx_reservations_guest_id     ON reservations(guest_id);
CREATE INDEX IF NOT EXISTS idx_reservations_property_id  ON reservations(property_id);
CREATE INDEX IF NOT EXISTS idx_sms_guest_id              ON openphone_sms_messages(guest_id);
CREATE INDEX IF NOT EXISTS idx_calls_guest_id            ON openphone_calls(guest_id);
CREATE INDEX IF NOT EXISTS idx_discord_msgs_channel      ON discord_messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_discord_msgs_sent_at      ON discord_messages(sent_at);
CREATE INDEX IF NOT EXISTS idx_gmail_threads_guest       ON gmail_threads(guest_id);
