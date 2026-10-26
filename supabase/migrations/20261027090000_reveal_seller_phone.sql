-- ================================================================
-- Seller phone numbers are revealed to signed-in users only, through
-- reveal_seller_phone(), with a per-user limit on distinct ads and a log
-- of every request (including refusals). Replaces get_ad_contact().
-- ================================================================

CREATE TABLE IF NOT EXISTS public.phone_reveal_log (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  ad_id        UUID        REFERENCES public.ads(id) ON DELETE SET NULL,
  outcome      TEXT        NOT NULL CHECK (outcome IN ('revealed', 'rate_limited', 'not_available')),
  contact_type TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_phone_reveal_user_time ON public.phone_reveal_log (user_id, created_at DESC);
COMMENT ON TABLE public.phone_reveal_log IS 'كل طلب لكشف رقم بائع — للحد من جمع الأرقام والتدقيق';

ALTER TABLE public.phone_reveal_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.phone_reveal_log FROM anon, authenticated;
GRANT ALL ON public.phone_reveal_log TO service_role;

INSERT INTO public.app_configs (key, value, description) VALUES
  ('phone_reveal_limit_per_hour', '20',  'أقصى عدد إعلانات مختلفة يكشف المستخدم رقم بائعها في الساعة'),
  ('phone_reveal_limit_per_day',  '100', 'أقصى عدد إعلانات مختلفة يكشف المستخدم رقم بائعها في اليوم')
ON CONFLICT (key) DO NOTHING;

DROP FUNCTION IF EXISTS public.get_ad_contact(uuid, text);

-- Returns {status: ok, phone} | {status: rate_limited, retry_after_seconds}
--       | {status: not_available}.
-- Refusals are returned rather than raised so they can be logged.
-- Re-revealing an ad already revealed in the last 24h does not use quota.
CREATE OR REPLACE FUNCTION public.reveal_seller_phone(p_ad_id uuid, p_contact_type text DEFAULT 'phone')
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller     uuid := auth.uid();
  v_owner      uuid;
  v_phone      text;
  v_hour_limit int;
  v_day_limit  int;
  v_hour_count int;
  v_day_count  int;
  v_oldest     timestamptz;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_contact_type NOT IN ('phone', 'whatsapp') THEN
    RAISE EXCEPTION 'unsupported contact type: %', p_contact_type USING ERRCODE = '22023';
  END IF;

  -- Serialise each user's requests so concurrent calls cannot overshoot the limit.
  PERFORM pg_advisory_xact_lock(hashtextextended('reveal_seller_phone:' || v_caller::text, 0));

  SELECT a.user_id, u.phone INTO v_owner, v_phone
  FROM public.ads a JOIN public.users u ON u.id = a.user_id
  WHERE a.id = p_ad_id AND a.status = 'active' AND a.deleted_at IS NULL AND u.deleted_at IS NULL;

  IF NOT FOUND THEN
    INSERT INTO public.phone_reveal_log (user_id, ad_id, outcome, contact_type)
    VALUES (v_caller, (SELECT id FROM public.ads WHERE id = p_ad_id), 'not_available', p_contact_type);
    RETURN jsonb_build_object('status', 'not_available');
  END IF;

  IF v_owner <> v_caller AND NOT EXISTS (
    SELECT 1 FROM public.phone_reveal_log
    WHERE user_id = v_caller AND ad_id = p_ad_id AND outcome = 'revealed'
      AND created_at > now() - interval '24 hours'
  ) THEN
    SELECT coalesce((SELECT (value #>> '{}')::int FROM public.app_configs WHERE key = 'phone_reveal_limit_per_hour'), 20),
           coalesce((SELECT (value #>> '{}')::int FROM public.app_configs WHERE key = 'phone_reveal_limit_per_day'), 100)
    INTO v_hour_limit, v_day_limit;

    SELECT count(DISTINCT ad_id) FILTER (WHERE created_at > now() - interval '1 hour'),
           count(DISTINCT ad_id)
    INTO v_hour_count, v_day_count
    FROM public.phone_reveal_log
    WHERE user_id = v_caller AND outcome = 'revealed' AND created_at > now() - interval '24 hours';

    IF v_hour_count >= v_hour_limit OR v_day_count >= v_day_limit THEN
      SELECT min(created_at) INTO v_oldest
      FROM public.phone_reveal_log
      WHERE user_id = v_caller AND outcome = 'revealed'
        AND created_at > now() - CASE WHEN v_day_count >= v_day_limit THEN interval '24 hours' ELSE interval '1 hour' END;

      INSERT INTO public.phone_reveal_log (user_id, ad_id, outcome, contact_type)
      VALUES (v_caller, p_ad_id, 'rate_limited', p_contact_type);

      RETURN jsonb_build_object(
        'status', 'rate_limited',
        'retry_after_seconds', greatest(1, ceil(extract(epoch FROM
          (v_oldest + CASE WHEN v_day_count >= v_day_limit THEN interval '24 hours' ELSE interval '1 hour' END) - now())))::int);
    END IF;
  END IF;

  INSERT INTO public.phone_reveal_log (user_id, ad_id, outcome, contact_type)
  VALUES (v_caller, p_ad_id, 'revealed', p_contact_type);

  IF v_owner <> v_caller THEN
    INSERT INTO public.contact_logs (ad_id, user_id, contact_type)
    VALUES (p_ad_id, v_caller, p_contact_type::public.contact_type_enum);
  END IF;

  RETURN jsonb_build_object('status', 'ok', 'phone', v_phone);
END;
$$;

REVOKE ALL ON FUNCTION public.reveal_seller_phone(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reveal_seller_phone(uuid, text) TO authenticated, service_role;
