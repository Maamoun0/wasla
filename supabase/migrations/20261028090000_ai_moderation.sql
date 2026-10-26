-- ================================================================
-- AI-01: server-side AI moderation.
--   * The verdict lives in real columns on ads (the admin review queue
--     selected ai_risk_level / ai_review_notes, which did not exist — the
--     verdict was buried in search_attributes). 'unreviewed' means the AI
--     review did not run or failed: the ad needs a human.
--   * The verdict never publishes an ad: create_ad_transaction always
--     inserts status 'pending'; only moderators change it.
--   * Every decision is logged (ai_moderation_log) with layer, model,
--     reason and any error. Reviews that call the API (layers 2-3) count
--     towards a per-user daily quota (app_configs.ai_moderation_daily_limit).
-- ================================================================

ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS ai_risk_level TEXT
  CHECK (ai_risk_level IN ('low', 'medium', 'high', 'unreviewed'));
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS ai_review_notes TEXT;
-- Queue order for moderators: high, then unreviewed, medium, low.
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS ai_risk_rank SMALLINT
  GENERATED ALWAYS AS (CASE ai_risk_level WHEN 'high' THEN 3 WHEN 'unreviewed' THEN 2
                                          WHEN 'medium' THEN 1 WHEN 'low' THEN 0 END) STORED;

UPDATE public.ads
SET ai_risk_level = CASE WHEN search_attributes ->> 'ai_risk_level' IN ('low', 'medium', 'high')
                         THEN search_attributes ->> 'ai_risk_level' ELSE 'unreviewed' END,
    ai_review_notes = search_attributes ->> 'ai_review_notes'
WHERE ai_risk_level IS NULL;

CREATE INDEX IF NOT EXISTS idx_ads_pending_risk ON public.ads (ai_risk_rank DESC, created_at)
  WHERE status = 'pending';

-- Same signature as before; the verdict now goes to its own columns.
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
BEGIN
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

CREATE TABLE IF NOT EXISTS public.ai_moderation_log (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        REFERENCES public.users(id) ON DELETE SET NULL,
  ad_id         UUID        REFERENCES public.ads(id) ON DELETE CASCADE,
  temp_draft_id VARCHAR(50),
  layer         SMALLINT    NOT NULL CHECK (layer BETWEEN 0 AND 3),
  risk_level    TEXT        NOT NULL CHECK (risk_level IN ('low', 'medium', 'high', 'unreviewed')),
  notes         TEXT,
  model         TEXT,
  error         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ai_moderation_user_time ON public.ai_moderation_log (user_id, created_at DESC);
COMMENT ON TABLE public.ai_moderation_log IS 'قرار المراجعة الآلية لكل إعلان: الطبقة، النموذج، السبب، والخطأ إن وجد';

ALTER TABLE public.ai_moderation_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ai_moderation_log FROM anon, authenticated;
GRANT ALL ON public.ai_moderation_log TO service_role;

INSERT INTO public.app_configs (key, value, description)
VALUES ('ai_moderation_daily_limit', '20', 'أقصى عدد إعلانات لكل مستخدم تمر بالمراجعة الآلية (Claude) خلال 24 ساعة')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.ai_moderation_allowed(p_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT count(*) < coalesce((SELECT (value #>> '{}')::int FROM public.app_configs WHERE key = 'ai_moderation_daily_limit'), 20)
  FROM public.ai_moderation_log
  WHERE user_id = p_user_id AND layer >= 2 AND created_at > now() - interval '24 hours';
$$;

REVOKE ALL ON FUNCTION public.ai_moderation_allowed(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ai_moderation_allowed(uuid) TO service_role;

-- Owners must not be able to rewrite the verdict on their own ads.
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
