-- ================================================================
-- KYC-01.
--   * Approving a verification now sets users.is_id_verified (the ✓ badge
--     the app shows on profiles and ads); before, it only overrode
--     trust_score with GREATEST(trust_score, 80), outside the trust formula.
--     The formula's trigger adds the 30 verification points.
--   * Only pending requests can be decided; the decision time is recorded.
--   * Identity documents are deleted from Storage 7 days after approval and
--     30 days after rejection (appeal window) by purge-kyc-documents (daily
--     cron, Storage API). The verification row — the decision record — stays,
--     with its document paths cleared.
-- ================================================================

ALTER TABLE public.user_verifications ADD COLUMN IF NOT EXISTS decided_at TIMESTAMPTZ;
ALTER TABLE public.user_verifications ADD COLUMN IF NOT EXISTS documents_deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_user_verifications_retention ON public.user_verifications (decided_at)
  WHERE documents_deleted_at IS NULL AND status IN ('approved', 'rejected');

CREATE OR REPLACE FUNCTION public.moderate_kyc(
  p_verification_id uuid,
  p_moderator_id uuid,
  p_action public.verification_status_enum,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id   uuid;
  v_status    public.verification_status_enum;
  v_user_name text;
BEGIN
  IF p_action NOT IN ('approved', 'rejected') THEN
    RETURN jsonb_build_object('success', false, 'error', 'إجراء غير صالح');
  END IF;

  SELECT user_id, status INTO v_user_id, v_status
  FROM public.user_verifications WHERE id = p_verification_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'طلب التوثيق غير موجود');
  END IF;
  IF v_status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'تم البت في هذا الطلب مسبقاً');
  END IF;

  SELECT full_name INTO v_user_name FROM public.users WHERE id = v_user_id;

  UPDATE public.user_verifications
  SET status = p_action,
      decided_at = now(),
      verified_at = CASE WHEN p_action = 'approved' THEN now() END
  WHERE id = p_verification_id;

  IF p_action = 'approved' THEN
    -- trg_trust_score_users recalculates trust_score from is_id_verified.
    UPDATE public.users
    SET is_id_verified = true,
        status = CASE WHEN status = 'pending_verification' THEN 'active' ELSE status END,
        updated_at = now()
    WHERE id = v_user_id;
  END IF;

  INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, changes)
  VALUES (p_moderator_id, 'moderate_kyc_' || p_action::text, 'user_verification', p_verification_id,
          jsonb_build_object('user_name', v_user_name, 'user_id', v_user_id, 'status', p_action, 'reason', p_reason));

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.moderate_kyc(uuid, uuid, public.verification_status_enum, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_kyc(uuid, uuid, public.verification_status_enum, text) TO service_role;

CREATE OR REPLACE FUNCTION public.list_due_kyc_documents(p_limit integer DEFAULT 50)
RETURNS TABLE (verification_id uuid, paths text[])
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT v.id, array_remove(ARRAY[v.document_url, v.document_back_url, v.selfie_url], NULL)
  FROM public.user_verifications v
  WHERE v.documents_deleted_at IS NULL
    AND ((v.status = 'approved' AND v.decided_at <= now() - interval '7 days')
      OR (v.status = 'rejected' AND v.decided_at <= now() - interval '30 days'))
    AND coalesce(v.document_url, v.document_back_url, v.selfie_url) IS NOT NULL
  ORDER BY v.decided_at
  LIMIT p_limit;
$$;

CREATE OR REPLACE FUNCTION public.mark_kyc_documents_deleted(p_verification_id uuid)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  UPDATE public.user_verifications
  SET document_url = NULL, document_back_url = NULL, selfie_url = NULL, documents_deleted_at = now()
  WHERE id = p_verification_id;
$$;

REVOKE ALL ON FUNCTION public.list_due_kyc_documents(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.mark_kyc_documents_deleted(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_due_kyc_documents(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_kyc_documents_deleted(uuid) TO service_role;

-- Daily purge tick; same Vault secrets as the other Edge Function ticks.
CREATE OR REPLACE FUNCTION public.purge_kyc_documents_tick()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_url text;
  v_key text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.list_due_kyc_documents(1)) THEN
    RETURN;
  END IF;

  SELECT decrypted_secret INTO v_url FROM vault.decrypted_secrets WHERE name = 'project_url';
  SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'service_role_key';
  IF v_url IS NULL OR v_key IS NULL THEN
    RAISE NOTICE 'purge_kyc_documents_tick: vault secrets project_url / service_role_key are not set';
    RETURN;
  END IF;

  PERFORM net.http_post(
    url := v_url || '/functions/v1/purge-kyc-documents',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000);
END;
$$;

REVOKE ALL ON FUNCTION public.purge_kyc_documents_tick() FROM PUBLIC, anon, authenticated;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'purge-kyc-documents';
SELECT cron.schedule('purge-kyc-documents', '45 3 * * *', 'SELECT public.purge_kyc_documents_tick();');
