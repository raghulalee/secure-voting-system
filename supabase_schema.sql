-- =====================================================================
-- SECURE ONLINE VOTING SYSTEM - Multi-Database Architecture
-- Supabase PostgreSQL Schema
-- 
-- INSTRUCTIONS: Copy this entire file and paste into
-- Supabase Dashboard → SQL Editor → New Query → Run
-- =====================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================================
-- DATABASE 1: VOTER REGISTRY (voter personal information)
-- =====================================================================

CREATE TABLE IF NOT EXISTS voter_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    voter_id VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(15),
    date_of_birth DATE NOT NULL,
    gender VARCHAR(10) CHECK (gender IN ('Male', 'Female', 'Other')),
    address TEXT,
    district VARCHAR(100),
    state VARCHAR(100) DEFAULT 'Telangana',
    photo_url TEXT,
    is_eligible BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- DATABASE 2: AUTHENTICATION STORE (credentials & security)
-- =====================================================================

CREATE TABLE IF NOT EXISTS voter_credentials (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    voter_profile_id UUID REFERENCES voter_profiles(id) ON DELETE CASCADE,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    otp_secret TEXT,
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMPTZ,
    failed_attempts INT DEFAULT 0,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    credential_id UUID REFERENCES voter_credentials(id),
    action VARCHAR(50) NOT NULL,  -- 'login', 'logout', 'failed_login', 'otp_verify'
    ip_address VARCHAR(45),
    user_agent TEXT,
    status VARCHAR(20) NOT NULL,  -- 'success', 'failed', 'blocked'
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS admin_users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(50) DEFAULT 'admin' CHECK (role IN ('admin', 'super_admin')),
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- DATABASE 3: BALLOT BOX (elections, candidates, encrypted votes)
-- =====================================================================

CREATE TABLE IF NOT EXISTS elections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    election_type VARCHAR(50) NOT NULL CHECK (election_type IN ('general', 'university', 'organization')),
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'active', 'paused', 'completed', 'cancelled')),
    total_eligible_voters INT DEFAULT 0,
    created_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS candidates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    election_id UUID REFERENCES elections(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    party VARCHAR(255),
    symbol VARCHAR(100),
    photo_url TEXT,
    manifesto TEXT,
    position INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS votes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    election_id UUID REFERENCES elections(id),
    encrypted_vote TEXT NOT NULL,
    vote_hash TEXT UNIQUE NOT NULL,
    voter_token TEXT UNIQUE NOT NULL,  -- anonymous token, NOT linked to voter identity
    cast_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vote_tracking (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    election_id UUID REFERENCES elections(id),
    voter_hash TEXT NOT NULL,  -- SHA-256 hash of voter_id, NOT the actual voter_id
    has_voted BOOLEAN DEFAULT true,
    voted_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(election_id, voter_hash)
);

CREATE TABLE IF NOT EXISTS election_results (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    election_id UUID REFERENCES elections(id),
    candidate_id UUID REFERENCES candidates(id),
    vote_count INT DEFAULT 0,
    percentage DECIMAL(5,2) DEFAULT 0,
    is_winner BOOLEAN DEFAULT false,
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(election_id, candidate_id)
);

-- =====================================================================
-- INDEXES for performance
-- =====================================================================

CREATE INDEX IF NOT EXISTS idx_voter_profiles_voter_id ON voter_profiles(voter_id);
CREATE INDEX IF NOT EXISTS idx_voter_profiles_email ON voter_profiles(email);
CREATE INDEX IF NOT EXISTS idx_voter_credentials_username ON voter_credentials(username);
CREATE INDEX IF NOT EXISTS idx_voter_credentials_profile ON voter_credentials(voter_profile_id);
CREATE INDEX IF NOT EXISTS idx_auth_logs_credential ON auth_logs(credential_id);
CREATE INDEX IF NOT EXISTS idx_auth_logs_created ON auth_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_elections_status ON elections(status);
CREATE INDEX IF NOT EXISTS idx_elections_dates ON elections(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_candidates_election ON candidates(election_id);
CREATE INDEX IF NOT EXISTS idx_votes_election ON votes(election_id);
CREATE INDEX IF NOT EXISTS idx_vote_tracking_election ON vote_tracking(election_id);
CREATE INDEX IF NOT EXISTS idx_vote_tracking_voter ON vote_tracking(voter_hash);
CREATE INDEX IF NOT EXISTS idx_election_results_election ON election_results(election_id);

-- =====================================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================================

ALTER TABLE voter_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE voter_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE elections ENABLE ROW LEVEL SECURITY;
ALTER TABLE candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE vote_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE election_results ENABLE ROW LEVEL SECURITY;

-- Service role has full access (used by backend)
CREATE POLICY "Service role full access" ON voter_profiles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access" ON voter_credentials FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access" ON auth_logs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access" ON admin_users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access" ON elections FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access" ON candidates FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access" ON votes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access" ON vote_tracking FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access" ON election_results FOR ALL USING (true) WITH CHECK (true);

-- =====================================================================
-- AUTO-UPDATE TIMESTAMP TRIGGER
-- =====================================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_voter_profiles_updated
    BEFORE UPDATE ON voter_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_voter_credentials_updated
    BEFORE UPDATE ON voter_credentials
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_elections_updated
    BEFORE UPDATE ON elections
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =====================================================================
-- SEED DATA: Default Admin Account
-- Username: admin | Password: 114462
-- =====================================================================

INSERT INTO admin_users (username, password_hash, full_name, email, role)
VALUES (
    'admin',
    '$2b$12$JYT9BSpbdmpegSy8bq5U/uYaTaFEmsy1dWuIwQpM8jx/RfR7Tv0IK',
    'System Administrator',
    'admin@kitssvoting.edu.in',
    'super_admin'
) ON CONFLICT (username) DO UPDATE SET
    password_hash = EXCLUDED.password_hash;

-- =====================================================================
-- DEMO DATA: Karimnagar District General Election (BJP National)
-- =====================================================================

INSERT INTO elections (id, title, description, election_type, start_date, end_date, status, total_eligible_voters)
VALUES (
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Karimnagar District Parliamentary Election 2026',
    'General Election for Karimnagar Parliamentary Constituency, Telangana. All eligible voters from Karimnagar district can participate in this democratic process.',
    'general',
    '2026-03-11T00:00:00+05:30',
    '2026-03-31T23:59:59+05:30',
    'active',
    500000
) ON CONFLICT (id) DO NOTHING;

-- Candidates
INSERT INTO candidates (election_id, name, party, symbol, manifesto, position) VALUES
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Bandi Sanjay Kumar',
    'Bharatiya Janata Party (BJP)',
    '🪷',
    'Development of Karimnagar through infrastructure, employment generation, and national integration. Committed to building a stronger Telangana within a united India.',
    1
),
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Vinod Kumar Boianapalli',
    'Telangana Rashtra Samithi (BRS)',
    '🚗',
    'Continued development of Telangana through Bangaru Telangana vision. Focus on irrigation projects, farmer welfare, and social justice programs.',
    2
),
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Ponnam Prabhakar',
    'Indian National Congress (INC)',
    '✋',
    'Empowerment of all sections of society, focus on education, healthcare, and employment opportunities for youth of Karimnagar.',
    3
),
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Srinivas Reddy',
    'Independent',
    '⭐',
    'Local governance focus with emphasis on civic infrastructure, clean water, road development, and transparent administration.',
    4
)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- DONE! Your multi-database architecture is ready.
-- 
-- Database 1 (Voter Registry): voter_profiles
-- Database 2 (Auth Store): voter_credentials, auth_logs, admin_users
-- Database 3 (Ballot Box): elections, candidates, votes, vote_tracking, election_results
--
-- Admin Login: username=admin, password=114462
-- =====================================================================
