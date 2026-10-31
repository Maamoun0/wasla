-- 🟡9: the five admin-panel switches now do what their labels say.
-- They were saved to app_configs but nothing read them.
--  * maintenance_mode: no new ads or renewals (here); no payments or KYC
--    requests (Edge Functions); the app shows a banner.
--  * min_trust_score_to_post: posting needs at least this trust score.
--  * ai_moderation_enabled (create-ad), enable_boost_feature (create-payment)
--    and enable_kyc_verification (submit-kyc-request) are read by the
--    functions; the app hides boosting/verification when they are off.
-- Missing rows are seeded with today's behaviour (all on, minimum score 0):
-- the panel used to show 20 for a missing minimum, which would have blocked
-- every new user (they start at 0) had it been enforced.

INSERT INTO public.app_configs (key, value, description) VALUES
  ('ai_moderation_enabled', 'true', 'تشغيل المراجعة الآلية بالذكاء الاصطناعي قبل المراجعة البشرية'),
  ('enable_boost_feature', 'true', 'السماح بشراء ترويج الإعلانات'),
  ('enable_kyc_verification', 'true', 'السماح بتقديم طلبات توثيق الهوية'),
  ('min_trust_score_to_post', '0', 'أقل مؤشر ثقة مطلوب لنشر إعلان (0 = بدون حد)'),
  ('maintenance_mode', 'false', 'وضع الصيانة: إيقاف النشر والدفع والتوثيق مؤقتاً')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.app_setting_bool(p_key text, p_default boolean)
RETURNS boolean
LANGUAGE sql STABLE SET search_path = public, pg_temp
AS $$
  SELECT coalesce(
    (SELECT CASE lower(value #>> '{}') WHEN 'true' THEN true WHEN 'false' THEN false END
     FROM public.app_configs WHERE key = p_key),
    p_default);
$$;

CREATE OR REPLACE FUNCTION public.app_setting_int(p_key text, p_default integer)
RETURNS integer
LANGUAGE sql STABLE SET search_path = public, pg_temp
AS $$
  SELECT coalesce(
    (SELECT (value #>> '{}')::integer FROM public.app_configs
     WHERE key = p_key AND (value #>> '{}') ~ '^-?[0-9]+$'),
    p_default);
$$;

-- Every rule for posting a new ad, in order: 'maintenance',
-- 'trust_score_too_low', then the plan's 'ad_limit_reached' /
-- 'image_limit_exceeded'; NULL when allowed. create-ad checks it before
-- the AI review; create_ad_transaction checks it again atomically.
CREATE OR REPLACE FUNCTION public.posting_block(p_user_id uuid, p_image_count integer)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.app_setting_bool('maintenance_mode', false) THEN
    RETURN 'maintenance';
  END IF;
  IF coalesce((SELECT trust_score FROM public.users WHERE id = p_user_id), 0)
     < public.app_setting_int('min_trust_score_to_post', 0) THEN
    RETURN 'trust_score_too_low';
  END IF;
  RETURN public.plan_violation(p_user_id, p_image_count);
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
  -- Maintenance, minimum trust score, then plan limits (FR-5.3).
  v_violation := public.posting_block(p_user_id, jsonb_array_length(coalesce(p_images, '[]'::jsonb)));
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
  IF public.app_setting_bool('maintenance_mode', false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'maintenance');
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

REVOKE ALL ON FUNCTION public.posting_block(uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.posting_block(uuid, integer) TO service_role;
