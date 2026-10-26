-- ⚙️ Wasla - Sprint 8 Migration: User Activity Log & Permissions
-- This migration adds a centralized logging system for user actions.

-- 1. Create Action Type ENUM
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_activity_type_enum') THEN
        CREATE TYPE user_activity_type_enum AS ENUM (
            'login_success', 
            'login_failed', 
            'otp_requested', 
            'payment_attempted', 
            'payment_completed', 
            'ad_published', 
            'account_deletion_requested'
        );
    END IF;
END $$;

-- 2. Create User Activity Log Table
CREATE TABLE IF NOT EXISTS public.user_activity_log (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID            REFERENCES public.users(id) ON DELETE CASCADE,
    action_type user_activity_type_enum NOT NULL,
    metadata    JSONB           DEFAULT '{}'::JSONB,
    ip_address  INET,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- 3. Security: RLS for User Activity Log
-- Only Service Role (Edge Functions) and Admins can write/read.
-- Users should NOT be able to see or modify their activity logs for security/forensics.
ALTER TABLE public.user_activity_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_all_access_activity" 
    ON public.user_activity_log 
    FOR ALL 
    USING (public.is_admin() OR public.is_moderator());

-- 4. Add 'is_hidden' to ads table (Piece 1.2)
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE;

-- 5. Update user_status_enum to include 'suspended' and 'banned' if not exists
-- (Wait, checking current enum from wasla-schema.sql)
-- wasla-schema.sql says: ('active','suspended','deleted','pending_verification')
-- Let's add 'banned' to it.
ALTER TYPE user_status_enum ADD VALUE IF NOT EXISTS 'banned';

-- 6. Indices for performance
CREATE INDEX IF NOT EXISTS idx_user_activity_user_id ON public.user_activity_log(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ads_is_hidden ON public.ads(is_hidden) WHERE is_hidden = TRUE;
