# Centralized Property Management Data System

A unified SQLite database that ingests and connects data from **Hostaway**, **OpenPhone**, **Gmail**, and **Discord** — enabling an AI assistant to answer cross-platform questions about guests, reservations, and property operations.

---

## Files

| File | Description |
|------|-------------|
| `schema.sql` | Full database schema with SCD Type 2 dimensions, cascading FKs, views, and indexes |
| `seed_data.sql` | Realistic mock data across all four platforms |
| `example_queries.sql` | All example queries (copy-paste ready for sqlite3) |
| `property_data.db` | Ready-to-query SQLite database |
| `run_queries.py` | Python script that builds the DB and runs all queries with formatted output |

---

## Schema Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DIMENSION TABLES (SCD Type 2)                │
│                                                                     │
│  ┌──────────────────────┐      ┌──────────────────────────────┐    │
│  │       guests         │      │         properties           │    │
│  │──────────────────────│      │──────────────────────────────│    │
│  │ id (surrogate PK)    │      │ id (surrogate PK)            │    │
│  │ guest_key (stable)   │      │ property_key (stable)        │    │
│  │ first_name           │      │ name                         │    │
│  │ last_name            │      │ address                      │    │
│  │ primary_email        │      │ hostaway_property_id         │    │
│  │ primary_phone        │      │ valid_from                   │    │
│  │ valid_from           │      │ valid_to  (NULL = active)    │    │
│  │ valid_to (NULL=live) │      │ is_current (0 or 1)         │    │
│  │ is_current (0 or 1)  │      └──────────────┬───────────────┘   │
│  └──────────┬───────────┘                     │                    │
│             │                                 │                    │
│    ┌────────▼─────────────────────────────────▼──────┐            │
│    │                    reservations                  │            │
│    │  id · hostaway_reservation_id · guest_id(FK)    │            │
│    │  property_id(FK) · check_in · check_out         │            │
│    │  status · channel · total_amount                │            │
│    └────┬────────────────────────────────────────────┘            │
│         │                                                          │
│    ┌────▼────────────────────┐                                     │
│    │  hostaway_conversations │ ← CASCADE on reservation delete     │
│    │  id · reservation_id   │                                      │
│    │  channel               │                                      │
│    └────┬────────────────────┘                                     │
│         │                                                          │
│    ┌────▼────────────────────┐                                     │
│    │   hostaway_messages     │ ← CASCADE on conversation delete    │
│    │   conversation_id(FK)   │                                     │
│    │   sender_type · body    │                                     │
│    │   sent_at               │                                     │
│    └─────────────────────────┘                                     │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                          OPENPHONE                                   │
│                                                                      │
│  ┌──────────────────────────┐    ┌──────────────────────────────┐   │
│  │     openphone_calls      │    │   openphone_sms_messages     │   │
│  │  id · guest_id(FK)       │    │   id · guest_id(FK)          │   │
│  │  guest_phone · our_phone │    │   guest_phone · our_phone    │   │
│  │  direction · duration_s  │    │   direction · body · sent_at │   │
│  │  started_at · summary    │    └──────────────────────────────┘   │
│  └──────────┬───────────────┘                                       │
│             │                                                        │
│  ┌──────────▼───────────────────┐                                   │
│  │  openphone_call_transcripts  │ ← CASCADE on call delete          │
│  │  call_id(FK) · speaker       │                                   │
│  │  text · timestamp_offset_s   │                                   │
│  └──────────────────────────────┘                                   │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                            GMAIL                                     │
│                                                                      │
│  ┌───────────────────────────────────┐                              │
│  │           gmail_threads           │                              │
│  │  id · guest_id(FK) · subject      │                              │
│  │  reservation_id(FK) · gmail_id    │                              │
│  └──────────────┬────────────────────┘                              │
│                 │                                                    │
│  ┌──────────────▼────────────────────┐                              │
│  │           gmail_emails            │ ← CASCADE on thread delete   │
│  │  thread_id(FK) · from_email       │                              │
│  │  to_email · subject · body_text   │                              │
│  │  sent_at · labels                 │                              │
│  └───────────────────────────────────┘                              │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                           DISCORD                                    │
│                                                                      │
│  ┌────────────────────────────────┐                                 │
│  │        discord_channels        │                                 │
│  │  id · property_id(FK)          │                                 │
│  │  channel_name · server_name    │                                 │
│  └──────────────┬─────────────────┘                                 │
│                 │                                                    │
│  ┌──────────────▼─────────────────┐                                 │
│  │        discord_messages        │ ← CASCADE on channel delete     │
│  │  channel_id(FK) · content      │                                 │
│  │  author · sent_at              │                                 │
│  │  reservation_id(FK, optional)  │                                 │
│  └────────────────────────────────┘                                 │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                             VIEWS                                    │
│                                                                      │
│  current_guests       → guests WHERE is_current = 1                 │
│  current_properties   → properties WHERE is_current = 1             │
│                                                                      │
│  unified_communications → UNION ALL of:                             │
│    hostaway_messages + openphone_sms_messages +                     │
│    openphone_calls + gmail_emails + discord_messages                │
│                                                                      │
│    Exposes: source, sent_at, content, direction,                    │
│             guest_key (stable), guest_id (surrogate),               │
│             property_id, reservation_id                             │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Mock Data Overview

| Table | Rows | Notes |
|-------|------|-------|
| guests | 5 | 4 guests · Sarah Chen has 2 SCD versions (email change Feb 15) |
| properties | 4 | 3 properties · Beach House 1 has 2 SCD versions (address corrected Jan 1) |
| reservations | 4 | Marcus (checked out), Emily (upcoming), Sarah (upcoming), David (checked out) |
| hostaway_conversations | 4 | One per reservation |
| hostaway_messages | 21 | Realistic guest ↔ host exchanges |
| openphone_calls | 2 | Marcus (parking/pet deposit), Sarah (early check-in/fire pit) |
| openphone_call_transcripts | 19 | Word-for-word dialogue with elapsed timestamps |
| openphone_sms_messages | 19 | Full threads per guest |
| gmail_threads | 3 | One per reservation |
| gmail_emails | 9 | Multi-reply threads |
| discord_channels | 4 | One ops channel per property + general |
| discord_messages | 15 | Maintenance reports, check-in notes, team comms |

---

## Example Queries & Results

### Query 1 — All communication for the guest arriving March 5th

> *"Show me all communication related to the guest arriving on March 5th"*

Uses `guest_key` (stable SCD identifier) to pull interactions across both versions of Sarah Chen's profile — her January SMS (linked to v1/Gmail) and her February SMS and call (linked to v2/ProtonMail) all appear in one result.

```sql
WITH march5_booking AS (
    SELECT g.guest_key, cp.name AS property_name,
           cg.first_name || ' ' || cg.last_name AS guest_name
    FROM reservations r
    JOIN guests g ON r.guest_id = g.id
    JOIN current_guests cg ON g.guest_key = cg.guest_key
    JOIN properties p ON r.property_id = p.id
    JOIN current_properties cp ON p.property_key = cp.property_key
    WHERE r.check_in = '2026-03-05'
)
SELECT mb.guest_name, mb.property_name, uc.source, uc.sent_at,
       uc.direction, SUBSTR(uc.content, 1, 65) AS content_preview
FROM unified_communications uc
JOIN march5_booking mb ON uc.guest_key = mb.guest_key
ORDER BY uc.sent_at;
```

**Results (17 rows):**
```
guest_name  property_name  source          sent_at              direction  content_preview
----------  -------------  --------------  -------------------  ---------  -----------------------------------------------------------------
Sarah Chen  Cottage 3      openphone_sms   2026-01-15 13:05:00  inbound    Hi, this is Sarah. Interested in Cottage 3 for early March — is i
Sarah Chen  Cottage 3      openphone_sms   2026-01-15 13:12:00  outbound   Hi Sarah! Yes, Cottage 3 is open March 5-10. Sending the booking
Sarah Chen  Cottage 3      openphone_sms   2026-01-15 13:30:00  inbound    Booked! So excited. Quick question — is the hot tub working?
Sarah Chen  Cottage 3      openphone_sms   2026-01-15 13:38:00  outbound   Yes! Hot tub is fully operational and seats 6. You'll love it.
Sarah Chen  Cottage 3      hostaway        2026-02-01 08:30:00  guest      Hi! Just booked Cottage 3 for March 5-10. So excited for our stay
Sarah Chen  Cottage 3      hostaway        2026-02-01 09:00:00  host       Welcome Sarah! We're thrilled to have you. Cottage 3 is stunning
Sarah Chen  Cottage 3      hostaway        2026-02-03 14:15:00  guest      Quick question — is there parking for two cars? We're each drivin
Sarah Chen  Cottage 3      hostaway        2026-02-03 14:45:00  host       Absolutely! Two-car garage plus overflow in the driveway. No prob
Sarah Chen  Cottage 3      gmail           2026-02-18 09:00:00  outbound   [Pre-Arrival Instructions — Cottage 3, March 5-10 | Booking #R-10
Sarah Chen  Cottage 3      openphone_sms   2026-02-18 09:00:00  outbound   Hi Sarah! Check-in is March 5th. Gate: 4821 · Door: 7392. Any que
Sarah Chen  Cottage 3      openphone_sms   2026-02-18 09:45:00  inbound    Thank you! Any chance we could do a 1pm early check-in instead of
Sarah Chen  Cottage 3      openphone_sms   2026-02-18 09:50:00  outbound   Let me check with housekeeping and get back to you by end of day!
Sarah Chen  Cottage 3      gmail           2026-02-18 10:30:00  inbound    [Re: Pre-Arrival Instructions — Cottage 3, March 5-10 | Booking #
Sarah Chen  Cottage 3      hostaway        2026-02-18 16:00:00  guest      Wonderful. One more thing — could we do an early check-in around
Sarah Chen  Cottage 3      hostaway        2026-02-18 16:30:00  host       Let me check with housekeeping. I'll confirm by end of day!
Sarah Chen  Cottage 3      openphone_call  2026-02-19 10:15:00  inbound    Sarah called to confirm 1pm early check-in and asked about the fi
Sarah Chen  Cottage 3      gmail           2026-02-19 11:00:00  outbound   [Re: Pre-Arrival Instructions — Cottage 3, March 5-10 | Booking #
```

---

### Query 2 — Discord maintenance issues for Cottage 3 this month

> *"What maintenance issues were reported in Discord for Cottage 3 this month?"*

```sql
SELECT dm.sent_at, dm.author_display_name AS reported_by,
       SUBSTR(dm.content, 1, 80) AS message
FROM discord_messages dm
JOIN discord_channels dc ON dm.channel_id = dc.id
JOIN properties p ON dc.property_id = p.id
JOIN current_properties cp ON p.property_key = cp.property_key
WHERE cp.name = 'Cottage 3'
  AND strftime('%Y-%m', dm.sent_at) = strftime('%Y-%m', 'now')
  AND (dm.content LIKE '%mainten%' OR dm.content LIKE '%broken%'
   OR dm.content LIKE '%repair%'   OR dm.content LIKE '%issue%'
   OR dm.content LIKE '%fix%'      OR dm.content LIKE '%leak%'
   OR dm.content LIKE '%hvac%'     OR dm.content LIKE '%heat%'
   OR dm.content LIKE '%blind%')
ORDER BY dm.sent_at;
```

**Results (6 rows):**
```
sent_at              reported_by           message
-------------------  --------------------  --------------------------------------------------------------------------------
2026-02-03 11:15:00  Tony (Manager)        Heads up — guest in Cottage 3 reported the hot tub isn't heating to temp. Came i
2026-02-04 10:45:00  Marco (Pool Tech)     Hot tub issue at Cottage 3 resolved. Replaced the faulty heating element. Runnin
2026-02-12 14:00:00  Rena (Ops)            HVAC filter at Cottage 3 is overdue. Scheduling replacement for the Feb 15 turno
2026-02-15 16:20:00  Linda (Housekeeping)  Cottage 3 turnover complete. HVAC filter replaced. Also caught a small leak unde
2026-02-17 09:00:00  Tony (Manager)        New issue at Cottage 3: current guest reporting a broken window blind in the mas
2026-02-20 13:10:00  Linda (Housekeeping)  Replaced the blind in Cottage 3 master bedroom during today's inspection. Looks
```

---

### Query 3 — Full call transcript, Marcus Johnson (most recent)

> *"Show me the transcript from the most recent call with Marcus Johnson"*

```sql
SELECT cg.first_name || ' ' || cg.last_name AS guest,
       c.started_at, c.direction, c.duration_seconds AS total_s,
       t.speaker, t.timestamp_offset_seconds AS elapsed_s, t.text
FROM openphone_call_transcripts t
JOIN openphone_calls c ON t.call_id = c.id
JOIN guests g ON c.guest_id = g.id
JOIN current_guests cg ON g.guest_key = cg.guest_key
WHERE cg.first_name = 'Marcus' AND cg.last_name = 'Johnson'
  AND c.started_at = (
      SELECT MAX(c2.started_at) FROM openphone_calls c2
      JOIN guests g2 ON c2.guest_id = g2.id
      WHERE g2.guest_key = cg.guest_key)
ORDER BY t.timestamp_offset_seconds;
```

**Results (10 rows):**
```
guest           started_at           direction  total_s  speaker  elapsed_s  text
--------------  -------------------  ---------  -------  -------  ---------  --------------------------------------------------------------------------------------------
Marcus Johnson  2026-01-30 15:30:00  inbound    262      host     0          Good afternoon, property management, how can I help?
Marcus Johnson  2026-01-30 15:30:00  inbound    262      guest    5          Hi, this is Marcus Johnson. I have a reservation at Beach House 1 starting February 1st.
Marcus Johnson  2026-01-30 15:30:00  inbound    262      host     13         Of course, hi Marcus! Looking forward to your stay. What can I help with?
Marcus Johnson  2026-01-30 15:30:00  inbound    262      guest    20         I wanted to confirm parking — I'm driving up from San Diego with my truck.
Marcus Johnson  2026-01-30 15:30:00  inbound    262      host     32         No problem. The driveway fits two to three vehicles comfortably.
Marcus Johnson  2026-01-30 15:30:00  inbound    262      guest    44         Great. Also — can we bring our dog? Golden retriever, very well-behaved.
Marcus Johnson  2026-01-30 15:30:00  inbound    262      host     56         Good news — Beach House 1 is pet-friendly. There's a $50 pet deposit I can add now.
Marcus Johnson  2026-01-30 15:30:00  inbound    262      guest    74         Perfect, let's do it. Thank you!
Marcus Johnson  2026-01-30 15:30:00  inbound    262      host     82         Done! Reservation updated. Looking forward to hosting you February 1st, Marcus.
Marcus Johnson  2026-01-30 15:30:00  inbound    262      guest    93         Appreciate it. See you then. Bye!
```

---

### Query 4 — Email threads for Beach House 1 reservations

> *"What emails were exchanged about Beach House 1 reservations?"*

```sql
SELECT ge.sent_at, ge.from_email,
       cg.first_name || ' ' || cg.last_name AS guest,
       ge.subject, SUBSTR(ge.body_text, 1, 70) AS body_preview
FROM gmail_emails ge
JOIN gmail_threads gt ON ge.thread_id = gt.id
JOIN reservations r ON gt.reservation_id = r.id
JOIN properties p ON r.property_id = p.id
JOIN current_properties cp ON p.property_key = cp.property_key
JOIN guests g ON r.guest_id = g.id
JOIN current_guests cg ON g.guest_key = cg.guest_key
WHERE cp.name = 'Beach House 1'
ORDER BY ge.sent_at;
```

**Results (3 rows):**
```
sent_at              from_email             guest           subject                                                                  body_preview
-------------------  ---------------------  --------------  -----------------------------------------------------------------------  ----------------------------------------------------------------------
2026-01-25 10:00:00  host@propertymgmt.com  Marcus Johnson  Reservation Confirmation — Beach House 1, Feb 1-8 | Booking #R-1001      Dear Marcus, Thank you for booking Beach House 1 for February 1-8. Boo
2026-01-25 14:22:00  marcus.j@outlook.com   Marcus Johnson  Re: Reservation Confirmation — Beach House 1, Feb 1-8 | Booking #R-1001  Thanks for the confirmation! Two questions: is the kayak available for
2026-01-26 09:15:00  host@propertymgmt.com  Marcus Johnson  Re: Reservation Confirmation — Beach House 1, Feb 1-8 | Booking #R-1001  Hi Marcus! Kayak is available — stored in the dock shed with life vest
```

---

### Query 5 — Full communication timeline for Emily Rodriguez

> *"Show me every interaction we've had with Emily Rodriguez"*

Filters by `guest_key` (stable across SCD versions) and joins all platforms through `unified_communications`.

```sql
SELECT uc.source, uc.sent_at, uc.direction,
       COALESCE(cp.name, '—') AS property,
       SUBSTR(uc.content, 1, 75) AS content_preview
FROM unified_communications uc
LEFT JOIN properties p ON uc.property_id = p.id
LEFT JOIN current_properties cp ON p.property_key = cp.property_key
WHERE uc.guest_key = (
    SELECT guest_key FROM current_guests
    WHERE first_name = 'Emily' AND last_name = 'Rodriguez')
ORDER BY uc.sent_at;
```

**Results (12 rows):**
```
source         sent_at              direction  property          content_preview
-------------  -------------------  ---------  ----------------  ---------------------------------------------------------------------------
openphone_sms  2026-02-10 10:30:00  inbound    —                 Hi! Emily here. Looking forward to Mountain Cabin A! Is snowshoeing gear av
openphone_sms  2026-02-10 10:42:00  outbound   —                 Hi Emily! Two pairs of snowshoes in the garage + sleds for the hills. Super
gmail          2026-02-12 10:00:00  outbound   —                 [Your Upcoming Stay — Mountain Cabin A, Feb 25-Mar 1 | Booking #R-1002] Dea
gmail          2026-02-14 09:45:00  inbound    —                 [Re: Your Upcoming Stay — Mountain Cabin A, Feb 25-Mar 1 | Booking #R-1002]
hostaway       2026-02-14 11:00:00  guest      Mountain Cabin A  Hi! Booked Mountain Cabin A for Feb 25 - Mar 1. Any local activity recommen
hostaway       2026-02-14 11:45:00  host       Mountain Cabin A  Hi Emily! Late February is magical up there. Ski resorts are 20 min away, s
hostaway       2026-02-14 12:10:00  guest      Mountain Cabin A  Perfect! We'll have 4 adults. Is there enough bedding?
hostaway       2026-02-14 12:30:00  host       Mountain Cabin A  Absolutely — two king bedrooms plus a queen loft. Sleeps 6 comfortably!
gmail          2026-02-14 14:00:00  outbound   —                 [Re: Your Upcoming Stay — Mountain Cabin A, Feb 25-Mar 1 | Booking #R-1002]
openphone_sms  2026-02-18 09:00:00  outbound   —                 Emily — confirming Feb 25 arrival at Mountain Cabin A. Door code: 6614. Can
openphone_sms  2026-02-18 09:30:00  inbound    —                 Perfect! We are so excited. Will the hot tub be cleaned and ready?
openphone_sms  2026-02-18 09:45:00  outbound   —                 Absolutely — hot tub will be fresh and set to 104°F for your arrival.
```

---

### Query 6 — SCD Type 2 audit: Sarah Chen version history

> *"Show Sarah Chen's guest record history — what changed and when?"*

Demonstrates SCD Type 2: Sarah changed her email on Feb 15. Her reservation (`R-1003`) remains linked to surrogate `id=1` (the version active at booking time). Post-Feb-15 SMS and the call are linked to `id=5` (new version).

```sql
SELECT g.id AS surrogate_id, g.guest_key, g.primary_email,
       g.valid_from, COALESCE(g.valid_to, 'CURRENT') AS valid_to,
       CASE g.is_current WHEN 1 THEN 'YES' ELSE 'no' END AS is_current,
       (SELECT GROUP_CONCAT(r.hostaway_reservation_id)
        FROM reservations r WHERE r.guest_id = g.id) AS reservations_on_version,
       (SELECT COUNT(*) FROM openphone_sms_messages s WHERE s.guest_id = g.id) AS sms_count,
       (SELECT COUNT(*) FROM openphone_calls c WHERE c.guest_id = g.id) AS call_count
FROM guests g
WHERE g.guest_key = (SELECT guest_key FROM current_guests
    WHERE first_name = 'Sarah' AND last_name = 'Chen')
ORDER BY g.valid_from;
```

**Results (2 rows):**
```
surrogate_id  guest_key  primary_email          valid_from           valid_to             is_current  reservations_on_version  sms_count  call_count
------------  ---------  ---------------------  -------------------  -------------------  ----------  -----------------------  ---------  ----------
1             G-001      sarah.chen@gmail.com   2026-01-01           2026-02-15 10:00:00  no          R-1003                   4          0
5             G-001      s.chen@protonmail.com  2026-02-15 10:00:00  CURRENT              YES                                  3          1
```

---

### Bonus — Monthly maintenance activity by property

> *"Summarize maintenance mentions per property this month"*

```sql
SELECT cp.name AS property, COUNT(*) AS maintenance_mentions,
       MIN(dm.sent_at) AS first_reported, MAX(dm.sent_at) AS last_activity
FROM discord_messages dm
JOIN discord_channels dc ON dm.channel_id = dc.id
JOIN properties p ON dc.property_id = p.id
JOIN current_properties cp ON p.property_key = cp.property_key
WHERE strftime('%Y-%m', dm.sent_at) = strftime('%Y-%m', 'now')
  AND (dm.content LIKE '%mainten%' OR dm.content LIKE '%broken%'
   OR dm.content LIKE '%repair%'   OR dm.content LIKE '%issue%'
   OR dm.content LIKE '%fix%'      OR dm.content LIKE '%leak%'
   OR dm.content LIKE '%hvac%'     OR dm.content LIKE '%heat%')
GROUP BY cp.name ORDER BY maintenance_mentions DESC;
```

**Results (2 rows):**
```
property       maintenance_mentions  first_reported       last_activity
-------------  --------------------  -------------------  -------------------
Cottage 3      5                     2026-02-03 11:15:00  2026-02-17 09:00:00
Beach House 1  2                     2026-02-01 15:30:00  2026-02-08 12:00:00
```

---

## Design Decisions

### 1. Unified communications view as the AI query layer
Rather than forcing an AI assistant to know which table holds which type of message, a single `unified_communications` view flattens all five message types (Hostaway messages, SMS, calls, emails, Discord) into one timeline. The AI queries one surface; the schema handles the joins.

### 2. SCD Type 2 for guests and properties
Guest contact info and property details change over time — an email address update or an address correction shouldn't silently overwrite history. SCD Type 2 preserves every version with `valid_from`, `valid_to`, and `is_current` columns, plus a stable `guest_key` / `property_key` that stays consistent across versions.

- A partial unique index (`WHERE is_current = 1`) enforces the "only one active version" rule at the database level rather than in application code.
- Operational records (reservations, SMS, calls) reference the **surrogate** id — capturing which version of a guest was current at the time of the event. Cross-version queries use `guest_key`.

### 3. Cascading deletes on operational child tables
Removing a parent record (a call, a conversation, an email thread, a Discord channel) automatically removes its dependent children. This prevents orphaned rows without requiring multi-statement transactions in application code:

- `openphone_calls` → `openphone_call_transcripts` (CASCADE)
- `hostaway_conversations` → `hostaway_messages` (CASCADE)
- `gmail_threads` → `gmail_emails` (CASCADE)
- `discord_channels` → `discord_messages` (CASCADE)

Dimension FKs (`reservations.guest_id`, `reservations.property_id`) are `RESTRICT` — you should not be able to delete a guest or property version that has reservations attached to it.

### 4. Discord as property-level, not guest-level
Discord is an internal ops channel, not a guest-facing platform. Messages are linked to a **property** (via `discord_channels.property_id`), not a guest. A `reservation_id` column is available for optionally tagging a message to a specific booking, but it's nullable.

### 5. SQLite for the prototype
SQLite requires zero infrastructure, ships on every OS, and supports CTEs, views, partial indexes, and foreign key cascading — everything needed for this prototype. The schema is written to be largely portable to PostgreSQL or MySQL if the system needs to scale.

---

## Write-Up

### AI Tools Used
This system was built using **Claude Code** (Anthropic's CLI tool, powered by Claude Sonnet 4.6). Claude designed the schema, wrote all SQL, generated the mock data, and executed the queries — working interactively with feedback on features like SCD Type 2 and cascading constraints.

### How Long It Took
Approximately **1.5 hours** from first prompt to completed deliverable, including:
- Schema design and iteration (SCD Type 2, cascading FKs, views)
- Writing realistic mock data across all four platforms
- Writing and validating all queries against the live database
- Documentation
