-- =============================================================================
-- Migration: v1 → v2
-- Applies to: property_data.db (existing v1 SQLite database)
-- Run ONCE on the existing database. For fresh builds, use schema.sql + seed_data.sql.
--
-- What this does:
--   1. Adds new columns to existing tables (ALTER TABLE ADD COLUMN)
--   2. Creates new tables (hostaway_listings, openphone_phone_numbers,
--      openphone_voicemails, whatsapp_*, detected_triggers, outbound_notifications)
--   3. Drops and recreates views (unified_communications now includes WhatsApp;
--      open_triggers and notification_log are new)
--   4. Creates new indexes
--   5. Backfills existing rows with reasonable defaults for new columns
--
-- SQLite note: ALTER TABLE ADD COLUMN does not support IF NOT EXISTS.
--   This script is idempotent only for CREATE TABLE/INDEX (IF NOT EXISTS).
--   The ALTER TABLE statements will error if run twice — use the schema_version
--   guard at the top to prevent re-running.
-- =============================================================================

PRAGMA foreign_keys = ON;

-- -----------------------------------------------------------------------------
-- VERSION GUARD
-- Sets PRAGMA user_version to 2 after migration. If already 2, stop.
-- Check before running: sqlite3 property_data.db "PRAGMA user_version;"
-- If result is 2, this migration has already been applied.
-- -----------------------------------------------------------------------------
-- To check:  sqlite3 property_data.db "PRAGMA user_version;"
-- To apply:  sqlite3 property_data.db < migrate_v2.sql

BEGIN TRANSACTION;

-- =============================================================================
-- STEP 1: ALTER TABLE — add new columns to existing tables
-- =============================================================================

-- guests: add Hostaway guest ID
ALTER TABLE guests ADD COLUMN hostaway_guest_id TEXT;

-- properties: add location and capacity fields from Hostaway listing
ALTER TABLE properties ADD COLUMN city            TEXT;
ALTER TABLE properties ADD COLUMN state           TEXT;
ALTER TABLE properties ADD COLUMN country         TEXT;
ALTER TABLE properties ADD COLUMN zipcode         TEXT;
ALTER TABLE properties ADD COLUMN lat             REAL;
ALTER TABLE properties ADD COLUMN lng             REAL;
ALTER TABLE properties ADD COLUMN person_capacity INTEGER;
ALTER TABLE properties ADD COLUMN bedrooms_number INTEGER;
ALTER TABLE properties ADD COLUMN bathrooms_number REAL;

-- reservations: add guest counts, financials, cancellation fields
ALTER TABLE reservations ADD COLUMN hostaway_listing_id TEXT;
ALTER TABLE reservations ADD COLUMN adults              INTEGER;
ALTER TABLE reservations ADD COLUMN children            INTEGER;
ALTER TABLE reservations ADD COLUMN infants             INTEGER;
ALTER TABLE reservations ADD COLUMN pets                INTEGER;
ALTER TABLE reservations ADD COLUMN base_rate           REAL;
ALTER TABLE reservations ADD COLUMN cleaning_fee        REAL;
ALTER TABLE reservations ADD COLUMN platform_fee        REAL;
ALTER TABLE reservations ADD COLUMN total_price         REAL;
ALTER TABLE reservations ADD COLUMN remaining_balance   REAL;
ALTER TABLE reservations ADD COLUMN cancellation_date   DATE;
ALTER TABLE reservations ADD COLUMN cancelled_by        TEXT;

-- hostaway_conversations: add Hostaway API fields
ALTER TABLE hostaway_conversations ADD COLUMN participant_id TEXT;
ALTER TABLE hostaway_conversations ADD COLUMN subject        TEXT;
ALTER TABLE hostaway_conversations ADD COLUMN updated_at     DATETIME;

-- hostaway_messages: add Hostaway API fields
ALTER TABLE hostaway_messages ADD COLUMN hostaway_msg_id TEXT;
ALTER TABLE hostaway_messages ADD COLUMN inserted_on     DATETIME;
ALTER TABLE hostaway_messages ADD COLUMN updated_at      DATETIME;

-- openphone_calls: add Quo API fields
ALTER TABLE openphone_calls ADD COLUMN openphone_phone_number_id TEXT;
ALTER TABLE openphone_calls ADD COLUMN openphone_user_id         TEXT;
ALTER TABLE openphone_calls ADD COLUMN status                    TEXT;
ALTER TABLE openphone_calls ADD COLUMN answered_at               DATETIME;
ALTER TABLE openphone_calls ADD COLUMN call_route                TEXT;
ALTER TABLE openphone_calls ADD COLUMN forwarded_from            TEXT;
ALTER TABLE openphone_calls ADD COLUMN forwarded_to              TEXT;
ALTER TABLE openphone_calls ADD COLUMN ai_handled                TEXT;
ALTER TABLE openphone_calls ADD COLUMN updated_at                DATETIME;

-- openphone_call_transcripts: add segment timing and speaker detail
ALTER TABLE openphone_call_transcripts ADD COLUMN transcript_status TEXT;
ALTER TABLE openphone_call_transcripts ADD COLUMN speaker_phone     TEXT;
ALTER TABLE openphone_call_transcripts ADD COLUMN speaker_user_id   TEXT;
ALTER TABLE openphone_call_transcripts ADD COLUMN start_seconds     REAL;
ALTER TABLE openphone_call_transcripts ADD COLUMN end_seconds       REAL;

-- openphone_sms_messages: add delivery status and Quo IDs
ALTER TABLE openphone_sms_messages ADD COLUMN openphone_phone_number_id TEXT;
ALTER TABLE openphone_sms_messages ADD COLUMN openphone_user_id         TEXT;
ALTER TABLE openphone_sms_messages ADD COLUMN status                    TEXT;
ALTER TABLE openphone_sms_messages ADD COLUMN updated_at                DATETIME;

-- =============================================================================
-- STEP 2: CREATE NEW TABLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS hostaway_listings (
    id                      INTEGER  PRIMARY KEY AUTOINCREMENT,
    hostaway_listing_id     TEXT     UNIQUE NOT NULL,
    property_key            TEXT,
    name                    TEXT,
    internal_listing_name   TEXT,
    external_listing_name   TEXT,
    description             TEXT,
    address                 TEXT,
    city                    TEXT,
    state                   TEXT,
    country                 TEXT,
    country_code            TEXT,
    zipcode                 TEXT,
    lat                     REAL,
    lng                     REAL,
    person_capacity         INTEGER,
    bedrooms_number         INTEGER,
    beds_number             INTEGER,
    bathrooms_number        REAL,
    guest_bathrooms_number  REAL,
    price                   REAL,
    cleaning_fee            REAL,
    price_for_extra_person  REAL,
    weekly_discount         REAL,
    monthly_discount        REAL,
    min_nights              INTEGER,
    max_nights              INTEGER,
    cancellation_policy     TEXT,
    check_in_time_start     INTEGER,
    check_in_time_end       INTEGER,
    check_out_time          INTEGER,
    property_rent_tax       REAL,
    guest_stay_tax          REAL,
    guest_nightly_tax       REAL,
    instant_bookable        INTEGER  CHECK(instant_bookable IN (0, 1)),
    allow_same_day_booking  INTEGER  CHECK(allow_same_day_booking IN (0, 1)),
    amenities_json          TEXT,
    bed_types_json          TEXT,
    is_archived             INTEGER  NOT NULL DEFAULT 0 CHECK(is_archived IN (0, 1)),
    last_synced_at          DATETIME,
    created_at              DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS openphone_phone_numbers (
    id                      INTEGER  PRIMARY KEY AUTOINCREMENT,
    openphone_number_id     TEXT     UNIQUE NOT NULL,
    phone_number            TEXT     NOT NULL,
    label                   TEXT,
    property_id             INTEGER  REFERENCES properties(id) ON DELETE SET NULL,
    created_at              DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS openphone_voicemails (
    id                  INTEGER  PRIMARY KEY AUTOINCREMENT,
    call_id             INTEGER  NOT NULL UNIQUE
                                    REFERENCES openphone_calls(id)
                                    ON DELETE CASCADE
                                    ON UPDATE CASCADE,
    voicemail_status    TEXT     CHECK(voicemail_status IN (
                                    'pending', 'completed', 'failed', 'absent'
                                )),
    transcript          TEXT,
    duration_seconds    INTEGER,
    recording_url       TEXT,
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
    processed_at        DATETIME
);

CREATE TABLE IF NOT EXISTS whatsapp_conversations (
    id                          INTEGER  PRIMARY KEY AUTOINCREMENT,
    whatsapp_conversation_id    TEXT     UNIQUE,
    guest_id                    INTEGER  REFERENCES guests(id)
                                             ON DELETE SET NULL ON UPDATE CASCADE,
    guest_phone                 TEXT     NOT NULL,
    our_phone                   TEXT     NOT NULL,
    created_at                  DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_message_at             DATETIME
);

CREATE TABLE IF NOT EXISTS whatsapp_messages (
    id                      INTEGER  PRIMARY KEY AUTOINCREMENT,
    whatsapp_msg_id         TEXT     UNIQUE NOT NULL,
    conversation_id         INTEGER  NOT NULL
                                        REFERENCES whatsapp_conversations(id)
                                        ON DELETE CASCADE ON UPDATE CASCADE,
    direction               TEXT     NOT NULL CHECK(direction IN ('inbound', 'outbound')),
    body                    TEXT,
    media_url               TEXT,
    media_type              TEXT,
    status                  TEXT     CHECK(status IN ('sent', 'delivered', 'read', 'failed')),
    sent_at                 DATETIME NOT NULL,
    delivered_at            DATETIME,
    read_at                 DATETIME
);

CREATE TABLE IF NOT EXISTS detected_triggers (
    id              INTEGER  PRIMARY KEY AUTOINCREMENT,
    detected_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    trigger_type    TEXT     NOT NULL
                             CHECK(trigger_type IN (
                                 'guest_complaint', 'maintenance_issue',
                                 'scheduling_problem', 'payment_issue',
                                 'checkin_issue', 'emergency',
                                 'positive_feedback', 'info_request', 'other'
                             )),
    severity        TEXT     NOT NULL DEFAULT 'medium'
                             CHECK(severity IN ('low', 'medium', 'high', 'critical')),
    source_platform TEXT     NOT NULL
                             CHECK(source_platform IN (
                                 'hostaway', 'openphone_sms', 'openphone_call',
                                 'openphone_voicemail', 'gmail', 'discord', 'whatsapp'
                             )),
    source_table    TEXT     NOT NULL,
    source_row_id   INTEGER  NOT NULL,
    reservation_id  INTEGER  REFERENCES reservations(id)  ON DELETE SET NULL,
    guest_id        INTEGER  REFERENCES guests(id)        ON DELETE SET NULL,
    property_id     INTEGER  REFERENCES properties(id)    ON DELETE SET NULL,
    raw_content     TEXT     NOT NULL,
    llm_reasoning   TEXT,
    llm_model       TEXT,
    llm_confidence  REAL,
    status          TEXT     NOT NULL DEFAULT 'open'
                             CHECK(status IN ('open', 'acknowledged', 'resolved', 'dismissed')),
    acknowledged_at DATETIME,
    resolved_at     DATETIME,
    resolved_by     TEXT
);

CREATE TABLE IF NOT EXISTS outbound_notifications (
    id                      INTEGER  PRIMARY KEY AUTOINCREMENT,
    trigger_id              INTEGER  REFERENCES detected_triggers(id) ON DELETE SET NULL,
    platform                TEXT     NOT NULL
                                     CHECK(platform IN (
                                         'openphone_sms', 'discord', 'whatsapp', 'gmail'
                                     )),
    recipient               TEXT     NOT NULL,
    message_body            TEXT     NOT NULL,
    initiated_by            TEXT     NOT NULL DEFAULT 'system'
                                     CHECK(initiated_by IN ('system', 'human')),
    status                  TEXT     NOT NULL DEFAULT 'pending'
                                     CHECK(status IN ('pending', 'sent', 'delivered', 'failed')),
    platform_message_id     TEXT,
    error_message           TEXT,
    reservation_id          INTEGER  REFERENCES reservations(id)  ON DELETE SET NULL,
    guest_id                INTEGER  REFERENCES guests(id)        ON DELETE SET NULL,
    property_id             INTEGER  REFERENCES properties(id)    ON DELETE SET NULL,
    queued_at               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sent_at                 DATETIME,
    delivered_at            DATETIME,
    updated_at              DATETIME
);

-- =============================================================================
-- STEP 3: DROP AND RECREATE VIEWS
-- unified_communications must include WhatsApp; open_triggers and
-- notification_log are new.
-- =============================================================================

DROP VIEW IF EXISTS unified_communications;
CREATE VIEW unified_communications AS

    SELECT 'hostaway' AS source, hm.id AS source_row_id, hm.sent_at,
           hm.body AS content, hm.sender_type AS direction,
           g.guest_key, r.guest_id, r.property_id, r.id AS reservation_id
    FROM hostaway_messages hm
    JOIN hostaway_conversations hc ON hm.conversation_id = hc.id
    JOIN reservations r            ON hc.reservation_id  = r.id
    JOIN guests g                  ON r.guest_id          = g.id

UNION ALL

    SELECT 'openphone_sms', sms.id, sms.sent_at, sms.body, sms.direction,
           g.guest_key, sms.guest_id, NULL, NULL
    FROM openphone_sms_messages sms
    LEFT JOIN guests g ON sms.guest_id = g.id

UNION ALL

    SELECT 'openphone_call', c.id, c.started_at,
           COALESCE(c.summary, c.direction || ' call · ' || c.duration_seconds || 's'),
           c.direction, g.guest_key, c.guest_id, NULL, NULL
    FROM openphone_calls c
    LEFT JOIN guests g ON c.guest_id = g.id

UNION ALL

    SELECT 'gmail', ge.id, ge.sent_at,
           '[' || ge.subject || '] ' || COALESCE(ge.body_text, ''),
           CASE WHEN ge.from_email = 'host@propertymgmt.com' THEN 'outbound' ELSE 'inbound' END,
           g.guest_key, gt.guest_id, NULL, gt.reservation_id
    FROM gmail_emails ge
    JOIN gmail_threads gt ON ge.thread_id = gt.id
    LEFT JOIN guests g    ON gt.guest_id  = g.id

UNION ALL

    SELECT 'discord', dm.id, dm.sent_at,
           '@' || dm.author_display_name || ': ' || dm.content,
           'internal', NULL, NULL, dc.property_id, dm.reservation_id
    FROM discord_messages dm
    JOIN discord_channels dc ON dm.channel_id = dc.id

UNION ALL

    SELECT 'whatsapp', wm.id, wm.sent_at, wm.body, wm.direction,
           g.guest_key, wc.guest_id, NULL, NULL
    FROM whatsapp_messages wm
    JOIN whatsapp_conversations wc ON wm.conversation_id = wc.id
    LEFT JOIN guests g             ON wc.guest_id         = g.id;

DROP VIEW IF EXISTS open_triggers;
CREATE VIEW open_triggers AS
    SELECT dt.id, dt.detected_at, dt.trigger_type, dt.severity,
           dt.source_platform, dt.status, dt.raw_content, dt.llm_reasoning,
           dt.llm_confidence,
           cg.first_name || ' ' || cg.last_name AS guest_name,
           cg.primary_phone                      AS guest_phone,
           cp.name                               AS property_name,
           r.check_in, r.check_out,
           (SELECT COUNT(*) FROM outbound_notifications n WHERE n.trigger_id = dt.id) AS notifications_sent
    FROM detected_triggers dt
    LEFT JOIN reservations r        ON dt.reservation_id = r.id
    LEFT JOIN guests g              ON dt.guest_id        = g.id
    LEFT JOIN current_guests cg     ON g.guest_key        = cg.guest_key
    LEFT JOIN properties p          ON dt.property_id     = p.id
    LEFT JOIN current_properties cp ON p.property_key     = cp.property_key
    WHERE dt.status IN ('open', 'acknowledged')
    ORDER BY
        CASE dt.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2
                         WHEN 'medium'   THEN 3 WHEN 'low'  THEN 4 END,
        dt.detected_at DESC;

DROP VIEW IF EXISTS notification_log;
CREATE VIEW notification_log AS
    SELECT n.id, n.queued_at, n.sent_at, n.platform, n.recipient,
           SUBSTR(n.message_body, 1, 100) AS message_preview,
           n.status, n.initiated_by, n.platform_message_id, n.error_message,
           dt.trigger_type, dt.severity,
           cg.first_name || ' ' || cg.last_name AS guest_name,
           cp.name                               AS property_name
    FROM outbound_notifications n
    LEFT JOIN detected_triggers dt  ON n.trigger_id   = dt.id
    LEFT JOIN guests g              ON n.guest_id      = g.id
    LEFT JOIN current_guests cg     ON g.guest_key     = cg.guest_key
    LEFT JOIN properties p          ON n.property_id   = p.id
    LEFT JOIN current_properties cp ON p.property_key  = cp.property_key
    ORDER BY n.queued_at DESC;

-- =============================================================================
-- STEP 4: NEW INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_listings_property_key   ON hostaway_listings(property_key);
CREATE INDEX IF NOT EXISTS idx_calls_started_at        ON openphone_calls(started_at);
CREATE INDEX IF NOT EXISTS idx_calls_status            ON openphone_calls(status);
CREATE INDEX IF NOT EXISTS idx_calls_direction         ON openphone_calls(direction);
CREATE INDEX IF NOT EXISTS idx_sms_sent_at             ON openphone_sms_messages(sent_at);
CREATE INDEX IF NOT EXISTS idx_sms_direction           ON openphone_sms_messages(direction);
CREATE INDEX IF NOT EXISTS idx_reservations_check_out  ON reservations(check_out);
CREATE INDEX IF NOT EXISTS idx_reservations_status     ON reservations(status);
CREATE INDEX IF NOT EXISTS idx_gmail_emails_sent_at    ON gmail_emails(sent_at);
CREATE INDEX IF NOT EXISTS idx_wa_conversations_guest  ON whatsapp_conversations(guest_id);
CREATE INDEX IF NOT EXISTS idx_wa_messages_sent_at     ON whatsapp_messages(sent_at);
CREATE INDEX IF NOT EXISTS idx_wa_messages_direction   ON whatsapp_messages(direction);
CREATE INDEX IF NOT EXISTS idx_transcripts_call_id     ON openphone_call_transcripts(call_id);
CREATE INDEX IF NOT EXISTS idx_triggers_status         ON detected_triggers(status);
CREATE INDEX IF NOT EXISTS idx_triggers_type           ON detected_triggers(trigger_type);
CREATE INDEX IF NOT EXISTS idx_triggers_severity       ON detected_triggers(severity);
CREATE INDEX IF NOT EXISTS idx_triggers_reservation    ON detected_triggers(reservation_id);
CREATE INDEX IF NOT EXISTS idx_triggers_detected_at    ON detected_triggers(detected_at);
CREATE INDEX IF NOT EXISTS idx_notifications_trigger   ON outbound_notifications(trigger_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status    ON outbound_notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_platform  ON outbound_notifications(platform);
CREATE INDEX IF NOT EXISTS idx_notifications_queued_at ON outbound_notifications(queued_at);

-- =============================================================================
-- STEP 5: BACKFILL EXISTING ROWS WITH REASONABLE DEFAULTS
-- =============================================================================

-- properties: backfill location and capacity from known data
UPDATE properties SET
    city='Big Bear Lake', state='CA', country='USA', zipcode='92315',
    lat=34.2439, lng=-116.9114,
    person_capacity=6, bedrooms_number=3, bathrooms_number=2.0
WHERE property_key = 'PROP-001';  -- Cottage 3

UPDATE properties SET
    city='Malibu', state='CA', country='USA', zipcode='90265',
    lat=34.0259, lng=-118.7798,
    person_capacity=8, bedrooms_number=4, bathrooms_number=3.0
WHERE property_key = 'PROP-002';  -- Beach House 1 (both v1 and v2)

UPDATE properties SET
    city='South Lake Tahoe', state='CA', country='USA', zipcode='96150',
    lat=38.9399, lng=-119.9772,
    person_capacity=6, bedrooms_number=3, bathrooms_number=2.0
WHERE property_key = 'PROP-003';  -- Mountain Cabin A

-- reservations: backfill guest counts and financials
-- R-1001 Marcus / Beach House 1 (7 nights × $185 + $150 cleaning + $95 Airbnb = $1,540)
UPDATE reservations SET
    adults=3, children=0, infants=0, pets=1,
    base_rate=1295.00, cleaning_fee=150.00, platform_fee=95.00,
    total_price=1540.00, remaining_balance=0.00,
    hostaway_listing_id='HA-002'
WHERE hostaway_reservation_id = 'R-1001';

-- R-1002 Emily / Mountain Cabin A (4 nights × $175 + $150 cleaning + $70 direct = $920)
UPDATE reservations SET
    adults=4, children=0, infants=0, pets=0,
    base_rate=700.00, cleaning_fee=150.00, platform_fee=70.00,
    total_price=920.00, remaining_balance=920.00,
    hostaway_listing_id='HA-003'
WHERE hostaway_reservation_id = 'R-1002';

-- R-1003 Sarah / Cottage 3 (5 nights × $200 + $150 cleaning + $100 VRBO = $1,250)
UPDATE reservations SET
    adults=2, children=0, infants=0, pets=0,
    base_rate=1000.00, cleaning_fee=150.00, platform_fee=100.00,
    total_price=1250.00, remaining_balance=1250.00,
    hostaway_listing_id='HA-001'
WHERE hostaway_reservation_id = 'R-1003';

-- R-1004 David / Beach House 1 (5 nights × $176 + $150 cleaning + $70 Airbnb = $1,100... but stored as $1100)
-- Actually: 5 × $176 = $880, + $150 cleaning + $70 fee = $1,100
UPDATE reservations SET
    adults=2, children=0, infants=0, pets=0,
    base_rate=880.00, cleaning_fee=150.00, platform_fee=70.00,
    total_price=1100.00, remaining_balance=0.00,
    hostaway_listing_id='HA-002'
WHERE hostaway_reservation_id = 'R-1004';

-- openphone_calls: backfill status and timestamps
UPDATE openphone_calls SET
    status='completed',
    answered_at='2026-01-30 15:30:08',
    call_route='phone-number',
    openphone_phone_number_id='PN-001'
WHERE openphone_call_id = 'OP-CALL-001';

UPDATE openphone_calls SET
    status='completed',
    answered_at='2026-02-19 10:15:06',
    call_route='phone-number',
    openphone_phone_number_id='PN-001'
WHERE openphone_call_id = 'OP-CALL-002';

-- openphone_sms_messages: backfill delivery status
-- Outbound messages: delivered. Inbound: no status (delivery from guest to us).
UPDATE openphone_sms_messages SET
    status='delivered',
    openphone_phone_number_id='PN-001'
WHERE direction = 'outbound';

UPDATE openphone_sms_messages SET
    openphone_phone_number_id='PN-001'
WHERE direction = 'inbound';

-- =============================================================================
-- STEP 6: INSERT NEW REFERENCE DATA
-- =============================================================================

-- Hostaway listings (one per active property)
INSERT OR IGNORE INTO hostaway_listings (
    hostaway_listing_id, property_key, name, internal_listing_name,
    address, city, state, country, country_code, zipcode, lat, lng,
    person_capacity, bedrooms_number, beds_number, bathrooms_number, guest_bathrooms_number,
    price, cleaning_fee, price_for_extra_person, min_nights, max_nights,
    cancellation_policy, check_in_time_start, check_in_time_end, check_out_time,
    instant_bookable, allow_same_day_booking,
    amenities_json, last_synced_at
) VALUES
    ('HA-001', 'PROP-001', 'Cottage 3', 'Cottage 3 — Big Bear Lake',
     '789 Lakeview Dr, Big Bear Lake, CA 92315',
     'Big Bear Lake', 'CA', 'USA', 'US', '92315', 34.2439, -116.9114,
     6, 3, 4, 2.0, 1.0,
     200.00, 150.00, 25.00, 2, 30,
     'moderate', 15, 20, 11,
     1, 0,
     '["WiFi","Hot Tub","BBQ Grill","Fire Pit","Lake View","Free Parking","Washer/Dryer","Full Kitchen","Pet Friendly"]',
     '2026-02-22 00:00:00'),

    ('HA-002', 'PROP-002', 'Beach House 1', 'Beach House 1 — Malibu',
     '125 Pacific Coast Hwy, Malibu, CA 90265',
     'Malibu', 'CA', 'USA', 'US', '90265', 34.0259, -118.7798,
     8, 4, 6, 3.0, 2.0,
     220.00, 175.00, 30.00, 3, 14,
     'strict', 15, 18, 10,
     0, 0,
     '["WiFi","Ocean View","Private Beach Access","Kayak","BBQ Grill","Pet Friendly","Hot Tub","Outdoor Shower","Free Parking"]',
     '2026-02-22 00:00:00'),

    ('HA-003', 'PROP-003', 'Mountain Cabin A', 'Mountain Cabin A — South Lake Tahoe',
     '456 Pine Ridge Rd, South Lake Tahoe, CA 96150',
     'South Lake Tahoe', 'CA', 'USA', 'US', '96150', 38.9399, -119.9772,
     6, 3, 4, 2.0, 1.0,
     195.00, 150.00, 25.00, 2, 21,
     'moderate', 16, 20, 10,
     1, 0,
     '["WiFi","Hot Tub","Fireplace","Ski-In/Ski-Out","Snowshoe Equipment","Sleds","Star Gazing Deck","Free Parking","Full Kitchen"]',
     '2026-02-22 00:00:00');

-- OpenPhone number registry
INSERT OR IGNORE INTO openphone_phone_numbers
    (openphone_number_id, phone_number, label, property_id)
VALUES
    ('PN-001', '+18185550001', 'Main Ops Line', NULL);

-- Stamp schema version
PRAGMA user_version = 2;

COMMIT;

-- =============================================================================
-- Verify migration
-- =============================================================================
SELECT 'Migration complete. Schema version: ' || user_version AS result FROM pragma_user_version;
SELECT 'New tables: ' || COUNT(*) || ' rows in hostaway_listings' AS check1 FROM hostaway_listings;
SELECT 'Phone numbers: ' || COUNT(*) || ' rows in openphone_phone_numbers' AS check2 FROM openphone_phone_numbers;
SELECT 'Reservations backfilled: ' || COUNT(*) || ' rows with total_price set' AS check3
    FROM reservations WHERE total_price IS NOT NULL;
