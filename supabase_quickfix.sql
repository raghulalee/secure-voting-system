-- =====================================================================
-- QUICKFIX SQL — Run this in Supabase SQL Editor
-- (Safe to run multiple times — no conflicts)
-- =====================================================================

-- 1. Fix admin password → admin / 114462
INSERT INTO admin_users (username, password_hash, full_name, email, role)
VALUES (
    'admin',
    '$2b$12$JYT9BSpbdmpegSy8bq5U/uYaTaFEmsy1dWuIwQpM8jx/RfR7Tv0IK',
    'System Administrator',
    'admin@kitssvoting.edu.in',
    'super_admin'
) ON CONFLICT (username) DO UPDATE SET
    password_hash = EXCLUDED.password_hash;

-- 2. Create Karimnagar District Election
INSERT INTO elections (id, title, description, election_type, start_date, end_date, status, total_eligible_voters)
VALUES (
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Karimnagar District Parliamentary Election 2026',
    'General Election for Karimnagar Parliamentary Constituency, Telangana. All eligible voters from Karimnagar district can participate. Cast your vote for your preferred party.',
    'general',
    '2026-03-11T00:00:00+05:30',
    '2026-03-31T23:59:59+05:30',
    'active',
    500000
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    status = 'active';

-- 3. Remove old candidates for this election (clean slate)
DELETE FROM candidates WHERE election_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- 4. Add the 4 parties with images
INSERT INTO candidates (election_id, name, party, symbol, photo_url, manifesto, position) VALUES
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Bandi Sanjay Kumar',
    'Bharatiya Janata Party (BJP)',
    '🪷',
    '/images/bjp.png',
    'Development of Karimnagar through infrastructure, employment generation, and national integration. Committed to building a stronger Telangana within a united India. Sabka Saath, Sabka Vikas.',
    1
),
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Kavitha Reddy',
    'Jagruti Party',
    '🌅',
    '/images/jagruti.png',
    'Social awareness and empowerment of all communities. Focus on youth education, women safety, digital governance, and transparent administration for Karimnagar.',
    2
),
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Vinod Kumar B.',
    'Bharat Rashtra Samithi (BRS)',
    '🚗',
    '/images/brs.png',
    'Bangaru Telangana vision for Karimnagar. Irrigation projects like Kaleshwaram, farmer welfare with Rythu Bandhu, and continued development of the district.',
    3
),
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Ponnam Prabhakar',
    'Indian National Congress (INC)',
    '✋',
    '/images/congress.png',
    'Empowerment of all sections of society. Focus on healthcare, education reforms, MGNREGA strengthening, and employment for Karimnagar youth.',
    4
);

-- =====================================================================
-- DONE! 
-- Admin: username=admin, password=114462
-- Election: Karimnagar District Parliamentary Election 2026 (ACTIVE)
-- Parties: BJP, Jagruti, BRS, Congress
-- =====================================================================
