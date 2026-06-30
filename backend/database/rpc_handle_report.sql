-- 🛡️ Wasla - Administrative RPC: Handle Report
-- This function allows moderators to resolve or dismiss reports atomically.

CREATE OR REPLACE FUNCTION public.handle_report(
    p_report_id UUID,
    p_moderator_id UUID,
    p_status report_status_enum, -- 'resolved' or 'dismissed'
    p_action_taken TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_reporter_id UUID;
    v_target_id UUID;
    v_target_type target_type_enum;
BEGIN
    -- 1. Fetch report details
    SELECT reporter_id, target_id, target_type INTO v_reporter_id, v_target_id, v_target_type
    FROM public.reports
    WHERE id = p_report_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البلاغ غير موجود');
    END IF;

    -- 2. Update the Report Record
    UPDATE public.reports
    SET 
        status = p_status,
        reviewed_by = p_moderator_id
    WHERE id = p_report_id;

    -- 3. Log in System Audit Log
    INSERT INTO public.audit_logs (
        actor_id,
        action,
        target_type,
        target_id,
        changes
    ) VALUES (
        p_moderator_id,
        'report_' || p_status::TEXT,
        'report',
        p_report_id,
        jsonb_build_object(
            'target_type', v_target_type,
            'target_id', v_target_id,
            'status', p_status,
            'action_taken', p_action_taken
        )
    );

    RETURN jsonb_build_object('success', true);
END;
$$;
