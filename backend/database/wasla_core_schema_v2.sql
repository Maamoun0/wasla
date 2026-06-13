-- ========================================================================================
-- WASLA SMART CLASSIFIEDS PLATFORM - DATABASE SCHEMA v2.0 (PostgreSQL / Supabase)
-- EXECUTION PHASE: Part 1 (Core Domains)
-- ========================================================================================

-- 0. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis"; -- For geographical proximity queries
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For text search

-- ==========================================
-- DOMAIN 1: GEO (الجغرافيا)
-- ==========================================
CREATE TABLE governorates (
    id SERIAL PRIMARY KEY,
    name_ar VARCHAR(50) NOT NULL,
    name_en VARCHAR(50) NOT NULL
);

CREATE TABLE cities (
    id SERIAL PRIMARY KEY,
    governorate_id INT REFERENCES governorates(id) ON DELETE CASCADE,
    name_ar VARCHAR(50) NOT NULL,
    name_en VARCHAR(50) NOT NULL,
    coordinates GEOMETRY(Point, 4326) -- PostGIS Point (Lng, Lat)
);

CREATE TABLE districts (
    id SERIAL PRIMARY KEY,
    city_id INT REFERENCES cities(id) ON DELETE CASCADE,
    name_ar VARCHAR(50) NOT NULL,
    name_en VARCHAR(50) NOT NULL
);

-- ==========================================
-- DOMAIN 2: AUTH & SECURITY (المصادقة والأمان)
-- ==========================================
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(30) UNIQUE NOT NULL, -- 'guest', 'regular', 'verified', 'business', 'admin'
    permissions JSONB DEFAULT '{}'::JSONB
);

-- Link to Supabase Auth
CREATE TABLE users (
    id UUID PRIMARY KEY, -- Maps to auth.users.id
    phone_number VARCHAR(20) UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    role_id INT REFERENCES roles(id),
    district_id INT REFERENCES districts(id),
    verification_status VARCHAR(20) DEFAULT 'unverified' CHECK (verification_status IN ('unverified', 'pending', 'verified', 'rejected')),
    trust_score DECIMAL(3,2) DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- KYC / Verifications
CREATE TABLE user_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    id_front_url TEXT NOT NULL,
    id_back_url TEXT NOT NULL,
    selfie_url TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    moderator_id UUID REFERENCES users(id),
    rejection_reason TEXT,
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ
);

-- Safety
CREATE TABLE user_blocks (
    blocker_id UUID REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id)
);

-- ==========================================
-- DOMAIN 3: CATEGORIES & DYNAMIC EAV (الأقسام)
-- ==========================================
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    parent_id INT REFERENCES categories(id) ON DELETE CASCADE,
    name_ar VARCHAR(100) NOT NULL,
    name_en VARCHAR(100) NOT NULL,
    icon_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INT DEFAULT 0
);

CREATE TABLE category_fields (
    id SERIAL PRIMARY KEY,
    category_id INT REFERENCES categories(id) ON DELETE CASCADE,
    field_name VARCHAR(50) NOT NULL, -- e.g., 'mileage', 'hourly_rate'
    field_type VARCHAR(20) NOT NULL, -- 'text', 'number', 'boolean', 'dropdown'
    is_required BOOLEAN DEFAULT FALSE,
    options JSONB -- For dropdowns: ["manual", "automatic"]
);

-- ==========================================
-- DOMAIN 4: ADS & SEARCH (الإعلانات - JSONB Optimized)
-- ==========================================
CREATE TABLE ads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    category_id INT REFERENCES categories(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(12,2),
    currency VARCHAR(10) DEFAULT 'EGP',
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('draft', 'pending', 'active', 'sold', 'expired', 'rejected')),
    district_id INT REFERENCES districts(id),
    location_coords GEOMETRY(Point, 4326),
    
    -- 🚀 PERFORMANCE SECRET: Instead of JOINing 5 tables to search for a "Red Automatic Car",
    -- we store the EAV output here as a JSONB object.
    search_attributes JSONB DEFAULT '{}'::JSONB,
    
    views_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- JSONB GIN INDEX (The core of the V2.0 speed upgrade)
CREATE INDEX idx_ads_search_attributes ON ads USING GIN (search_attributes);
-- Geospatial Index
CREATE INDEX idx_ads_location ON ads USING GIST (location_coords);

CREATE TABLE ad_media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ad_id UUID REFERENCES ads(id) ON DELETE CASCADE,
    media_url TEXT NOT NULL,
    media_type VARCHAR(10) DEFAULT 'image',
    is_primary BOOLEAN DEFAULT FALSE,
    sort_order INT DEFAULT 0
);

-- ==========================================
-- DOMAIN 5: CHAT & NEGOTIATIONS (الدردشة)
-- ==========================================
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ad_id UUID REFERENCES ads(id) ON DELETE CASCADE,
    buyer_id UUID REFERENCES users(id),
    seller_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (ad_id, buyer_id) -- Prevent duplicate chats for the same ad
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id),
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- DOMAIN 6: SERVICE BOOKINGS (حجوزات العمالة)
-- ==========================================
CREATE TABLE service_bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ad_id UUID REFERENCES ads(id), -- The worker's profile/service ad
    customer_id UUID REFERENCES users(id),
    worker_id UUID REFERENCES users(id),
    scheduled_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'in_progress', 'completed', 'cancelled')),
    customer_notes TEXT,
    agreed_price DECIMAL(10,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
