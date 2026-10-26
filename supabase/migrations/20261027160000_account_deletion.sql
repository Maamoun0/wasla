-- ================================================================
-- Account deletion (security plan §6, right to be forgotten).
-- The app wrote to account_deletion_requests, which did not exist, and
-- deleting a user who ever acted as staff failed: audit_logs.actor_id and
-- ad_moderation_log.moderator_id were NOT NULL with ON DELETE SET NULL.
--   * request_account_deletion(): immediately hides the profile and ads,
--     stops push / saved searches, blocks sign-in, ends sessions, and
--     schedules the purge 30 days later.
--   * purge-deleted-accounts (Edge Function, daily cron) lists due
--     requests, deletes the user's files through the Storage API, deletes
--     the auth user through the Auth API (cascading to public data), then
--     calls complete_account_deletion(). Audit and moderation history is
--     kept with the actor anonymised.
-- ================================================================

ALTER TABLE public.audit_logs ALTER COLUMN actor_id DROP NOT NULL;
ALTER TABLE public.ad_moderation_log ALTER COLUMN moderator_id DROP NOT NULL;

CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        REFERENCES public.users(id) ON DELETE SET NULL,
  reason        TEXT,
  status        TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
  requested_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  scheduled_for TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '30 days',
  completed_at  TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_account_deletion_pending
  ON public.account_deletion_requests (user_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_account_deletion_due
  ON public.account_deletion_requests (scheduled_for) WHERE status = 'pending';

ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_deletion_requests FROM anon, authenticated;
GRANT SELECT ON public.account_deletion_requests TO authenticated;
GRANT ALL ON public.account_deletion_requests TO service_role;
DROP POLICY IF EXISTS account_deletion_select_own ON public.account_deletion_requests;
CREATE POLICY account_deletion_select_own ON public.account_deletion_requests
  FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.request_account_deletion(p_reason text DEFAULT NULL)
RETURNS SETOF public.account_deletion_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_req public.account_deletion_requests;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_req FROM public.account_deletion_requests WHERE user_id = v_uid AND status = 'pending';
  IF FOUND THEN
    RETURN NEXT v_req;
    RETURN;
  END IF;

  INSERT INTO public.account_deletion_requests (user_id, reason)
  VALUES (v_uid, nullif(btrim(p_reason), ''))
  RETURNING * INTO v_req;

  UPDATE public.users SET status = 'deleted', deleted_at = now(), updated_at = now() WHERE id = v_uid;
  UPDATE public.ads SET status = 'deleted', deleted_at = now()
  WHERE user_id = v_uid AND deleted_at IS NULL;
  DELETE FROM public.push_tokens WHERE user_id = v_uid;
  UPDATE public.saved_searches SET is_active = false WHERE user_id = v_uid;

  -- Block sign-in and end existing sessions. A finite date: GoTrue cannot
  -- load users whose banned_until is 'infinity', which would break the purge.
  UPDATE auth.users SET banned_until = now() + interval '100 years' WHERE id = v_uid;
  DELETE FROM auth.sessions WHERE user_id = v_uid;

  RETURN NEXT v_req;
END;
$$;

REVOKE ALL ON FUNCTION public.request_account_deletion(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_account_deletion(text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.list_due_account_deletions(p_limit integer DEFAULT 50)
RETURNS TABLE (request_id uuid, user_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT r.id, r.user_id
  FROM public.account_deletion_requests r
  WHERE r.status = 'pending' AND r.scheduled_for <= now() AND r.user_id IS NOT NULL
  ORDER BY r.scheduled_for
  LIMIT p_limit;
$$;

CREATE OR REPLACE FUNCTION public.complete_account_deletion(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.account_deletion_requests
  SET status = 'completed', completed_at = now(), user_id = NULL
  WHERE id = p_request_id AND status = 'pending' AND scheduled_for <= now();
END;
$$;

REVOKE ALL ON FUNCTION public.list_due_account_deletions(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_account_deletion(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_due_account_deletions(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_account_deletion(uuid) TO service_role;

-- Daily purge tick. Uses the same Vault secrets as the notification dispatcher.
CREATE OR REPLACE FUNCTION public.purge_accounts_tick()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_url text;
  v_key text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.list_due_account_deletions(1)) THEN
    RETURN;
  END IF;

  SELECT decrypted_secret INTO v_url FROM vault.decrypted_secrets WHERE name = 'project_url';
  SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'service_role_key';
  IF v_url IS NULL OR v_key IS NULL THEN
    RAISE NOTICE 'purge_accounts_tick: vault secrets project_url / service_role_key are not set';
    RETURN;
  END IF;

  PERFORM net.http_post(
    url := v_url || '/functions/v1/purge-deleted-accounts',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000);
END;
$$;

REVOKE ALL ON FUNCTION public.purge_accounts_tick() FROM PUBLIC, anon, authenticated;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'purge-deleted-accounts';
SELECT cron.schedule('purge-deleted-accounts', '15 3 * * *', 'SELECT public.purge_accounts_tick();');
