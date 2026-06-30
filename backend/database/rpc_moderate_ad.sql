-- 🛡️ Wasla - Administrative RPC: Moderate Ad
-- This function ensures that ad moderation is an atomic transaction.
-- It updates the ad status, logs the action in the moderation history, 
-- and adds a record to the system-wide audit log.

CREATE OR REPLACE FUNCTION public.moderate_ad(
    p_ad_id UUID,
    p_moderator_id UUID,
    p_action mod_action_enum,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with elevated privileges to bypass RLS
AS $$
DECLARE
    v_old_status ad_status_enum;
    v_new_status ad_status_enum;
    v_ad_title TEXT;
BEGIN
    -- 1. Fetch current ad details
    SELECT status, title INTO v_old_status, v_ad_title
    FROM public.ads
    WHERE id = p_ad_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'الإعلان غير موجود');
    END IF;

    -- 2. Map moderation action to ad status
    IF p_action = 'approved' THEN
        v_new_status := 'active';
    ELSIF p_action = 'rejected' THEN
        v_new_status := 'rejected';
    ELSE
        -- For other actions like 'flagged', we might not change the status immediately
        v_new_status := v_old_status;
    END IF;

    -- 3. Update the Ad
    UPDATE public.ads
    SET 
        status = v_new_status,
        rejection_reason = CASE WHEN p_action = 'rejected' THEN p_reason ELSE NULL END,
        updated_at = NOW()
    WHERE id = p_ad_id;

    -- 4. Log in Ad Moderation Log
    INSERT INTO public.ad_moderation_log (
        ad_id,
        moderator_id,
        action,
        reason,
        previous_status,
        new_status
    ) VALUES (
        p_ad_id,
        p_moderator_id,
        p_action,
        p_reason,
        v_old_status::VARCHAR,
        v_new_status::VARCHAR
    );

    -- 5. Log in System Audit Log
    INSERT INTO public.audit_logs (
        actor_id,
        action,
        target_type,
        target_id,
        changes
    ) VALUES (
        p_moderator_id,
        'moderate_ad_' || p_action::TEXT,
        'ad',
        p_ad_id,
        jsonb_build_object(
            'title', v_ad_title,
            'old_status', v_old_status,
            'new_status', v_new_status,
            'reason', p_reason
        )
    );

    RETURN jsonb_build_object('success', true);
END;
$$;
