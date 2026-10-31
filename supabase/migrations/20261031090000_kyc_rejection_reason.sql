-- N17: a KYC rejection reason reached only audit_logs, which users cannot
-- read, so the app always showed its generic text. The reason is now stored
-- on the request and readable by its owner.

ALTER TABLE public.user_verifications
  ADD COLUMN rejection_reason text
    CONSTRAINT user_verifications_rejection_reason_length CHECK (char_length(rejection_reason) <= 500);

GRANT SELECT (rejection_reason) ON public.user_verifications TO authenticated;

-- Same as 20261028100000 except that a rejection now stores its reason.
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
      rejection_reason = CASE WHEN p_action = 'rejected' THEN left(NULLIF(btrim(p_reason), ''), 500) END,
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
