-- ========================================================================================
-- WASLA SMART CLASSIFIEDS PLATFORM - DATABASE SCHEMA v2.0 (PostgreSQL / Supabase)
-- EXECUTION PHASE: Part 2 (Interactions, Payments, System)
-- ========================================================================================

-- ==========================================
-- DOMAIN 7: INTERACTIONS (التفاعلات والتقييمات)
-- ==========================================
CREATE TABLE favorites (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    ad_id UUID REFERENCES ads(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, ad_id)
);

CREATE TABLE saved_searches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    search_query JSONB NOT NULL, -- Stores filters like {"category_id": 5, "max_price": 5000}
    notify_email BOOLEAN DEFAULT FALSE,
    notify_push BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reviewer_id UUID REFERENCES users(id),
    reviewed_user_id UUID REFERENCES users(id),
    ad_id UUID REFERENCES ads(id), -- Optional: if review is tied to a specific ad/service
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID REFERENCES users(id),
    reported_ad_id UUID REFERENCES ads(id),
    reported_user_id UUID REFERENCES users(id),
    reason_code VARCHAR(50) NOT NULL, -- e.g., 'spam', 'fake_price', 'inappropriate'
    details TEXT,
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'dismissed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- DOMAIN 8: PAYMENTS & SUBSCRIPTIONS (المدفوعات والمحافظ)
-- ==========================================
CREATE TABLE user_wallets (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    balance DECIMAL(12,2) DEFAULT 0.00,
    currency VARCHAR(10) DEFAULT 'EGP',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    amount DECIMAL(12,2) NOT NULL,
    transaction_type VARCHAR(20) CHECK (transaction_type IN ('deposit', 'withdrawal', 'ad_boost', 'subscription_fee', 'commission')),
    payment_method VARCHAR(50), -- 'paymob_fawry', 'paymob_wallet', 'card'
    provider_reference VARCHAR(100), -- ID from Paymob
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'successful', 'failed', 'refunded')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE subscription_plans (
    id SERIAL PRIMARY KEY,
    name_ar VARCHAR(50) NOT NULL,
    name_en VARCHAR(50) NOT NULL,
    price_monthly DECIMAL(10,2) NOT NULL,
    features JSONB -- e.g., {"free_boosts": 5, "dashboard_access": true}
);

CREATE TABLE user_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    plan_id INT REFERENCES subscription_plans(id),
    starts_at TIMESTAMPTZ DEFAULT NOW(),
    ends_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- ==========================================
-- DOMAIN 9: SYSTEM & NOTIFICATIONS (النظام والإشعارات)
-- ==========================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title_ar VARCHAR(255) NOT NULL,
    body_ar TEXT NOT NULL,
    action_url TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE push_tokens (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform VARCHAR(20), -- 'ios', 'android', 'web'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, device_token)
);

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL, -- e.g., 'approved_kyc', 'deleted_ad'
    target_id UUID, -- ID of the affected record
    target_table VARCHAR(50),
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================================================================
-- END OF SCHEMA V2.0 (38 Tables Total)
-- Next Step: Supabase Row Level Security (RLS) Policies
-- ========================================================================================
