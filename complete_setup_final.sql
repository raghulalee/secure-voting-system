-- =====================================================================
-- ULTIMATE ONE-SHOT SETUP SCRIPT — SECURE VOTING SYSTEM
-- Run this in your Supabase SQL Editor.
-- (Targets the 'public' schema for simplicity)
-- =================================------------------------------------

-- ---------------------------------------------------------
-- 1. CLEANUP (Fixes Foreign Key Errors)
-- ---------------------------------------------------------
DROP TABLE IF EXISTS election_results CASCADE;
DROP TABLE IF EXISTS votes CASCADE;
DROP TABLE IF EXISTS vote_tracking CASCADE;
DROP TABLE IF EXISTS candidates CASCADE;
DROP TABLE IF EXISTS elections CASCADE;
DROP TABLE IF EXISTS auth_logs CASCADE;
DROP TABLE IF EXISTS credentials CASCADE;
DROP TABLE IF EXISTS voters CASCADE;
DROP TABLE IF EXISTS admin_users CASCADE;

-- ---------------------------------------------------------
-- 2. CORE TABLES
-- ---------------------------------------------------------

CREATE TABLE voters (
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
    photo_url TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE credentials (
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

CREATE TABLE admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    photo_url TEXT, -- New: Admin profile pic support
    role VARCHAR(50) DEFAULT 'admin',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE auth_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credential_id UUID,
    action VARCHAR(50) NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE elections (
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

CREATE TABLE candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id UUID REFERENCES elections(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    party VARCHAR(100),
    symbol VARCHAR(50),
    photo_url TEXT,
    manifesto TEXT,
    position INTEGER DEFAULT 0,
    age INTEGER,
    locality TEXT,
    state TEXT,
    district TEXT,
    timings TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE vote_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id UUID REFERENCES elections(id) ON DELETE CASCADE,
    voter_hash VARCHAR(255) NOT NULL,
    cast_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(election_id, voter_hash)
);

CREATE TABLE votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id UUID REFERENCES elections(id) ON DELETE CASCADE,
    encrypted_vote TEXT NOT NULL,
    cryptographic_hash VARCHAR(255) UNIQUE NOT NULL,
    cast_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE election_results (
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
-- 3. DEFAULT DATA
-- ---------------------------------------------------------

-- Admin (Username: admin, Password: 114462)
INSERT INTO admin_users (username, password_hash, full_name, email, role, photo_url)
VALUES (
    'admin',
    '$2b$12$NQxJzSc47GQTjb2Cdkruuup1ByuMiM5NqhMRwI.Cot2djNtS4/una',
    'System Administrator',
    'admin@kitssvoting.edu.in',
    'super_admin',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&q=80'
);

-- Demo Voter (Username: voter, Password: voter)
INSERT INTO voters (id, full_name, voter_id, email, district, state, photo_url, address, date_of_birth)
VALUES (
    'ba141111-1111-4111-8111-111111111111',
    'Demo Voter (Student)',
    'VTR001',
    'voter@kitssvoting.edu.in',
    'Karimnagar',
    'Telangana',
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&q=80',
    'Science Block, Room 101',
    '2003-01-01'
);

INSERT INTO credentials (voter_profile_id, username, password_hash)
VALUES (
    'ba141111-1111-4111-8111-111111111111',
    'voter',
    '$2b$12$fBClN9oAHL4fAwk6VrzlnuGfKVHWqTAQiWL7WWf5hnToq4UFbkCGe'
);

-- Demo Election
INSERT INTO elections (id, title, description, election_type, start_date, end_date, status)
VALUES (
    'd3e01234-5678-4a12-8d34-ef56ba789012',
    'Demo: University Student Council 2025',
    'A demonstration election featuring complete profiles, real-time charts, and Antigravity UI.',
    'university',
    '2025-01-01T00:00:00+00:00',
    '2025-01-02T00:00:00+00:00',
    'completed'
);

INSERT INTO candidates (id, election_id, name, party, symbol, photo_url, manifesto, position, age, locality, state, district, timings) VALUES
('c1e14111-1111-4111-8111-111111111111', 'd3e01234-5678-4a12-8d34-ef56ba789012', 'Nova Quantum', 'Innovation Party', '🚀', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&q=80', 'Focusing on advanced AI research funding, better UI/UX for all campus systems, and Antigravity tech.', 1, 22, 'Campus North', 'Telangana', 'Karimnagar', '10:00 AM - 4:00 PM'),
('c2e24222-2222-4222-8222-222222222222', 'd3e01234-5678-4a12-8d34-ef56ba789012', 'Dr. Alexander Flux', 'Science First', '⚛️', 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&q=80', 'Dedicated to expanding laboratory equipment and establishing new computing clusters.', 2, 24, 'Science Block', 'Telangana', 'Hyderabad', '9:00 AM - 2:00 PM'),
('c3e34333-3333-4333-8333-333333333333', 'd3e01234-5678-4a12-8d34-ef56ba789012', 'Sarah Nebula', 'Traditionalists', '🏛️', 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&q=80', 'Ensuring steady and stable growth while maintaining our university core values and heritage.', 3, 21, 'Main Hostels', 'Telangana', 'Warangal', '4:00 PM - 8:00 PM');

INSERT INTO election_results (election_id, candidate_id, vote_count, percentage, is_winner) VALUES
('d3e01234-5678-4a12-8d34-ef56ba789012', 'c1e14111-1111-4111-8111-111111111111', 450, 52.94, true),
('d3e01234-5678-4a12-8d34-ef56ba789012', 'c2e24222-2222-4222-8222-222222222222', 250, 29.41, false),
('d3e01234-5678-4a12-8d34-ef56ba789012', 'c3e34333-3333-4333-8333-333333333333', 150, 17.65, false);

INSERT INTO vote_tracking (election_id, voter_hash)
SELECT 'd3e01234-5678-4a12-8d34-ef56ba789012', md5(random()::text) FROM generate_series(1, 100);

-- DONE.
