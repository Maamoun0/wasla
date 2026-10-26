-- ================================================================
-- Notifications via an outbox instead of pg_net calls inside triggers.
-- The old ads triggers called net.http_post with app.settings.* values
-- that were never configured, so every approval/rejection failed.
--   * Triggers on ads only write rows: an in-app notification and, when
--     the user allows push, a notifications_outbox row. Any failure there
--     is caught and logged as a WARNING; the ad change always commits.
--   * dispatch-notifications (Edge Function) claims batches with
--     claim_notifications(), sends through FCM HTTP v1 and reports back
--     with complete_notification() (retry with backoff, dead tokens off).
--   * pg_cron pokes the dispatcher every minute when work is waiting.
--     It reads the project URL and service key from Vault; until those
--     secrets exist the tick is a no-op.
-- ================================================================

-- ── 1. Remove the network-calling triggers ───────────────────────
DROP TRIGGER IF EXISTS trg_notify_ad_status ON public.ads;
DROP TRIGGER IF EXISTS trg_notify_watchlist ON public.ads;
DROP FUNCTION IF EXISTS public.trigger_notify_ad_status();
DROP FUNCTION IF EXISTS public.trigger_notify_watchlist_match();

-- ── 2. Outbox ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications_outbox (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  notification_id UUID        REFERENCES public.notifications(id) ON DELETE SET NULL,
  title           TEXT        NOT NULL,
  body            TEXT        NOT NULL,
  data            JSONB       NOT NULL DEFAULT '{}'::jsonb,
  status          TEXT        NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending', 'processing', 'sent', 'failed', 'skipped')),
  attempts        INTEGER     NOT NULL DEFAULT 0,
  last_error      TEXT,
  available_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  locked_at       TIMESTAMPTZ,
  sent_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_outbox_ready ON public.notifications_outbox (available_at)
  WHERE status IN ('pending', 'processing');
COMMENT ON TABLE public.notifications_outbox IS 'إشعارات Push بانتظار الإرسال عبر dispatch-notifications';

ALTER TABLE public.notifications_outbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notifications_outbox FROM anon, authenticated;
GRANT ALL ON public.notifications_outbox TO service_role;

-- ── 3. Enqueue helpers ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.enqueue_notification(
  p_user_id uuid,
  p_type    public.notification_type_enum,
  p_title   text,
  p_body    text,
  p_data    jsonb,
  p_push    boolean
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_notification_id uuid;
BEGIN
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_user_id, p_type, p_title, p_body, p_data)
  RETURNING id INTO v_notification_id;

  IF p_push THEN
    INSERT INTO public.notifications_outbox (user_id, notification_id, title, body, data)
    VALUES (p_user_id, v_notification_id, p_title, p_body, p_data);
  END IF;
END;
$$;

-- Saved searches match on category (the ad's subcategory or its parent),
-- optional city, optional keyword in title/description, and optional
-- min_price / max_price in filters. Each watcher hears about an ad once.
CREATE OR REPLACE FUNCTION public.enqueue_watchlist_matches(p_ad public.ads)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_parent smallint;
  r record;
BEGIN
  SELECT parent_id INTO v_parent FROM public.categories WHERE id = p_ad.category_id;

  FOR r IN
    SELECT DISTINCT ON (s.user_id) s.id, s.user_id,
           coalesce((u.notification_preferences ->> 'watchlist_matches')::boolean, true) AS wants_push
    FROM public.saved_searches s
    JOIN public.users u ON u.id = s.user_id AND u.deleted_at IS NULL
    WHERE s.is_active
      AND s.user_id <> p_ad.user_id
      AND (s.category_id IS NULL OR s.category_id IN (p_ad.category_id, v_parent))
      AND (s.city_id IS NULL OR s.city_id = p_ad.city_id)
      AND (s.keywords IS NULL OR btrim(s.keywords) = ''
           OR (p_ad.title || ' ' || p_ad.description) ILIKE '%' || btrim(s.keywords) || '%')
      AND (NOT s.filters ? 'min_price' OR p_ad.price >= (s.filters ->> 'min_price')::numeric)
      AND (NOT s.filters ? 'max_price' OR p_ad.price <= (s.filters ->> 'max_price')::numeric)
    ORDER BY s.user_id, s.created_at
  LOOP
    INSERT INTO public.watchlist_notifications (user_id, ad_id)
    VALUES (r.user_id, p_ad.id)
    ON CONFLICT (user_id, ad_id) DO NOTHING;
    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    UPDATE public.saved_searches SET last_notified_at = now() WHERE id = r.id;
    PERFORM public.enqueue_notification(
      r.user_id, 'saved_search_match', 'إعلان جديد يهمك! 🔔',
      format('لقينا إعلان "%s" يطابق بحثك المحفوظ.', p_ad.title),
      jsonb_build_object('type', 'watchlist_match', 'ad_id', p_ad.id),
      r.wants_push);
  END LOOP;
END;
$$;

-- ── 4. Ads trigger ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ads_enqueue_notifications()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_wants_push boolean;
BEGIN
  BEGIN
    IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status
       AND NEW.status IN ('active', 'rejected') AND OLD.status IN ('pending', 'rejected') THEN
      SELECT coalesce((notification_preferences ->> 'ad_status_updates')::boolean, true)
      INTO v_wants_push FROM public.users WHERE id = NEW.user_id;

      IF NEW.status = 'active' THEN
        PERFORM public.enqueue_notification(
          NEW.user_id, 'ad_approved', 'تم قبول إعلانك 🎉',
          format('✅ إعلانك "%s" اتنشر وبقى مرئي للجميع!', NEW.title),
          jsonb_build_object('type', 'ad_status_change', 'ad_id', NEW.id, 'status', 'active'),
          coalesce(v_wants_push, true));
      ELSE
        PERFORM public.enqueue_notification(
          NEW.user_id, 'ad_rejected', 'تحديث بخصوص إعلانك',
          format('❌ إعلانك "%s" اترفض. السبب: %s', NEW.title, coalesce(NEW.rejection_reason, 'مخالف لشروط النشر')),
          jsonb_build_object('type', 'ad_status_change', 'ad_id', NEW.id, 'status', 'rejected'),
          coalesce(v_wants_push, true));
      END IF;
    END IF;

    IF NEW.status = 'active' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'active') THEN
      PERFORM public.enqueue_watchlist_matches(NEW);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- Notifications must never block the ad change.
    RAISE WARNING 'ads_enqueue_notifications failed for ad %: %', NEW.id, SQLERRM;
  END;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_ads_enqueue_notifications ON public.ads;
CREATE TRIGGER trg_ads_enqueue_notifications
  AFTER INSERT OR UPDATE OF status ON public.ads
  FOR EACH ROW EXECUTE FUNCTION public.ads_enqueue_notifications();

-- ── 5. Dispatcher RPCs (service_role only) ───────────────────────
-- Claims ready rows, plus rows left 'processing' by a dispatcher that died.
CREATE OR REPLACE FUNCTION public.claim_notifications(p_limit integer DEFAULT 50)
RETURNS TABLE (id uuid, user_id uuid, title text, body text, data jsonb, attempts integer, tokens text[])
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN QUERY
  WITH picked AS (
    SELECT o.id FROM public.notifications_outbox o
    WHERE (o.status = 'pending' AND o.available_at <= now())
       OR (o.status = 'processing' AND o.locked_at < now() - interval '10 minutes')
    ORDER BY o.created_at
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  ), claimed AS (
    UPDATE public.notifications_outbox o
    SET status = 'processing', locked_at = now(), attempts = o.attempts + 1
    FROM picked WHERE o.id = picked.id
    RETURNING o.id, o.user_id, o.title, o.body, o.data, o.attempts
  )
  SELECT c.id, c.user_id, c.title, c.body, c.data, c.attempts,
         coalesce((SELECT array_agg(t.token ORDER BY t.created_at)
                   FROM public.push_tokens t WHERE t.user_id = c.user_id AND t.is_active), ARRAY[]::text[])
  FROM claimed c;
END;
$$;

-- p_status: sent | skipped (final) | failed (retried with backoff up to 5 attempts).
CREATE OR REPLACE FUNCTION public.complete_notification(
  p_id             uuid,
  p_status         text,
  p_error          text DEFAULT NULL,
  p_invalid_tokens text[] DEFAULT '{}'
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_attempts integer;
  v_user     uuid;
BEGIN
  IF p_status NOT IN ('sent', 'skipped', 'failed') THEN
    RAISE EXCEPTION 'invalid status %', p_status USING ERRCODE = '22023';
  END IF;

  SELECT attempts, user_id INTO v_attempts, v_user FROM public.notifications_outbox WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF coalesce(array_length(p_invalid_tokens, 1), 0) > 0 THEN
    UPDATE public.push_tokens SET is_active = false, updated_at = now()
    WHERE user_id = v_user AND token = ANY (p_invalid_tokens);
  END IF;

  IF p_status = 'failed' AND v_attempts < 5 THEN
    UPDATE public.notifications_outbox
    SET status = 'pending', locked_at = NULL, last_error = p_error,
        available_at = now() + make_interval(mins => power(2, v_attempts)::int)
    WHERE id = p_id;
  ELSE
    UPDATE public.notifications_outbox
    SET status = p_status, locked_at = NULL, last_error = p_error,
        sent_at = CASE WHEN p_status = 'sent' THEN now() END
    WHERE id = p_id;
  END IF;
END;
$$;

DO $$
DECLARE
  f regprocedure;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('enqueue_notification', 'enqueue_watchlist_matches', 'ads_enqueue_notifications',
                        'claim_notifications', 'complete_notification')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END;
$$;

-- In-app notifications: owners read and mark their own as read.
DROP POLICY IF EXISTS "notifs_own" ON public.notifications;
DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
DROP POLICY IF EXISTS notifications_update_own ON public.notifications;
CREATE POLICY notifications_select_own ON public.notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY notifications_update_own ON public.notifications FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
REVOKE INSERT, DELETE, TRUNCATE ON public.notifications FROM anon, authenticated;
REVOKE UPDATE ON public.notifications FROM anon, authenticated;
GRANT UPDATE (is_read, read_at) ON public.notifications TO authenticated;

-- ── 6. Dispatcher tick ───────────────────────────────────────────
-- Vault secrets (per environment, never in migrations):
--   select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
--   select vault.create_secret('<service_role key>', 'service_role_key');
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.dispatch_notifications_tick()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_url text;
  v_key text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.notifications_outbox
    WHERE (status = 'pending' AND available_at <= now())
       OR (status = 'processing' AND locked_at < now() - interval '10 minutes')
  ) THEN
    RETURN;
  END IF;

  SELECT decrypted_secret INTO v_url FROM vault.decrypted_secrets WHERE name = 'project_url';
  SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'service_role_key';
  IF v_url IS NULL OR v_key IS NULL THEN
    RAISE NOTICE 'dispatch_notifications_tick: vault secrets project_url / service_role_key are not set';
    RETURN;
  END IF;

  PERFORM net.http_post(
    url := v_url || '/functions/v1/dispatch-notifications',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000);
END;
$$;

REVOKE ALL ON FUNCTION public.dispatch_notifications_tick() FROM PUBLIC, anon, authenticated;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'dispatch-notifications';
SELECT cron.schedule('dispatch-notifications', '* * * * *', 'SELECT public.dispatch_notifications_tick();');
