-- 🟡5 (FR-3.3): an ad is active for ad_expiry_days (app_configs, 30) from
-- its approval, not from its creation; owners can renew it.
--  * expires_at defaulted to created_at + 30 days and approval kept it: an ad
--    that waited 3 days for review got 27 days, and one that waited over 30
--    days expired within the hour after approval.
--  * Owners could also write expires_at directly (an ad that never expires).
--    Publication dates are now system-managed.
--  * renew_ad: the owner renews an expired ad, or an active one in its last
--    3 days, for another ad_expiry_days. A renewal does not move
--    published_at (no fake "new" ad) and does not notify again.

CREATE OR REPLACE FUNCTION public.ad_lifetime()
RETURNS interval
LANGUAGE sql STABLE SET search_path = public, pg_temp
AS $$
  SELECT make_interval(days => coalesce(
    (SELECT least(greatest((value #>> '{}')::integer, 1), 365) FROM public.app_configs
     WHERE key = 'ad_expiry_days' AND (value #>> '{}') ~ '^[0-9]+$'),
    30));
$$;

CREATE OR REPLACE FUNCTION public.set_ad_published_at()
RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp
AS $$
BEGIN
  -- First publication (approval, or approval after a rejection): the clock starts now.
  IF NEW.status = 'active' AND OLD.status IN ('pending', 'rejected') THEN
    NEW.published_at := now();
    NEW.expires_at := now() + public.ad_lifetime();
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.protect_ad_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN NEW;
  END IF;

  IF OLD.user_id IS DISTINCT FROM NEW.user_id THEN
    RAISE EXCEPTION 'Ownership cannot be changed directly.' USING ERRCODE = '42501';
  END IF;
  IF OLD.is_featured IS DISTINCT FROM NEW.is_featured
     OR OLD.is_urgent IS DISTINCT FROM NEW.is_urgent
     OR OLD.refreshed_at IS DISTINCT FROM NEW.refreshed_at THEN
    RAISE EXCEPTION 'Promotion fields can only be changed by the payment flow.' USING ERRCODE = '42501';
  END IF;
  IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status NOT IN ('paused', 'deleted', 'sold') THEN
    RAISE EXCEPTION 'Status change restricted. Use official moderation flow.' USING ERRCODE = '42501';
  END IF;
  IF OLD.expires_at IS DISTINCT FROM NEW.expires_at
     OR OLD.published_at IS DISTINCT FROM NEW.published_at THEN
    RAISE EXCEPTION 'Publication dates are set by approval and renew_ad.' USING ERRCODE = '42501';
  END IF;
  IF OLD.rejection_reason IS DISTINCT FROM NEW.rejection_reason THEN
    RAISE EXCEPTION 'Rejection reason can only be modified by moderators.' USING ERRCODE = '42501';
  END IF;
  IF OLD.ai_layer_used IS DISTINCT FROM NEW.ai_layer_used
     OR OLD.ai_risk_level IS DISTINCT FROM NEW.ai_risk_level
     OR OLD.ai_review_notes IS DISTINCT FROM NEW.ai_review_notes
     OR OLD.search_attributes IS DISTINCT FROM NEW.search_attributes THEN
    RAISE EXCEPTION 'AI review fields are system-managed.' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.renew_ad(p_ad_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_ad public.ads;
  v_expires timestamptz;
BEGIN
  SELECT * INTO v_ad FROM public.ads WHERE id = p_ad_id AND user_id = auth.uid() AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_found');
  END IF;
  IF NOT (v_ad.status = 'expired'
          OR (v_ad.status = 'active' AND v_ad.expires_at <= now() + interval '3 days')) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_renewable');
  END IF;

  v_expires := now() + public.ad_lifetime();
  UPDATE public.ads SET status = 'active', expires_at = v_expires, updated_at = now() WHERE id = p_ad_id;
  RETURN jsonb_build_object('success', true, 'expires_at', v_expires);
END;
$$;

REVOKE ALL ON FUNCTION public.renew_ad(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renew_ad(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.ad_lifetime() FROM PUBLIC, anon, authenticated;
