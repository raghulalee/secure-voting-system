-- QUICK FIX: Add participation tracking to voters table
ALTER TABLE voters ADD COLUMN IF NOT EXISTS has_voted BOOLEAN DEFAULT FALSE;

-- Optional: Re-sync schema cache
NOTIFY pgrst, 'reload schema';
