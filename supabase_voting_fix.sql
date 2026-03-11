-- QUICK FIX: Sync 'votes' table with backend column names
-- Run this in Supabase SQL Editor to fix the "Could not find vote_hash" error.

ALTER TABLE votes RENAME COLUMN cryptographic_hash TO vote_hash;
ALTER TABLE votes ADD COLUMN IF NOT EXISTS voter_token VARCHAR(255);

-- Optional: Re-sync schema cache (Postgrest automatically does this, but just in case)
NOTIFY pgrst, 'reload schema';
