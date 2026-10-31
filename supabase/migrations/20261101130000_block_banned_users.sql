-- 🟡10 (FR-6.2): a suspended or banned user disappears at once.
--  * Their ads are hidden (ads.is_hidden, unused until now) the moment their
--    status changes, and shown again if they are reactivated. Hidden ads are
--    excluded from search, the public read policy and phone reveals.
--  * Their Auth sessions and refresh tokens are deleted at once, so no new
--    access token can be issued. The access token already issued stays
--    valid until it expires (jwt_expiry, at most an hour): posting, phone
--    reveals, payments and KYC therefore check account_blocked() as well.

CREATE OR REPLACE FUNCTION public.account_blocked(p_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT coalesce((SELECT status IN ('suspended', 'banned', 'deleted') FROM public.users WHERE id = p_user_id), false);
$$;

CREATE OR REPLACE FUNCTION public.apply_user_block()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status IN ('suspended', 'banned') AND OLD.status NOT IN ('suspended', 'banned') THEN
    UPDATE public.ads SET is_hidden = true WHERE user_id = NEW.id AND NOT coalesce(is_hidden, false);
    DELETE FROM auth.refresh_tokens WHERE user_id = NEW.id::text;
    DELETE FROM auth.sessions WHERE user_id = NEW.id;
  ELSIF NEW.status = 'active' AND OLD.status IN ('suspended', 'banned') THEN
    UPDATE public.ads SET is_hidden = false WHERE user_id = NEW.id AND is_hidden;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_user_block ON public.users;
CREATE TRIGGER trg_apply_user_block
  AFTER UPDATE OF status ON public.users
  FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.apply_user_block();

-- Public reads skip hidden ads; owners and moderators still see them.
DROP POLICY IF EXISTS ads_select ON public.ads;
CREATE POLICY ads_select ON public.ads FOR SELECT USING (
  (status = 'active' AND NOT coalesce(is_hidden, false)) OR user_id = auth.uid() OR public.is_moderator());

CREATE OR REPLACE FUNCTION public.search_ads(
  p_query         text DEFAULT NULL,
  p_category_id   integer DEFAULT NULL,
  p_city_id       integer DEFAULT NULL,
  p_ad_type       public.ad_type_enum DEFAULT NULL,
  p_min_price     numeric DEFAULT NULL,
  p_max_price     numeric DEFAULT NULL,
  p_featured_only boolean DEFAULT false,
  p_district_id   integer DEFAULT NULL,
  p_posted_within_days integer DEFAULT NULL,
  p_near_lat      numeric DEFAULT NULL,
  p_near_lng      numeric DEFAULT NULL,
  p_radius_km     numeric DEFAULT NULL,
  p_limit         integer DEFAULT 20,
  p_offset        integer DEFAULT 0
)
RETURNS SETOF public.ads
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_temp
AS $$
  WITH q AS (
    SELECT public.normalize_arabic(btrim(coalesce(p_query, ''))) AS text
  ), here AS (
    -- The caller's position (used for this query only, never stored).
    SELECT CASE WHEN p_near_lat BETWEEN -90 AND 90 AND p_near_lng BETWEEN -180 AND 180
                THEN ST_SetSRID(ST_MakePoint(p_near_lng, p_near_lat), 4326)::geography END AS point
  ), terms AS (
    -- Each word becomes a prefix term; characters with meaning in tsquery are dropped.
    SELECT string_agg(quote_literal(w) || ':*', ' & ') AS tsq
    FROM q, regexp_split_to_table(regexp_replace(q.text, '[''\\:&|!()<>*]', ' ', 'g'), '\s+') AS w
    WHERE w <> ''
  )
  SELECT a.*
  FROM public.ads a
  CROSS JOIN q CROSS JOIN terms CROSS JOIN here
  -- An ad without its own coordinates is placed at its city's centre.
  LEFT JOIN public.cities c ON c.id = a.city_id
  CROSS JOIN LATERAL (
    SELECT coalesce(a.location_point,
                    CASE WHEN c.latitude IS NOT NULL AND c.longitude IS NOT NULL
                         THEN ST_SetSRID(ST_MakePoint(c.longitude, c.latitude), 4326)::geography END) AS point
  ) ad_loc
  WHERE a.status = 'active' AND a.deleted_at IS NULL AND NOT coalesce(a.is_hidden, false)
    AND (q.text = ''
         OR a.search_vector @@ to_tsquery('simple', terms.tsq)
         OR public.word_similarity(q.text, public.normalize_arabic(a.title)) >= 0.5)
    AND (p_category_id IS NULL OR a.category_id = p_category_id
         OR a.category_id IN (SELECT c.id FROM public.categories c WHERE c.parent_id = p_category_id))
    AND (p_city_id IS NULL OR a.city_id = p_city_id)
    AND (p_ad_type IS NULL OR a.ad_type = p_ad_type)
    AND (p_min_price IS NULL OR a.price >= p_min_price)
    AND (p_max_price IS NULL OR a.price <= p_max_price)
    AND (NOT p_featured_only OR a.is_featured)
    AND (p_district_id IS NULL OR a.district_id = p_district_id)
    AND (here.point IS NULL OR p_radius_km IS NULL
         OR ST_DWithin(ad_loc.point, here.point, least(greatest(p_radius_km, 1), 500) * 1000))
    -- Posting date = publication (approval) time; 1..365 days.
    AND (p_posted_within_days IS NULL
         OR coalesce(a.published_at, a.created_at) >= now() - make_interval(days => least(greatest(p_posted_within_days, 1), 365)))
  ORDER BY a.is_featured DESC,
           -- "Near me": closest first (ads with no known place last).
           CASE WHEN here.point IS NULL THEN 0 ELSE coalesce(ST_Distance(ad_loc.point, here.point), 'Infinity') END,
           CASE WHEN q.text = '' THEN 0
                ELSE ts_rank(a.search_vector, to_tsquery('simple', terms.tsq))
                     + public.word_similarity(q.text, public.normalize_arabic(a.title)) END DESC,
           a.created_at DESC
  LIMIT least(greatest(p_limit, 1), 100)
  OFFSET greatest(p_offset, 0);
$$;

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
  -- A suspended or banned caller's access token is still valid for up to an hour.
  IF public.account_blocked(v_caller) THEN
    RAISE EXCEPTION 'account blocked' USING ERRCODE = '42501';
  END IF;
  IF p_contact_type NOT IN ('phone', 'whatsapp') THEN
    RAISE EXCEPTION 'unsupported contact type: %', p_contact_type USING ERRCODE = '22023';
  END IF;

  -- Serialise each user's requests so concurrent calls cannot overshoot the limit.
  PERFORM pg_advisory_xact_lock(hashtextextended('reveal_seller_phone:' || v_caller::text, 0));

  SELECT a.user_id, u.phone INTO v_owner, v_phone
  FROM public.ads a JOIN public.users u ON u.id = a.user_id
  WHERE a.id = p_ad_id AND a.status = 'active' AND a.deleted_at IS NULL AND u.deleted_at IS NULL
    AND NOT coalesce(a.is_hidden, false);

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

CREATE OR REPLACE FUNCTION public.posting_block(p_user_id uuid, p_image_count integer)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.app_setting_bool('maintenance_mode', false) THEN
    RETURN 'maintenance';
  END IF;
  IF public.account_blocked(p_user_id) THEN
    RETURN 'account_blocked';
  END IF;
  IF coalesce((SELECT trust_score FROM public.users WHERE id = p_user_id), 0)
     < public.app_setting_int('min_trust_score_to_post', 0) THEN
    RETURN 'trust_score_too_low';
  END IF;
  RETURN public.plan_violation(p_user_id, p_image_count);
END;
$$;

REVOKE ALL ON FUNCTION public.account_blocked(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.account_blocked(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.apply_user_block() FROM PUBLIC, anon, authenticated;
