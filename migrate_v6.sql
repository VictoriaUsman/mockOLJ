-- =============================================================================
-- Migration: v5 → v6
-- Applies to: property_data.db (existing v5 SQLite database)
-- Applied: 2026-03-02
-- Run ONCE on the existing database. For fresh builds, use schema.sql + seed_data.sql.
--
-- What this does:
--   Aligns gmail_threads with the output produced by the Gmail loader
--   (output/domains/gmail.json). Three columns were missing that the loader
--   populates for every thread it fetches across all four mailboxes:
--
--   1. gmail_threads.delegate_email  — which service-account mailbox the thread
--                                      was fetched from
--   2. gmail_threads.message_count   — number of messages in the thread at sync time
--   3. gmail_threads.history_id      — Gmail historyId for incremental sync tracking
--
--   gmail_emails is already complete — no changes needed there.
--
-- SQLite notes:
--   · ALTER TABLE ADD COLUMN does not support IF NOT EXISTS.
--     Run this script ONCE. Re-running will fail with "duplicate column name".
--   · New columns are append-only after the last existing column.
--   · Foreign key checks are left ON — new columns default to NULL so no
--     existing rows violate any constraint.
-- =============================================================================

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- =============================================================================
-- 1. gmail_threads
--    Gmail loader fetches from four mailboxes via service account and
--    populates these three fields on every thread record.
-- =============================================================================

-- Which mailbox this thread belongs to.
-- One of: noah@staywithprecision.com, hello@staywithprecision.com,
--         bookkeeping@staywithprecision.com, evergreencottages@staywithprecision.com
ALTER TABLE gmail_threads ADD COLUMN delegate_email TEXT;

-- Number of messages inside the thread at the time of the last sync.
ALTER TABLE gmail_threads ADD COLUMN message_count INTEGER;

-- Gmail historyId — used by the loader for incremental / delta sync.
ALTER TABLE gmail_threads ADD COLUMN history_id TEXT;

CREATE INDEX IF NOT EXISTS idx_gmail_threads_delegate
    ON gmail_threads(delegate_email);

-- =============================================================================
-- 2. Bump schema version
-- =============================================================================

PRAGMA user_version = 6;

COMMIT;
