#!/usr/bin/env python3
"""
Centralized Property Management Data System — Demo Runner
=========================================================
Creates the SQLite database from schema.sql + seed_data.sql,
then executes the five example queries and prints formatted results.

Usage:
    python run_queries.py
"""

import sqlite3
import os
import textwrap

DB_PATH = "property_data.db"
HOST_DIR = os.path.dirname(os.path.abspath(__file__))


def load_sql(filename):
    with open(os.path.join(HOST_DIR, filename), "r") as f:
        return f.read()


def create_database():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.executescript(load_sql("schema.sql"))
    conn.executescript(load_sql("seed_data.sql"))
    conn.commit()
    return conn


def print_table(rows, col_names, max_col_width=52):
    if not rows:
        print("  (no rows returned)")
        return

    col_widths = [len(c) for c in col_names]
    for row in rows:
        for i, val in enumerate(row):
            col_widths[i] = max(col_widths[i], len(str(val) if val is not None else "NULL"))

    col_widths = [min(w, max_col_width) for w in col_widths]

    sep = "+-" + "-+-".join("-" * w for w in col_widths) + "-+"
    header = "| " + " | ".join(c.ljust(col_widths[i]) for i, c in enumerate(col_names)) + " |"

    print(sep)
    print(header)
    print(sep)
    for row in rows:
        cells = []
        for i, val in enumerate(row):
            text = str(val) if val is not None else "NULL"
            cells.append(text[:col_widths[i]].ljust(col_widths[i]))
        print("| " + " | ".join(cells) + " |")
    print(sep)
    print(f"  {len(rows)} row{'s' if len(rows) != 1 else ''}\n")


def run_query(conn, title, question, sql):
    bar = "=" * 72
    print(f"\n{bar}")
    print(f"  {title}")
    print(f"  Q: \"{question}\"")
    print(bar)
    print()

    cur = conn.execute(sql)
    rows = cur.fetchall()
    col_names = [d[0] for d in cur.description]
    print_table(rows, col_names)


# ---------------------------------------------------------------------------
# QUERIES
# ---------------------------------------------------------------------------

Q1_TITLE    = "QUERY 1 — All Communication for Guest Arriving March 5th"
Q1_QUESTION = "Show me all communication related to the guest arriving on March 5th"
Q1_SQL = """
WITH march5_booking AS (
    SELECT
        r.id            AS res_id,
        r.guest_id,
        r.property_id,
        p.name          AS property_name,
        g.first_name || ' ' || g.last_name AS guest_name
    FROM reservations r
    JOIN guests     g ON r.guest_id    = g.id
    JOIN properties p ON r.property_id = p.id
    WHERE r.check_in = '2026-03-05'
)
SELECT
    mb.guest_name,
    mb.property_name,
    uc.source,
    uc.sent_at,
    uc.direction,
    SUBSTR(uc.content, 1, 70) AS content_preview
FROM unified_communications uc
JOIN march5_booking mb
  ON  uc.reservation_id = mb.res_id
   OR uc.guest_id       = mb.guest_id
ORDER BY uc.sent_at;
"""

Q2_TITLE    = "QUERY 2 — Discord Maintenance Issues, Cottage 3, This Month"
Q2_QUESTION = "What maintenance issues were reported in Discord for Cottage 3 this month?"
Q2_SQL = """
SELECT
    dm.sent_at,
    dm.author_display_name  AS reported_by,
    p.name                  AS property,
    SUBSTR(dm.content, 1, 75) AS message
FROM discord_messages dm
JOIN discord_channels dc ON dm.channel_id  = dc.id
JOIN properties       p  ON dc.property_id = p.id
WHERE p.name = 'Cottage 3'
  AND strftime('%Y-%m', dm.sent_at) = '2026-02'
  AND (
      dm.content LIKE '%mainten%'
   OR dm.content LIKE '%broken%'
   OR dm.content LIKE '%repair%'
   OR dm.content LIKE '%issue%'
   OR dm.content LIKE '%fix%'
   OR dm.content LIKE '%leak%'
   OR dm.content LIKE '%hvac%'
   OR dm.content LIKE '%heat%'
   OR dm.content LIKE '%blind%'
  )
ORDER BY dm.sent_at;
"""

Q3_TITLE    = "QUERY 3 — Full Call Transcript, Marcus Johnson (Most Recent)"
Q3_QUESTION = "Show me the transcript from the most recent call with Marcus Johnson"
Q3_SQL = """
SELECT
    g.first_name || ' ' || g.last_name AS guest,
    c.started_at,
    c.direction,
    c.duration_seconds                  AS total_s,
    t.speaker,
    t.timestamp_offset_seconds          AS elapsed_s,
    t.text
FROM openphone_call_transcripts t
JOIN openphone_calls c ON t.call_id  = c.id
JOIN guests          g ON c.guest_id = g.id
WHERE g.first_name = 'Marcus'
  AND g.last_name  = 'Johnson'
  AND c.started_at = (
      SELECT MAX(c2.started_at)
      FROM openphone_calls c2
      WHERE c2.guest_id = c.guest_id
  )
ORDER BY t.timestamp_offset_seconds;
"""

Q4_TITLE    = "QUERY 4 — Email Thread, Beach House 1 Reservations"
Q4_QUESTION = "What emails were exchanged about Beach House 1 reservations?"
Q4_SQL = """
SELECT
    ge.sent_at,
    ge.from_email,
    g.first_name || ' ' || g.last_name AS guest,
    ge.subject,
    SUBSTR(ge.body_text, 1, 80)        AS body_preview
FROM gmail_emails ge
JOIN gmail_threads gt ON ge.thread_id      = gt.id
JOIN reservations  r  ON gt.reservation_id = r.id
JOIN properties    p  ON r.property_id     = p.id
JOIN guests        g  ON r.guest_id        = g.id
WHERE p.name = 'Beach House 1'
ORDER BY ge.sent_at;
"""

Q5_TITLE    = "QUERY 5 — Full Communication Timeline, Emily Rodriguez"
Q5_QUESTION = "Show me every interaction we've had with Emily Rodriguez"
Q5_SQL = """
SELECT
    uc.source,
    uc.sent_at,
    uc.direction,
    COALESCE(p.name, '—') AS property,
    SUBSTR(uc.content, 1, 75) AS content_preview
FROM unified_communications uc
LEFT JOIN properties p ON uc.property_id = p.id
WHERE uc.guest_id = (
    SELECT id FROM guests
    WHERE first_name = 'Emily' AND last_name = 'Rodriguez'
)
ORDER BY uc.sent_at;
"""

Q6_TITLE    = "BONUS QUERY — Monthly Maintenance Activity by Property"
Q6_QUESTION = "Show a summary of maintenance mentions per property this month"
Q6_SQL = """
SELECT
    p.name              AS property,
    COUNT(*)            AS maintenance_mentions,
    MIN(dm.sent_at)     AS first_reported,
    MAX(dm.sent_at)     AS last_activity
FROM discord_messages dm
JOIN discord_channels dc ON dm.channel_id  = dc.id
JOIN properties       p  ON dc.property_id = p.id
WHERE strftime('%Y-%m', dm.sent_at) = '2026-02'
  AND (
      dm.content LIKE '%mainten%'
   OR dm.content LIKE '%broken%'
   OR dm.content LIKE '%repair%'
   OR dm.content LIKE '%issue%'
   OR dm.content LIKE '%fix%'
   OR dm.content LIKE '%leak%'
   OR dm.content LIKE '%hvac%'
   OR dm.content LIKE '%heat%'
  )
GROUP BY p.name
ORDER BY maintenance_mentions DESC;
"""


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

def main():
    print("\n" + "=" * 72)
    print("  CENTRALIZED PROPERTY MANAGEMENT DATA SYSTEM")
    print("  Hostaway · OpenPhone · Gmail · Discord → SQLite")
    print("=" * 72)

    print(f"\nBuilding database '{DB_PATH}'...")
    conn = create_database()
    print("  ✓ schema loaded")
    print("  ✓ mock data seeded")

    # Print record counts per table
    tables = [
        "guests", "properties", "reservations",
        "hostaway_conversations", "hostaway_messages",
        "openphone_calls", "openphone_call_transcripts", "openphone_sms_messages",
        "gmail_threads", "gmail_emails",
        "discord_channels", "discord_messages",
    ]
    print("\nRecord counts:")
    for t in tables:
        n = conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        print(f"  {t:<36} {n:>3} rows")

    # Run all queries
    run_query(conn, Q1_TITLE, Q1_QUESTION, Q1_SQL)
    run_query(conn, Q2_TITLE, Q2_QUESTION, Q2_SQL)
    run_query(conn, Q3_TITLE, Q3_QUESTION, Q3_SQL)
    run_query(conn, Q4_TITLE, Q4_QUESTION, Q4_SQL)
    run_query(conn, Q5_TITLE, Q5_QUESTION, Q5_SQL)
    run_query(conn, Q6_TITLE, Q6_QUESTION, Q6_SQL)

    conn.close()
    print("=" * 72)
    print(f"  Done. Database saved: {os.path.abspath(DB_PATH)}")
    print("=" * 72 + "\n")


if __name__ == "__main__":
    main()
