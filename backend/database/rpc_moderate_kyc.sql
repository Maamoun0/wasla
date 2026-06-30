-- 🛡️ Wasla - Administrative RPC: Moderate KYC Request
-- This function ensures that KYC verification is an atomic transaction.
-- It updates the verification status, user verification status, and logs the action.

CREATE OR REPLACE FUNCTION public.moderate_kyc(
    p_verification_id UUID,
    p_moderator_id UUID,
    p_action verification_status_enum, -- 'approved' or 'rejected'
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_user_name TEXT;
BEGIN
    -- 1. Fetch verification details
    SELECT user_id INTO v_user_id
    FROM public.user_verifications
    WHERE id = p_verification_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'طلب التوثيق غير موجود');
    END IF;

    SELECT full_name INTO v_user_name FROM public.users WHERE id = v_user_id;

    -- 2. Update the Verification Record
    UPDATE public.user_verifications
    SET 
        status = p_action,
        verified_at = CASE WHEN p_action = 'approved' THEN NOW() ELSE NULL END
    WHERE id = p_verification_id;

    -- 3. Update the User Status
    IF p_action = 'approved' THEN
        UPDATE public.users
        SET 
            status = 'active', -- Ensure user is active if they were pending_verification
            trust_score = GREATEST(trust_score, 80), -- Boost trust score on ID verification
            updated_at = NOW()
        WHERE id = v_user_id;
    END IF;

    -- 4. Log in System Audit Log
    INSERT INTO public.audit_logs (
        actor_id,
        action,
        target_type,
        target_id,
        changes
    ) VALUES (
        p_moderator_id,
        'moderate_kyc_' || p_action::TEXT,
        'user_verification',
        p_verification_id,
        jsonb_build_object(
            'user_name', v_user_name,
            'user_id', v_user_id,
            'status', p_action,
            'reason', p_reason
        )
    );

    RETURN jsonb_build_object('success', true);
END;
$$;
