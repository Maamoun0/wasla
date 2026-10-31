-- 🟡6 (FR-5.3): enforce the subscription plan limits.
--  * A user's plan is their active (or trial) subscription's plan, else the
--    'free' plan. Live ads = pending + active (pending counts, so the review
--    queue cannot be flooded).
--  * create_ad_transaction refuses a new ad over max_ads and more photos than
--    max_images_per_ad; renew_ad refuses to bring an expired ad back over
--    max_ads. The limits are the plan rows' values (data, not code).
--  * my_plan_usage() lets the app show the limits before posting.
--  * N23: clients could insert/delete ad_media rows of their own ads at any
--    time, so photos could be swapped after approval without review and
--    without limit. The app only reads ad_media; writes are server-only now.

CREATE OR REPLACE FUNCTION public.user_plan(p_user_id uuid)
RETURNS public.subscription_plans
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT p.* FROM public.subscription_plans p
  WHERE p.id = coalesce(
    (SELECT s.plan_id
     FROM public.user_subscriptions s
     JOIN public.subscription_plans sp ON sp.id = s.plan_id AND sp.is_active
     WHERE s.user_id = p_user_id AND s.status IN ('active', 'trial') AND s.expires_at > now()
     ORDER BY sp.max_ads DESC
     LIMIT 1),
    (SELECT id FROM public.subscription_plans WHERE name = 'free'));
$$;

CREATE OR REPLACE FUNCTION public.live_ad_count(p_user_id uuid)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT count(*)::integer FROM public.ads
  WHERE user_id = p_user_id AND deleted_at IS NULL AND status IN ('pending', 'active');
$$;

-- The single rule: 'ad_limit_reached', 'image_limit_exceeded' or NULL.
-- Used by create_ad_transaction and by create-ad before the AI review.
CREATE OR REPLACE FUNCTION public.plan_violation(p_user_id uuid, p_image_count integer)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_plan public.subscription_plans := public.user_plan(p_user_id);
BEGIN
  IF public.live_ad_count(p_user_id) >= v_plan.max_ads THEN
    RETURN 'ad_limit_reached';
  END IF;
  IF coalesce(p_image_count, 0) > v_plan.max_images_per_ad THEN
    RETURN 'image_limit_exceeded';
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.my_plan_usage()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_plan public.subscription_plans;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not signed in' USING ERRCODE = '42501';
  END IF;
  v_plan := public.user_plan(auth.uid());
  RETURN jsonb_build_object(
    'plan', v_plan.name, 'plan_name_ar', v_plan.name_ar,
    'max_ads', v_plan.max_ads, 'max_images_per_ad', v_plan.max_images_per_ad,
    'live_ads', public.live_ad_count(auth.uid()));
END;
$$;

CREATE OR REPLACE FUNCTION public.create_ad_transaction(
  p_user_id UUID,
  p_temp_draft_id VARCHAR(50),
  p_category_id INT,
  p_title VARCHAR(120),
  p_description TEXT,
  p_ad_type public.ad_type_enum,
  p_price DECIMAL(12,2),
  p_price_type public.price_type_enum,
  p_city_id INT,
  p_district_id INT,
  p_latitude DECIMAL(10,8),
  p_longitude DECIMAL(11,8),
  p_ai_risk_level VARCHAR(20),
  p_ai_review_notes TEXT,
  p_ai_layer_used SMALLINT,
  p_images JSONB,
  p_fields JSONB
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_ad_id UUID;
  v_violation text;
BEGIN
  -- Plan limits (FR-5.3): live ads and photos per ad.
  v_violation := public.plan_violation(p_user_id, jsonb_array_length(coalesce(p_images, '[]'::jsonb)));
  IF v_violation IS NOT NULL THEN
    RAISE EXCEPTION '%', v_violation USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.ads (
    user_id, temp_draft_id, category_id, title, description, ad_type, price, price_type,
    city_id, district_id, latitude, longitude, status,
    ai_risk_level, ai_review_notes, ai_layer_used
  ) VALUES (
    p_user_id, p_temp_draft_id, p_category_id, p_title, p_description, p_ad_type, p_price, p_price_type,
    p_city_id, p_district_id, p_latitude, p_longitude, 'pending',
    CASE WHEN p_ai_risk_level IN ('low', 'medium', 'high', 'unreviewed') THEN p_ai_risk_level ELSE 'unreviewed' END,
    p_ai_review_notes, p_ai_layer_used
  ) RETURNING id INTO v_ad_id;

  INSERT INTO public.ad_media (ad_id, url, type, sort_order, is_primary)
  SELECT v_ad_id, img ->> 'url', 'image', (img ->> 'sort_order')::SMALLINT, coalesce((img ->> 'is_primary')::BOOLEAN, false)
  FROM jsonb_array_elements(coalesce(p_images, '[]'::jsonb)) AS img;

  INSERT INTO public.ad_fields (ad_id, field_id, value_text, value_number, value_boolean, value_json)
  SELECT v_ad_id, (f ->> 'field_id')::INTEGER, f ->> 'value_text', (f ->> 'value_number')::DECIMAL(15,4),
         (f ->> 'value_boolean')::BOOLEAN, f -> 'value_json'
  FROM jsonb_array_elements(coalesce(p_fields, '[]'::jsonb)) AS f;

  RETURN v_ad_id;
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

  -- Bringing an expired ad back counts against the plan like a new one.
  IF v_ad.status = 'expired' AND public.live_ad_count(v_ad.user_id) >= (public.user_plan(v_ad.user_id)).max_ads THEN
    RETURN jsonb_build_object('success', false, 'error', 'ad_limit_reached');
  END IF;

  v_expires := now() + public.ad_lifetime();
  UPDATE public.ads SET status = 'active', expires_at = v_expires, updated_at = now() WHERE id = p_ad_id;
  RETURN jsonb_build_object('success', true, 'expires_at', v_expires);
END;
$$;

REVOKE ALL ON FUNCTION public.user_plan(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.live_ad_count(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.plan_violation(uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.plan_violation(uuid, integer) TO service_role;
REVOKE ALL ON FUNCTION public.my_plan_usage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_plan_usage() TO authenticated;

-- N23: ad photos are written only by create_ad_transaction (service role).
DROP POLICY IF EXISTS ad_media_insert ON public.ad_media;
DROP POLICY IF EXISTS ad_media_delete ON public.ad_media;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.ad_media FROM anon, authenticated;
