-- =============================================================================
-- Mock Seed Data
-- Hostaway · OpenPhone · Gmail · Discord
-- Reference date: 2026-02-20
--
-- SCD Type 2 examples:
--   guests.G-001 (Sarah Chen) — email changed 2026-02-15, two versions exist.
--     Her reservation (created Feb 1) references surrogate id=1 (v1, the version
--     active at booking time). Post-Feb-15 SMS and calls reference id=5 (v2).
--
--   properties.PROP-002 (Beach House 1) — address corrected 2026-01-01.
--     Historical reservations from 2025 reference surrogate id=2 (v1).
--     All 2026 reservations reference id=5 (v2, the corrected listing).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PROPERTIES (SCD Type 2)
-- -----------------------------------------------------------------------------
INSERT INTO properties (id, property_key, name, address, hostaway_property_id, valid_from, valid_to, is_current) VALUES
    -- Cottage 3: one version, no changes
    (1, 'PROP-001', 'Cottage 3',
        '789 Lakeview Dr, Big Bear Lake, CA 92315',    'HA-001', '2025-06-01', NULL,         1),

    -- Beach House 1 v1: original address (typo in street number), expired 2026-01-01
    (2, 'PROP-002', 'Beach House 1',
        '123 Ocean Ave, Malibu, CA 90265',             'HA-002', '2025-03-01', '2026-01-01', 0),

    -- Mountain Cabin A: one version
    (3, 'PROP-003', 'Mountain Cabin A',
        '456 Pine Ridge Rd, South Lake Tahoe, CA 96150','HA-003','2025-09-01', NULL,         1),

    -- Beach House 1 v2: corrected address — active 2026-01-01 onward (current)
    (5, 'PROP-002', 'Beach House 1',
        '125 Pacific Coast Hwy, Malibu, CA 90265',     'HA-002', '2026-01-01', NULL,         1);

-- -----------------------------------------------------------------------------
-- GUESTS (SCD Type 2)
-- -----------------------------------------------------------------------------
INSERT INTO guests (id, guest_key, first_name, last_name, primary_email, primary_phone, valid_from, valid_to, is_current) VALUES
    -- Sarah Chen v1: registered with Gmail; expires when she updates to ProtonMail
    (1, 'G-001', 'Sarah',  'Chen',      'sarah.chen@gmail.com',   '+14155557821', '2026-01-01', '2026-02-15 10:00:00', 0),

    -- Marcus Johnson: one version, no changes
    (2, 'G-002', 'Marcus', 'Johnson',   'marcus.j@outlook.com',   '+13105554392', '2025-12-01', NULL,                  1),

    -- Emily Rodriguez: one version, no changes
    (3, 'G-003', 'Emily',  'Rodriguez', 'emily.r@yahoo.com',      '+17145558834', '2026-01-01', NULL,                  1),

    -- David Park: one version, no changes
    (4, 'G-004', 'David',  'Park',      'dpark@gmail.com',        '+14085559121', '2025-06-01', NULL,                  1),

    -- Sarah Chen v2: switched to ProtonMail — current version
    (5, 'G-001', 'Sarah',  'Chen',      's.chen@protonmail.com',  '+14155557821', '2026-02-15 10:00:00', NULL,         1);

-- -----------------------------------------------------------------------------
-- RESERVATIONS
-- guest_id and property_id reference the surrogate that was current at
-- the time the reservation was created.
-- -----------------------------------------------------------------------------
INSERT INTO reservations (id, hostaway_reservation_id, guest_id, property_id, check_in, check_out, status, channel, total_amount) VALUES
    -- Marcus Johnson / Beach House 1 v2 (property corrected before this booking)
    (1, 'R-1001', 2, 5, '2026-02-01', '2026-02-08', 'checked_out', 'airbnb',  1540.00),

    -- Emily Rodriguez / Mountain Cabin A
    (2, 'R-1002', 3, 3, '2026-02-25', '2026-03-01', 'confirmed',   'direct',   920.00),

    -- Sarah Chen / Cottage 3  — guest_id=1 (v1 was active on Feb 1 when booked)
    (3, 'R-1003', 1, 1, '2026-03-05', '2026-03-10', 'confirmed',   'vrbo',    1250.00),

    -- David Park / Beach House 1 v2 (Jan 2026 stay, v2 active since Jan 1)
    (4, 'R-1004', 4, 5, '2026-01-10', '2026-01-15', 'checked_out', 'airbnb',  1100.00);

-- -----------------------------------------------------------------------------
-- HOSTAWAY CONVERSATIONS & MESSAGES
-- -----------------------------------------------------------------------------
INSERT INTO hostaway_conversations (id, hostaway_conversation_id, reservation_id, channel) VALUES
    (1, 'HC-1001', 1, 'airbnb'),
    (2, 'HC-1002', 2, 'direct'),
    (3, 'HC-1003', 3, 'vrbo'),
    (4, 'HC-1004', 4, 'airbnb');

-- Marcus Johnson ↔ Beach House 1
INSERT INTO hostaway_messages (conversation_id, sender_type, body, sent_at) VALUES
    (1, 'guest', 'Hey, just confirmed my booking. Will I receive check-in instructions soon?',                                    '2026-01-28 09:12:00'),
    (1, 'host',  'Hi Marcus! Full check-in instructions arrive 48 hours before arrival, including the digital lock code.',        '2026-01-28 10:05:00'),
    (1, 'guest', 'Perfect. Also — is the kayak still available for guests?',                                                      '2026-01-28 10:22:00'),
    (1, 'host',  'Yes! Kayak is in the shed by the dock; life vests on the wall hooks. Enjoy!',                                  '2026-01-28 10:45:00'),
    (1, 'guest', 'Awesome! See you February 1st.',                                                                                '2026-01-28 10:48:00'),
    (1, 'guest', 'Just a note — garbage disposal isn''t working. Not urgent at all.',                                             '2026-02-07 14:30:00'),
    (1, 'host',  'Thanks for letting us know Marcus! We''ll service it during turnover. Sorry for the trouble.',                  '2026-02-07 14:55:00');

-- Emily Rodriguez ↔ Mountain Cabin A
INSERT INTO hostaway_messages (conversation_id, sender_type, body, sent_at) VALUES
    (2, 'guest', 'Hi! Booked Mountain Cabin A for Feb 25 - Mar 1. Any local activity recommendations?',                          '2026-02-14 11:00:00'),
    (2, 'host',  'Hi Emily! Late February is magical up there. Ski resorts are 20 min away, snowshoeing trails are on property, and the hot tub runs 24/7.', '2026-02-14 11:45:00'),
    (2, 'guest', 'Perfect! We''ll have 4 adults. Is there enough bedding?',                                                       '2026-02-14 12:10:00'),
    (2, 'host',  'Absolutely — two king bedrooms plus a queen loft. Sleeps 6 comfortably!',                                      '2026-02-14 12:30:00');

-- Sarah Chen ↔ Cottage 3 (reservation linked to guest v1)
INSERT INTO hostaway_messages (conversation_id, sender_type, body, sent_at) VALUES
    (3, 'guest', 'Hi! Just booked Cottage 3 for March 5-10. So excited for our stay!',                                           '2026-02-01 08:30:00'),
    (3, 'host',  'Welcome Sarah! We''re thrilled to have you. Cottage 3 is stunning in early March.',                            '2026-02-01 09:00:00'),
    (3, 'guest', 'Quick question — is there parking for two cars? We''re each driving.',                                         '2026-02-03 14:15:00'),
    (3, 'host',  'Absolutely! Two-car garage plus overflow in the driveway. No problem.',                                        '2026-02-03 14:45:00'),
    (3, 'guest', 'Wonderful. One more thing — could we do an early check-in around 1pm if possible?',                            '2026-02-18 16:00:00'),
    (3, 'host',  'Let me check with housekeeping. I''ll confirm by end of day!',                                                 '2026-02-18 16:30:00');

-- David Park ↔ Beach House 1
INSERT INTO hostaway_messages (conversation_id, sender_type, body, sent_at) VALUES
    (4, 'guest', 'Hello! Looking forward to our stay at Beach House 1 next week.',                      '2026-01-08 10:00:00'),
    (4, 'host',  'Hi David! Great to have you back. Anything you need before arrival?',                 '2026-01-08 10:30:00'),
    (4, 'guest', 'Just making sure the WiFi password hasn''t changed.',                                 '2026-01-08 10:45:00'),
    (4, 'host',  'Same password as last time: BeachWave2024. See you on the 10th!',                    '2026-01-08 11:00:00');

-- -----------------------------------------------------------------------------
-- OPENPHONE CALLS
-- Sarah's call (Feb 19) references guest_id=5 (v2 — she updated email Feb 15)
-- -----------------------------------------------------------------------------
INSERT INTO openphone_calls (id, openphone_call_id, guest_id, guest_phone, our_phone, direction, duration_seconds, started_at, ended_at, summary) VALUES
    (1, 'OP-CALL-001', 2, '+13105554392', '+18185550001', 'inbound', 262,
     '2026-01-30 15:30:00', '2026-01-30 15:34:22',
     'Marcus called to confirm parking and ask about pet policy. Confirmed pet-friendly with $50 deposit — added to reservation.'),

    -- guest_id=5: Sarah v2 was current on Feb 19 (post email-change)
    (2, 'OP-CALL-002', 5, '+14155557821', '+18185550001', 'inbound', 185,
     '2026-02-19 10:15:00', '2026-02-19 10:18:05',
     'Sarah called to confirm 1pm early check-in and asked about the fire pit. Both confirmed.');

-- Marcus Johnson transcript
INSERT INTO openphone_call_transcripts (call_id, speaker, text, timestamp_offset_seconds) VALUES
    (1, 'host',  'Good afternoon, property management, how can I help?',                                        0),
    (1, 'guest', 'Hi, this is Marcus Johnson. I have a reservation at Beach House 1 starting February 1st.',    5),
    (1, 'host',  'Of course, hi Marcus! Looking forward to your stay. What can I help with?',                  13),
    (1, 'guest', 'I wanted to confirm parking — I''m driving up from San Diego with my truck.',                 20),
    (1, 'host',  'No problem. The driveway fits two to three vehicles comfortably.',                            32),
    (1, 'guest', 'Great. Also — can we bring our dog? Golden retriever, very well-behaved.',                   44),
    (1, 'host',  'Good news — Beach House 1 is pet-friendly. There''s a $50 pet deposit I can add now.',       56),
    (1, 'guest', 'Perfect, let''s do it. Thank you!',                                                          74),
    (1, 'host',  'Done! Reservation updated. Looking forward to hosting you February 1st, Marcus.',            82),
    (1, 'guest', 'Appreciate it. See you then. Bye!',                                                          93);

-- Sarah Chen transcript (call linked to guest v2)
INSERT INTO openphone_call_transcripts (call_id, speaker, text, timestamp_offset_seconds) VALUES
    (2, 'host',  'Hello, property management, how can I help?',                                                  0),
    (2, 'guest', 'Hi, this is Sarah Chen. I have an upcoming stay at Cottage 3 on March 5th.',                  4),
    (2, 'host',  'Hi Sarah! I have your reservation right here. How can I help?',                               11),
    (2, 'guest', 'Wanted to confirm the 1pm early check-in we texted about — is that locked in?',               18),
    (2, 'host',  'Yes! Housekeeping confirmed. You''re all set for a 1pm arrival on March 5th.',                27),
    (2, 'guest', 'Perfect. Also — does the property have a fire pit? My husband is really hoping.',              40),
    (2, 'host',  'Yes! There''s a beautiful stone fire pit in the backyard, and we provide firewood.',           51),
    (2, 'guest', 'That''s amazing. We are going to love it. Thank you!',                                        65),
    (2, 'host',  'We''re so excited for you. See you on March 5th, Sarah!',                                     73);

-- -----------------------------------------------------------------------------
-- OPENPHONE SMS
-- Sarah's early SMS (Jan) reference guest_id=1 (v1, pre-email-change).
-- Sarah's later SMS (Feb 18-19, after the Feb 15 update) reference guest_id=5 (v2).
-- -----------------------------------------------------------------------------

-- Sarah Chen v1 (guest_id=1) — Jan 15, initial inquiry before email change
INSERT INTO openphone_sms_messages (openphone_sms_id, guest_id, guest_phone, our_phone, direction, body, sent_at) VALUES
    ('SMS-001', 1, '+14155557821', '+18185550001', 'inbound',  'Hi, this is Sarah. Interested in Cottage 3 for early March — is it still available?',        '2026-01-15 13:05:00'),
    ('SMS-002', 1, '+14155557821', '+18185550001', 'outbound', 'Hi Sarah! Yes, Cottage 3 is open March 5-10. Sending the booking link now.',                  '2026-01-15 13:12:00'),
    ('SMS-003', 1, '+14155557821', '+18185550001', 'inbound',  'Booked! So excited. Quick question — is the hot tub working?',                               '2026-01-15 13:30:00'),
    ('SMS-004', 1, '+14155557821', '+18185550001', 'outbound', 'Yes! Hot tub is fully operational and seats 6. You''ll love it.',                             '2026-01-15 13:38:00');

-- Sarah Chen v2 (guest_id=5) — Feb 18-19, after she updated her email on Feb 15
INSERT INTO openphone_sms_messages (openphone_sms_id, guest_id, guest_phone, our_phone, direction, body, sent_at) VALUES
    ('SMS-005', 5, '+14155557821', '+18185550001', 'outbound', 'Hi Sarah! Check-in is March 5th. Gate: 4821 · Door: 7392. Any questions, just text!',         '2026-02-18 09:00:00'),
    ('SMS-006', 5, '+14155557821', '+18185550001', 'inbound',  'Thank you! Any chance we could do a 1pm early check-in instead of 3pm?',                     '2026-02-18 09:45:00'),
    ('SMS-007', 5, '+14155557821', '+18185550001', 'outbound', 'Let me check with housekeeping and get back to you by end of day!',                           '2026-02-18 09:50:00');

-- Marcus Johnson (guest_id=2)
INSERT INTO openphone_sms_messages (openphone_sms_id, guest_id, guest_phone, our_phone, direction, body, sent_at) VALUES
    ('SMS-010', 2, '+13105554392', '+18185550001', 'inbound',  'Hi! Marcus here. Just confirmed Beach House 1. Really looking forward to it.',                '2026-01-28 08:55:00'),
    ('SMS-011', 2, '+13105554392', '+18185550001', 'outbound', 'Great to hear from you Marcus! Excited to host you. Anything I can help with?',               '2026-01-28 09:10:00'),
    ('SMS-012', 2, '+13105554392', '+18185550001', 'outbound', 'Marcus — check-in day! Lock code is #2249. Text if anything comes up. Enjoy!',               '2026-02-01 08:00:00'),
    ('SMS-013', 2, '+13105554392', '+18185550001', 'inbound',  'Quick heads up — the garbage disposal isn''t working. Not urgent.',                           '2026-02-07 14:20:00'),
    ('SMS-014', 2, '+13105554392', '+18185550001', 'outbound', 'So sorry! We''ll fix it during turnover. Do you need it working before checkout tomorrow?',   '2026-02-07 14:35:00'),
    ('SMS-015', 2, '+13105554392', '+18185550001', 'inbound',  'No worries, we managed fine. Thanks for the quick reply!',                                    '2026-02-07 14:50:00'),
    ('SMS-016', 2, '+13105554392', '+18185550001', 'outbound', 'Hope checkout was smooth! Thanks for taking great care of the place. A review would mean the world!', '2026-02-08 12:00:00');

-- Emily Rodriguez (guest_id=3)
INSERT INTO openphone_sms_messages (openphone_sms_id, guest_id, guest_phone, our_phone, direction, body, sent_at) VALUES
    ('SMS-020', 3, '+17145558834', '+18185550001', 'inbound',  'Hi! Emily here. Looking forward to Mountain Cabin A! Is snowshoeing gear available?',         '2026-02-10 10:30:00'),
    ('SMS-021', 3, '+17145558834', '+18185550001', 'outbound', 'Hi Emily! Two pairs of snowshoes in the garage + sleds for the hills. Super fun!',            '2026-02-10 10:42:00'),
    ('SMS-022', 3, '+17145558834', '+18185550001', 'outbound', 'Emily — confirming Feb 25 arrival at Mountain Cabin A. Door code: 6614. Can''t wait!',        '2026-02-18 09:00:00'),
    ('SMS-023', 3, '+17145558834', '+18185550001', 'inbound',  'Perfect! We are so excited. Will the hot tub be cleaned and ready?',                          '2026-02-18 09:30:00'),
    ('SMS-024', 3, '+17145558834', '+18185550001', 'outbound', 'Absolutely — hot tub will be fresh and set to 104°F for your arrival.',                      '2026-02-18 09:45:00');

-- -----------------------------------------------------------------------------
-- GMAIL THREADS & EMAILS
-- gmail_threads.guest_id points to the surrogate active at time of first email.
-- -----------------------------------------------------------------------------

-- Thread 1: Marcus Johnson / Beach House 1
INSERT INTO gmail_threads (id, gmail_thread_id, subject, guest_id, reservation_id) VALUES
    (1, 'GT-001', 'Reservation Confirmation — Beach House 1, Feb 1-8 | Booking #R-1001', 2, 1);

INSERT INTO gmail_emails (gmail_message_id, thread_id, from_email, to_email, subject, body_text, sent_at, labels) VALUES
    ('GM-001', 1, 'host@propertymgmt.com', 'marcus.j@outlook.com',
     'Reservation Confirmation — Beach House 1, Feb 1-8 | Booking #R-1001',
     'Dear Marcus, Thank you for booking Beach House 1 for February 1-8. Booking #R-1001 confirmed. Total: $1,540. Check-in 3pm, check-out 11am. Full instructions 48 hours before arrival. Don''t hesitate to reach out. Warm regards, The Management Team',
     '2026-01-25 10:00:00', '["inbox","sent","reservation"]'),
    ('GM-002', 1, 'marcus.j@outlook.com', 'host@propertymgmt.com',
     'Re: Reservation Confirmation — Beach House 1, Feb 1-8 | Booking #R-1001',
     'Thanks for the confirmation! Two questions: is the kayak available for guests? And we''re hoping to bring our dog — is the property pet-friendly?',
     '2026-01-25 14:22:00', '["inbox","reservation"]'),
    ('GM-003', 1, 'host@propertymgmt.com', 'marcus.j@outlook.com',
     'Re: Reservation Confirmation — Beach House 1, Feb 1-8 | Booking #R-1001',
     'Hi Marcus! Kayak is available — stored in the dock shed with life vests. And yes, Beach House 1 is pet-friendly! Added a $50 pet deposit; you''ll see the updated total in the Airbnb app. Looking forward to hosting you and your pup! The Management Team',
     '2026-01-26 09:15:00', '["inbox","sent","reservation"]');

-- Thread 2: Sarah Chen / Cottage 3 (guest_id=1, v1 was active on Feb 18 when email was sent)
INSERT INTO gmail_threads (id, gmail_thread_id, subject, guest_id, reservation_id) VALUES
    (2, 'GT-002', 'Pre-Arrival Instructions — Cottage 3, March 5-10 | Booking #R-1003', 1, 3);

INSERT INTO gmail_emails (gmail_message_id, thread_id, from_email, to_email, subject, body_text, sent_at, labels) VALUES
    ('GM-010', 2, 'host@propertymgmt.com', 'sarah.chen@gmail.com',
     'Pre-Arrival Instructions — Cottage 3, March 5-10 | Booking #R-1003',
     'Dear Sarah, Your stay at Cottage 3 is almost here! Gate: 4821 · Door: 7392 · Check-in: 3pm (early may be possible — text us). Parking: 2-car garage + driveway. WiFi: CottageGuest / lake2024. Hot tub is heated. Firewood on back porch. We can''t wait to host you! The Management Team',
     '2026-02-18 09:00:00', '["inbox","sent","check-in"]'),
    ('GM-011', 2, 'sarah.chen@gmail.com', 'host@propertymgmt.com',
     'Re: Pre-Arrival Instructions — Cottage 3, March 5-10 | Booking #R-1003',
     'Thank you! This is so helpful. We texted about a 1pm arrival — has that been confirmed? Also, what''s the cell service like at the property?',
     '2026-02-18 10:30:00', '["inbox","check-in"]'),
    ('GM-012', 2, 'host@propertymgmt.com', 'sarah.chen@gmail.com',
     'Re: Pre-Arrival Instructions — Cottage 3, March 5-10 | Booking #R-1003',
     'Hi Sarah! Great news — 1pm early check-in confirmed, no extra charge. Cell service: 1-2 bars AT&T/T-Mobile in most areas; WiFi is very reliable at 500 Mbps. See you March 5th! The Management Team',
     '2026-02-19 11:00:00', '["inbox","sent","check-in"]');

-- Thread 3: Emily Rodriguez / Mountain Cabin A
INSERT INTO gmail_threads (id, gmail_thread_id, subject, guest_id, reservation_id) VALUES
    (3, 'GT-003', 'Your Upcoming Stay — Mountain Cabin A, Feb 25-Mar 1 | Booking #R-1002', 3, 2);

INSERT INTO gmail_emails (gmail_message_id, thread_id, from_email, to_email, subject, body_text, sent_at, labels) VALUES
    ('GM-020', 3, 'host@propertymgmt.com', 'emily.r@yahoo.com',
     'Your Upcoming Stay — Mountain Cabin A, Feb 25-Mar 1 | Booking #R-1002',
     'Dear Emily, We''re so excited to welcome you to Mountain Cabin A! Door: 6614 · Check-in: 4pm. Two king bedrooms + queen loft (sleeps 6). Hot tub cleaned day-of. Two snowshoe pairs in garage. Ski resorts 20 min away. Pantry stocked with breakfast basics. See you soon! The Management Team',
     '2026-02-12 10:00:00', '["inbox","sent","reservation"]'),
    ('GM-021', 3, 'emily.r@yahoo.com', 'host@propertymgmt.com',
     'Re: Your Upcoming Stay — Mountain Cabin A, Feb 25-Mar 1 | Booking #R-1002',
     'This looks wonderful, thank you! We''ll have 4 adults, no children. Is there a grocery store within 15 minutes? Also — is there a good spot for stargazing?',
     '2026-02-14 09:45:00', '["inbox","reservation"]'),
    ('GM-022', 3, 'host@propertymgmt.com', 'emily.r@yahoo.com',
     'Re: Your Upcoming Stay — Mountain Cabin A, Feb 25-Mar 1 | Booking #R-1002',
     'Hi Emily! 4 adults is perfect. There''s a Safeway about 12 minutes away (address in your door-code text). Stargazing is INCREDIBLE from the back deck — zero light pollution. Hot tub + clear sky is our guests'' favorite combo. You are going to love it! The Management Team',
     '2026-02-14 14:00:00', '["inbox","sent","reservation"]');

-- -----------------------------------------------------------------------------
-- DISCORD CHANNELS
-- property_id references the current property surrogate (fine — channels are
-- created once and linked to the long-lived property, not a specific version).
-- -----------------------------------------------------------------------------
INSERT INTO discord_channels (id, discord_channel_id, channel_name, server_name, property_id) VALUES
    (1, 'DC-001', 'cottage-3-ops',        'Property Ops HQ', 1),
    (2, 'DC-002', 'beach-house-1-ops',    'Property Ops HQ', 5),
    (3, 'DC-003', 'mountain-cabin-a-ops', 'Property Ops HQ', 3),
    (4, 'DC-004', 'general',              'Property Ops HQ', NULL);

-- -----------------------------------------------------------------------------
-- DISCORD MESSAGES — Cottage 3 Maintenance (February 2026)
-- -----------------------------------------------------------------------------
INSERT INTO discord_messages (discord_message_id, channel_id, author_username, author_display_name, content, sent_at) VALUES
    ('DM-001', 1, 'mgr_tony',    'Tony (Manager)',
     'Heads up — guest in Cottage 3 reported the hot tub isn''t heating to temp. Came in about an hour ago.',
     '2026-02-03 11:15:00'),
    ('DM-002', 1, 'ops_rena',    'Rena (Ops)',
     'On it. Pool tech Marco is available tomorrow morning — scheduling him for 9am.',
     '2026-02-03 11:30:00'),
    ('DM-003', 1, 'vendor_marco','Marco (Pool Tech)',
     'Hot tub issue at Cottage 3 resolved. Replaced the faulty heating element. Running at 104°F.',
     '2026-02-04 10:45:00'),
    ('DM-004', 1, 'ops_rena',    'Rena (Ops)',
     'HVAC filter at Cottage 3 is overdue. Scheduling replacement for the Feb 15 turnover window.',
     '2026-02-12 14:00:00'),
    ('DM-005', 1, 'hskp_linda',  'Linda (Housekeeping)',
     'Cottage 3 turnover complete. HVAC filter replaced. Also caught a small leak under the kitchen sink — fixed on the spot. All clear.',
     '2026-02-15 16:20:00'),
    ('DM-006', 1, 'mgr_tony',    'Tony (Manager)',
     'New issue at Cottage 3: current guest reporting a broken window blind in the master bedroom. Adding to punch list for next turnover.',
     '2026-02-17 09:00:00'),
    ('DM-007', 1, 'hskp_linda',  'Linda (Housekeeping)',
     'Replaced the blind in Cottage 3 master bedroom during today''s inspection. Looks great. Marking resolved.',
     '2026-02-20 13:10:00');

-- Non-maintenance Cottage 3 messages
INSERT INTO discord_messages (discord_message_id, channel_id, author_username, author_display_name, content, sent_at) VALUES
    ('DM-008', 1, 'ops_rena', 'Rena (Ops)',
     'Cottage 3 turnover confirmed for March 4 in prep for March 5-10 booking (Sarah Chen, VRBO).',
     '2026-02-20 09:00:00');

-- Beach House 1 ops
INSERT INTO discord_messages (discord_message_id, channel_id, author_username, author_display_name, content, sent_at, reservation_id) VALUES
    ('DM-010', 2, 'ops_rena',         'Rena (Ops)',
     'Marcus Johnson checked in at Beach House 1. Smooth arrival, no issues. Pet deposit collected.',
     '2026-02-01 15:30:00', 1),
    ('DM-011', 2, 'hskp_linda',       'Linda (Housekeeping)',
     'Marcus Johnson checked out of Beach House 1. Property in great shape. Left a thank-you card!',
     '2026-02-08 11:15:00', 1),
    ('DM-012', 2, 'mgr_tony',         'Tony (Manager)',
     'Garbage disposal at Beach House 1 needs repair before next guest. Scheduling maintenance for Feb 10.',
     '2026-02-08 12:00:00', NULL),
    ('DM-013', 2, 'vendor_handyman',  'Jake (Handyman)',
     'Beach House 1 garbage disposal replaced. Tightened a loose towel rack in main bath while there. All good.',
     '2026-02-10 14:30:00', NULL);

-- Mountain Cabin A pre-arrival prep
INSERT INTO discord_messages (discord_message_id, channel_id, author_username, author_display_name, content, sent_at, reservation_id) VALUES
    ('DM-020', 3, 'ops_rena',   'Rena (Ops)',
     'Mountain Cabin A prep for Emily Rodriguez (Feb 25). Hot tub service booked Feb 24, housekeeping at 2pm. Stocking pantry basics.',
     '2026-02-18 10:00:00', 2),
    ('DM-021', 3, 'mgr_tony',   'Tony (Manager)',
     'Reminder: the Mountain Cabin A driveway had ice accumulation last week. Confirm salt/sand is stocked before Emily''s arrival.',
     '2026-02-19 09:30:00', 2);

-- General channel
INSERT INTO discord_messages (discord_message_id, channel_id, author_username, author_display_name, content, sent_at) VALUES
    ('DM-030', 4, 'mgr_tony', 'Tony (Manager)',
     'Team reminder: 3 properties active this weekend. Cottage 3 occupied, Beach House 1 turning over, Mountain Cabin A prepping. Stay sharp!',
     '2026-02-20 08:00:00');
