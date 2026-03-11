-- =====================================================================
-- QUICKFIX SQL — Create a COMPLETED Demo Election with Results
-- Run this in your Supabase SQL Editor
-- =====================================================================

-- 1. Create a Completed Demo Election
INSERT INTO elections (id, title, description, election_type, start_date, end_date, status, total_eligible_voters)
VALUES (
    'd3m0-1234-5678-ab12-cd34ef56gh78',
    'Demo: University Student Council 2025',
    'A demonstration election to showcase the results dashboard, real-time charts, and antigravity UI/UX.',
    'university',
    '2025-01-01T00:00:00+00:00',
    '2025-01-02T00:00:00+00:00',
    'completed',
    1000
) ON CONFLICT (id) DO UPDATE SET status = 'completed', title = EXCLUDED.title, description = EXCLUDED.description;

-- 2. Create Demo Candidates
DELETE FROM candidates WHERE election_id = 'd3m0-1234-5678-ab12-cd34ef56gh78';

INSERT INTO candidates (id, election_id, name, party, symbol, photo_url, manifesto, position) VALUES
('c1nd-1111-1111-1111-111111111111', 'd3m0-1234-5678-ab12-cd34ef56gh78', 'Nova Quantum', 'Innovation Party', '🚀', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&q=80', 'Focusing on advanced AI research funding, better UI/UX for all campus systems, and Antigravity tech.', 1),
('c2nd-2222-2222-2222-222222222222', 'd3m0-1234-5678-ab12-cd34ef56gh78', 'Dr. Alexander Flux', 'Science First', '⚛️', 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&q=80', 'Dedicated to expanding laboratory equipment and establishing new computing clusters.', 2),
('c3nd-3333-3333-3333-333333333333', 'd3m0-1234-5678-ab12-cd34ef56gh78', 'Sarah Nebula', 'Traditionalists', '🏛️', 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&q=80', 'Ensuring steady and stable growth while maintaining our university core values and heritage.', 3);

-- 3. Insert specific results directly
DELETE FROM election_results WHERE election_id = 'd3m0-1234-5678-ab12-cd34ef56gh78';

INSERT INTO election_results (election_id, candidate_id, vote_count, percentage, is_winner) VALUES
('d3m0-1234-5678-ab12-cd34ef56gh78', 'c1nd-1111-1111-1111-111111111111', 450, 52.94, true),
('d3m0-1234-5678-ab12-cd34ef56gh78', 'c2nd-2222-2222-2222-222222222222', 250, 29.41, false),
('d3m0-1234-5678-ab12-cd34ef56gh78', 'c3nd-3333-3333-3333-333333333333', 150, 17.65, false);

-- 4. To make "Total Votes" query work in the dashboard (it counts rows in vote_tracking)
-- We need to insert 850 dummy rows in vote_tracking
DELETE FROM vote_tracking WHERE election_id = 'd3m0-1234-5678-ab12-cd34ef56gh78';

INSERT INTO vote_tracking (election_id, voter_hash)
SELECT 'd3m0-1234-5678-ab12-cd34ef56gh78', md5(random()::text)
FROM generate_series(1, 850);

-- Done! Now refresh your app and go to the Results tab.
