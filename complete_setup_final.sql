-- =====================================================================
-- COMPLETE & UNIFIED SETUP SCRIPT — SECURE VOTING SYSTEM
-- Run this ONCE in your Supabase SQL Editor.
-- It works safely even if run multiple times (uses IF NOT EXISTS).
-- =====================================================================

-- ---------------------------------------------------------
-- 1. VOTERS & AUTHENTICATION TABLES
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS voters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(150) NOT NULL,
    voter_id VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(20),
    date_of_birth DATE NOT NULL,
    gender VARCHAR(20),
    address TEXT,
    district VARCHAR(100),
    state VARCHAR(100),
    photo_url TEXT, -- Newly added Profile Picture URL! 
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure photo_url is present if table already existed
ALTER TABLE voters ADD COLUMN IF NOT EXISTS photo_url TEXT;

CREATE TABLE IF NOT EXISTS credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voter_profile_id UUID REFERENCES voters(id) ON DELETE CASCADE,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    failed_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credential_id UUID, -- Can be voter or admin
    action VARCHAR(50) NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 2. ADMIN TABLE & DEFAULT ADMIN USER
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    role VARCHAR(50) DEFAULT 'admin',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert/Update Default Admin (Username: admin, Password: 1162)
INSERT INTO admin_users (username, password_hash, full_name, email, role)
VALUES (
    'admin',
    '$2b$12$vw.LjnZLyMLyn01ibfH2Nut28aVS7GEqyFMvKoaQIVQ9yoByOrltu', -- Hash for "1162"
    'System Administrator',
    'admin@kitssvoting.edu.in',
    'super_admin'
) ON CONFLICT (username) DO UPDATE SET password_hash = EXCLUDED.password_hash;

-- ---------------------------------------------------------
-- 3. ELECTIONS, CANDIDATES, & VOTING TABLES
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS elections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    election_type VARCHAR(50) NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) DEFAULT 'upcoming',
    created_by UUID,
    total_eligible_voters INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id UUID REFERENCES elections(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    party VARCHAR(100),
    symbol VARCHAR(50),
    photo_url TEXT,     -- Professional photo!
    manifesto TEXT,
    position INTEGER DEFAULT 0,
    age INTEGER,        -- Extra metadata!
    locality TEXT,      -- Extra metadata!
    state TEXT,         -- Extra metadata!
    district TEXT,      -- Extra metadata!
    timings TEXT,       -- Extra metadata!
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure new candidate columns are present if table already existed
ALTER TABLE candidates 
ADD COLUMN IF NOT EXISTS photo_url TEXT,
ADD COLUMN IF NOT EXISTS age INTEGER,
ADD COLUMN IF NOT EXISTS locality TEXT,
ADD COLUMN IF NOT EXISTS state TEXT,
ADD COLUMN IF NOT EXISTS district TEXT,
ADD COLUMN IF NOT EXISTS timings TEXT;

CREATE TABLE IF NOT EXISTS vote_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id UUID REFERENCES elections(id) ON DELETE CASCADE,
    voter_hash VARCHAR(255) NOT NULL,
    cast_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(election_id, voter_hash)
);

CREATE TABLE IF NOT EXISTS votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id UUID REFERENCES elections(id) ON DELETE CASCADE,
    encrypted_vote TEXT NOT NULL,
    cryptographic_hash VARCHAR(255) UNIQUE NOT NULL,
    cast_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS election_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id UUID REFERENCES elections(id) ON DELETE CASCADE,
    candidate_id UUID REFERENCES candidates(id) ON DELETE CASCADE,
    vote_count INTEGER DEFAULT 0,
    percentage DECIMAL(5,2) DEFAULT 0.00,
    is_winner BOOLEAN DEFAULT FALSE,
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(election_id, candidate_id)
);

-- ---------------------------------------------------------
-- 4. INSERT DEMO ELECTION & CANDIDATES WITH METADATA
-- ---------------------------------------------------------

INSERT INTO elections (id, title, description, election_type, start_date, end_date, status)
VALUES (
    'd3e01234-5678-4a12-8d34-ef56ba789012',
    'Demo: University Student Council 2025',
    'A demonstration election featuring complete profiles, real-time charts, and Antigravity UI.',
    'university',
    '2025-01-01T00:00:00+00:00',
    '2025-01-02T00:00:00+00:00',
    'completed'
) ON CONFLICT (id) DO UPDATE SET status = 'completed', title = EXCLUDED.title;

-- Clear old demo candidates to re-insert freshly
DELETE FROM candidates WHERE election_id = 'd3e01234-5678-4a12-8d34-ef56ba789012';

INSERT INTO candidates (id, election_id, name, party, symbol, photo_url, manifesto, position, age, locality, state, district, timings) VALUES
('c1e14111-1111-4111-8111-111111111111', 'd3e01234-5678-4a12-8d34-ef56ba789012', 'Nova Quantum', 'Innovation Party', '🚀', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&q=80', 'Focusing on advanced AI research funding, better UI/UX for all campus systems, and Antigravity tech.', 1, 22, 'Campus North', 'Telangana', 'Karimnagar', '10:00 AM - 4:00 PM'),
('c2e24222-2222-4222-8222-222222222222', 'd3e01234-5678-4a12-8d34-ef56ba789012', 'Dr. Alexander Flux', 'Science First', '⚛️', 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&q=80', 'Dedicated to expanding laboratory equipment and establishing new computing clusters.', 2, 24, 'Science Block', 'Telangana', 'Hyderabad', '9:00 AM - 2:00 PM'),
('c3e34333-3333-4333-8333-333333333333', 'd3e01234-5678-4a12-8d34-ef56ba789012', 'Sarah Nebula', 'Traditionalists', '🏛️', 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&q=80', 'Ensuring steady and stable growth while maintaining our university core values and heritage.', 3, 21, 'Main Hostels', 'Telangana', 'Warangal', '4:00 PM - 8:00 PM');

-- Insert Demo Results
DELETE FROM election_results WHERE election_id = 'd3e01234-5678-4a12-8d34-ef56ba789012';
INSERT INTO election_results (election_id, candidate_id, vote_count, percentage, is_winner) VALUES
('d3e01234-5678-4a12-8d34-ef56ba789012', 'c1e14111-1111-4111-8111-111111111111', 450, 52.94, true),
('d3e01234-5678-4a12-8d34-ef56ba789012', 'c2e24222-2222-4222-8222-222222222222', 250, 29.41, false),
('d3e01234-5678-4a12-8d34-ef56ba789012', 'c3e34333-3333-4333-8333-333333333333', 150, 17.65, false);

-- Insert Demo Vote Tracking (Total Votes Count in Dashboard requires this)
DELETE FROM vote_tracking WHERE election_id = 'd3e01234-5678-4a12-8d34-ef56ba789012';
INSERT INTO vote_tracking (election_id, voter_hash)
SELECT 'd3e01234-5678-4a12-8d34-ef56ba789012', md5(random()::text) FROM generate_series(1, 850);

-- ---------------------------------------------------------
-- 5. INSERT DEMO VOTER (Username: voter, Password: voter)
-- ---------------------------------------------------------

-- Create a fixed UUID for the demo voter
-- Insert Voter Profile
INSERT INTO voters (id, full_name, voter_id, email, district, state, photo_url)
VALUES (
    'v0t3r111-1111-4111-8111-111111111111',
    'Demo Voter (Student)',
    'VTR001',
    'voter@kitssvoting.edu.in',
    'Karimnagar',
    'Telangana',
    'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400&q=80'
) ON CONFLICT (voter_id) DO NOTHING;

-- Insert Credentials for the voter
INSERT INTO credentials (voter_profile_id, username, password_hash)
VALUES (
    'v0t3r111-1111-4111-8111-111111111111',
    'voter',
    '$2b$12$fBClN9oAHL4fAwk6VrzlnuGfKVHWqTAQiWL7WWf5hnToq4UFbkCGe' -- password: voter
) ON CONFLICT (username) DO NOTHING;

-- COMPLETE!
