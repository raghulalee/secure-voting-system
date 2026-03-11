-- =====================================================================
-- QUICKFIX SQL — Add Profile & Candidate Detail Columns
-- Run this in your Supabase SQL Editor
-- =====================================================================

-- 1. Add optional profile photo URL for voters
ALTER TABLE voter_schema.voters 
ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- 2. Add extra details for candidates
ALTER TABLE vote_schema.candidates
ADD COLUMN IF NOT EXISTS age INTEGER,
ADD COLUMN IF NOT EXISTS locality TEXT,
ADD COLUMN IF NOT EXISTS state TEXT,
ADD COLUMN IF NOT EXISTS district TEXT,
ADD COLUMN IF NOT EXISTS timings TEXT;

-- 3. Update the existing demo candidates with realistic demo details
UPDATE vote_schema.candidates 
SET age = 22, locality = 'Campus North', state = 'Telangana', district = 'Karimnagar', timings = '10:00 AM - 4:00 PM'
WHERE name = 'Nova Quantum';

UPDATE vote_schema.candidates 
SET age = 24, locality = 'Science Block', state = 'Telangana', district = 'Hyderabad', timings = '9:00 AM - 2:00 PM'
WHERE name = 'Dr. Alexander Flux';

UPDATE vote_schema.candidates 
SET age = 21, locality = 'Main Hostels', state = 'Telangana', district = 'Warangal', timings = '4:00 PM - 8:00 PM'
WHERE name = 'Sarah Nebula';

-- Done. Refresh the page to see changes.
