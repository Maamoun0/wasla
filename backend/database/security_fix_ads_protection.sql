-- 🛡️ Wasla - Security Fix: Ads Sensitive Fields Protection
-- This migration prevents users from self-promoting ads or bypassing moderation via direct SQL/API calls.

-- 1. Function to protect sensitive fields
CREATE OR REPLACE FUNCTION public.protect_ad_sensitive_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the current user is a regular user (not admin/moderator)
    -- In Supabase, moderators/admins or service_role will have these functions return true
    -- or will bypass triggers if configured.
    IF NOT (public.is_moderator() OR public.is_admin()) THEN
        
        -- Prevent changing the owner
        IF OLD.user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Ownership cannot be changed directly.';
        END IF;

        -- Prevent self-promoting (bypassing payment)
        IF OLD.is_featured IS DISTINCT FROM NEW.is_featured THEN
            RAISE EXCEPTION 'Featured status can only be modified via payment gateway.';
        END IF;

        IF OLD.is_urgent IS DISTINCT FROM NEW.is_urgent THEN
            RAISE EXCEPTION 'Urgent status can only be modified via payment gateway.';
        END IF;

        -- Prevent bypassing moderation
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            -- Users can only change status to 'paused', 'deleted', 'sold' 
            -- but NOT to 'active' or 'pending' if it was rejected
            IF NEW.status NOT IN ('paused', 'deleted', 'sold') THEN
                RAISE EXCEPTION 'Status change restricted. Use official moderation flow.';
            END IF;
        END IF;

        -- Prevent touching AI risk levels or notes (if they exist)
        -- Using a dynamic check to avoid errors if columns aren't there yet
        BEGIN
            IF OLD.ai_risk_level IS DISTINCT FROM NEW.ai_risk_level THEN
                RAISE EXCEPTION 'AI Risk Level is system-managed.';
            END IF;
        EXCEPTION WHEN undefined_column THEN
            -- Column doesn't exist yet, ignore
        END;

        IF OLD.rejection_reason IS DISTINCT FROM NEW.rejection_reason THEN
            RAISE EXCEPTION 'Rejection reason can only be modified by moderators.';
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Apply Trigger
DROP TRIGGER IF EXISTS trg_protect_ad_fields ON public.ads;
CREATE TRIGGER trg_protect_ad_fields
BEFORE UPDATE ON public.ads
FOR EACH ROW EXECUTE FUNCTION public.protect_ad_sensitive_fields();

-- 3. Audit Log Entry for this fix
-- Since I don't have a direct SQL runner, I'm providing this as a migration file.
