-- ================================================================
-- SEC (أ): lock the client API roles (anon, authenticated) out of
-- privileged state.
--   1. RLS on every public table; lookup tables are read-only.
--   2. No client EXECUTE on moderation RPCs / create_ad_transaction.
--   3. SECURITY DEFINER functions pin search_path.
--   4. No client writes to role / verification / trust / status,
--      credits, subscriptions, transactions, boosts, KYC rows.
--   5. phone/email readable only by the owner (get_my_profile) or by
--      a signed-in buyer of an active ad (get_ad_contact, which logs
--      the contact).
--   6. Mock KYC auto-approval trigger removed.
-- service_role (Edge Functions, admin panel) is unaffected.
-- Written to be idempotent and tolerant of objects that may not exist
-- on every environment.
-- ================================================================

-- ── 1. RLS everywhere; lookup tables are public read-only ────────
DO $$
DECLARE
  t text;
BEGIN
  FOR t IN
    SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relname <> 'spatial_ref_sys'
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype = 'e')
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;

  FOREACH t IN ARRAY ARRAY['governorates', 'cities', 'districts', 'categories',
                           'category_fields', 'subscription_plans', 'app_configs']
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_public_read', t);
      EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO anon, authenticated USING (true)',
                     t || '_public_read', t);
    END IF;
  END LOOP;
END;
$$;

-- ── 2. Client write privileges removed on server-owned tables ────
-- Writes to these happen only through service_role (Edge Functions /
-- admin panel) or SECURITY DEFINER functions.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'governorates', 'cities', 'districts', 'categories', 'category_fields',
    'subscription_plans', 'app_configs', 'roles', 'permissions', 'role_permissions', 'user_roles',
    'user_credits', 'credit_transactions', 'user_subscriptions', 'transactions', 'ad_boosts',
    'user_verifications', 'contact_logs', 'audit_logs', 'audit_log', 'ad_moderation_log',
    'watchlist_notifications', 'user_activity_log', 'otp_requests']
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.%I FROM anon, authenticated', t);
    END IF;
  END LOOP;
END;
$$;

-- ── 3. Owner-read-only policies for money and KYC tables ─────────
-- Existing policies on these tables are replaced wholesale: earlier
-- scripts left overlapping FOR ALL / INSERT policies with different
-- names on different environments.
DO $$
DECLARE
  t text;
  p record;
BEGIN
  FOREACH t IN ARRAY ARRAY['user_credits', 'credit_transactions', 'user_subscriptions',
                           'transactions', 'user_verifications', 'ad_boosts', 'watchlist_notifications']
  LOOP
    IF to_regclass('public.' || t) IS NULL THEN
      CONTINUE;
    END IF;
    FOR p IN SELECT polname FROM pg_policy WHERE polrelid = ('public.' || t)::regclass LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', p.polname, t);
    END LOOP;
    IF t = 'ad_boosts' THEN
      -- Boost badges are shown on public ads.
      EXECUTE 'CREATE POLICY ad_boosts_public_read ON public.ad_boosts FOR SELECT TO anon, authenticated USING (true)';
    ELSE
      EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (user_id = auth.uid())',
                     t || '_select_own', t);
    END IF;
  END LOOP;
END;
$$;

DROP POLICY IF EXISTS "contact_insert" ON public.contact_logs;

-- ── 4. users: column-level privileges ────────────────────────────
-- Clients may read only public profile columns and update only
-- self-service columns. Role, verification flags, trust score,
-- status, phone and email are server-managed.
REVOKE ALL ON public.users FROM anon, authenticated;

DO $$
DECLARE
  read_cols   text;
  update_cols text;
BEGIN
  SELECT string_agg(quote_ident(column_name), ', ') INTO read_cols
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'users'
    AND column_name IN ('id', 'full_name', 'avatar_url', 'bio', 'is_id_verified',
                        'trust_score', 'city_id', 'created_at', 'deleted_at');

  SELECT string_agg(quote_ident(column_name), ', ') INTO update_cols
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'users'
    AND column_name IN ('full_name', 'avatar_url', 'bio', 'city_id',
                        'notification_preferences', 'last_active_at', 'updated_at');

  EXECUTE format('GRANT SELECT (%s) ON public.users TO anon, authenticated', read_cols);
  EXECUTE format('GRANT UPDATE (%s) ON public.users TO authenticated', update_cols);
END;
$$;

-- Profiles are created by the handle_new_user trigger (SECURITY DEFINER),
-- and deletion goes through the account-deletion flow.
DROP POLICY IF EXISTS "users_insert_trigger" ON public.users;
DROP POLICY IF EXISTS "users_delete_own" ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;
CREATE POLICY "users_update_own" ON public.users FOR UPDATE TO authenticated
  USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- ── 5. Owner / buyer access to private profile fields ────────────
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS SETOF public.users
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT * FROM public.users WHERE id = auth.uid();
$$;

-- Returns the seller's phone for an active ad and records the contact
-- (contact_logs feeds analytics and review eligibility).
CREATE OR REPLACE FUNCTION public.get_ad_contact(p_ad_id uuid, p_contact_type text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_owner  uuid;
  v_phone  text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_contact_type NOT IN ('phone', 'whatsapp') THEN
    RAISE EXCEPTION 'unsupported contact type: %', p_contact_type USING ERRCODE = '22023';
  END IF;

  SELECT a.user_id, u.phone INTO v_owner, v_phone
  FROM public.ads a JOIN public.users u ON u.id = a.user_id
  WHERE a.id = p_ad_id AND a.status = 'active' AND a.deleted_at IS NULL AND u.deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ad not available' USING ERRCODE = 'P0002';
  END IF;

  IF v_owner <> v_caller THEN
    INSERT INTO public.contact_logs (ad_id, user_id, contact_type)
    VALUES (p_ad_id, v_caller, p_contact_type::public.contact_type_enum);
  END IF;

  RETURN jsonb_build_object('phone', v_phone);
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_profile() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_ad_contact(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_ad_contact(uuid, text) TO authenticated, service_role;

-- ── 6. Privileged RPCs: service_role only ────────────────────────
-- These take the acting moderator / owner id as a parameter, so they
-- must never be reachable with a client token.
DO $$
DECLARE
  f regprocedure;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('moderate_ad', 'moderate_kyc', 'handle_report', 'create_ad_transaction')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END;
$$;

-- ── 7. Trust-score triggers write to other users' rows ───────────
-- They ran as the reviewer, so RLS silently dropped the update (and the
-- column privileges above would now reject it). Run them as owner.
DO $$
DECLARE
  f regprocedure;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname IN ('update_trust_score', 'refresh_user_trust_score')
  LOOP
    EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER', f);
  END LOOP;
END;
$$;

-- ── 8. Pin search_path on every SECURITY DEFINER function ────────
DO $$
DECLARE
  f regprocedure;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prosecdef
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
      AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) cfg WHERE cfg LIKE 'search_path=%')
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp', f);
  END LOOP;
END;
$$;

-- ── 9. Remove the development KYC auto-approval mock ─────────────
DROP TRIGGER IF EXISTS trg_mock_face_verification ON public.user_verifications;
DROP FUNCTION IF EXISTS public.mock_face_verification_processor();
