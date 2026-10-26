-- ⚙️ Wasla - Sprint 9 Migration: Push Notifications & Watchlist Matching
-- This migration sets up the infrastructure for real-time notifications.

-- 1. Ensure notification_preferences column exists in users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS notification_preferences JSONB DEFAULT '{
  "watchlist_matches": true,
  "ad_status_updates": true,
  "special_offers": true
}'::JSONB;

-- 2. Create watchlist_notifications table to prevent duplicate alerts
CREATE TABLE IF NOT EXISTS public.watchlist_notifications (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID            NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    ad_id       UUID            NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
    sent_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, ad_id) -- Critical for Piece 2.3 (Prevent duplicates)
);

-- 3. Ensure device_tokens table is robust (Checking from original schema: it was push_tokens)
-- Let's stick to 'push_tokens' as per original wasla-schema.sql, but ensure it meets requirements.
-- wasla-schema.sql snippet:
-- CREATE TABLE public.push_tokens (
--   user_id      UUID           NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
--   token        TEXT           NOT NULL,
--   platform     push_platform_enum NOT NULL,
--   is_active    BOOLEAN        NOT NULL DEFAULT TRUE,
--   last_seen_at TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
--   PRIMARY KEY (user_id, token)
-- );

-- 4. Create Triggers for Notifications
-- Trigger 1: Watchlist Match (When ad becomes active)
CREATE OR REPLACE FUNCTION public.trigger_notify_watchlist_match()
RETURNS TRIGGER AS $$
BEGIN
    -- Only trigger when status changes to 'active' or a new active ad is created
    IF (TG_OP = 'INSERT' AND NEW.status = 'active') OR 
       (TG_OP = 'UPDATE' AND OLD.status <> 'active' AND NEW.status = 'active') THEN
        
        -- Call Edge Function
        PERFORM net.http_post(
            url := concat(current_setting('app.settings.supabase_url'), '/functions/v1/notify-watchlist-match'),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', concat('Bearer ', current_setting('app.settings.service_role_key'))
            ),
            body := jsonb_build_object('ad_id', NEW.id)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notify_watchlist ON public.ads;
CREATE TRIGGER trg_notify_watchlist
AFTER INSERT OR UPDATE OF status ON public.ads
FOR EACH ROW EXECUTE FUNCTION public.trigger_notify_watchlist_match();

-- Trigger 2: Ad Status Change (Approved/Rejected)
CREATE OR REPLACE FUNCTION public.trigger_notify_ad_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Trigger on status change to 'active' or 'rejected'
    IF (TG_OP = 'UPDATE' AND OLD.status <> NEW.status AND NEW.status IN ('active', 'rejected')) THEN
        
        -- Call Edge Function
        PERFORM net.http_post(
            url := concat(current_setting('app.settings.supabase_url'), '/functions/v1/notify-ad-status'),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', concat('Bearer ', current_setting('app.settings.service_role_key'))
            ),
            body := jsonb_build_object(
                'ad_id', NEW.id,
                'new_status', NEW.status,
                'rejection_reason', NEW.rejection_reason
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notify_ad_status ON public.ads;
CREATE TRIGGER trg_notify_ad_status
AFTER UPDATE OF status ON public.ads
FOR EACH ROW EXECUTE FUNCTION public.trigger_notify_ad_status();

-- Indices for performance
CREATE INDEX IF NOT EXISTS idx_push_tokens_active ON public.push_tokens(user_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_watchlist_user_cat ON public.saved_searches(category_id, is_active) WHERE is_active = TRUE;
