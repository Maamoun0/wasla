-- 🟡4 (FR-2.3): filter search by district and by posting date.
--  * search_ads gains p_district_id and p_posted_within_days (1..365, by
--    publication time). Named arguments keep existing callers working.
--  * A saved search can carry the district, and its alerts match it, so an
--    alert covers exactly what the user searched. The date filter is not
--    saved: alerts are about new ads anyway.

DROP FUNCTION IF EXISTS public.search_ads(text, integer, integer, public.ad_type_enum, numeric, numeric, boolean, integer, integer);

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
  p_limit         integer DEFAULT 20,
  p_offset        integer DEFAULT 0
)
RETURNS SETOF public.ads
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_temp
AS $$
  WITH q AS (
    SELECT public.normalize_arabic(btrim(coalesce(p_query, ''))) AS text
  ), terms AS (
    -- Each word becomes a prefix term; characters with meaning in tsquery are dropped.
    SELECT string_agg(quote_literal(w) || ':*', ' & ') AS tsq
    FROM q, regexp_split_to_table(regexp_replace(q.text, '[''\\:&|!()<>*]', ' ', 'g'), '\s+') AS w
    WHERE w <> ''
  )
  SELECT a.*
  FROM public.ads a, q, terms
  WHERE a.status = 'active' AND a.deleted_at IS NULL
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
    -- Posting date = publication (approval) time; 1..365 days.
    AND (p_posted_within_days IS NULL
         OR coalesce(a.published_at, a.created_at) >= now() - make_interval(days => least(greatest(p_posted_within_days, 1), 365)))
  ORDER BY a.is_featured DESC,
           CASE WHEN q.text = '' THEN 0
                ELSE ts_rank(a.search_vector, to_tsquery('simple', terms.tsq))
                     + public.word_similarity(q.text, public.normalize_arabic(a.title)) END DESC,
           a.created_at DESC
  LIMIT least(greatest(p_limit, 1), 100)
  OFFSET greatest(p_offset, 0);
$$;

REVOKE ALL ON FUNCTION public.search_ads(text, integer, integer, public.ad_type_enum, numeric, numeric, boolean, integer, integer, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_ads(text, integer, integer, public.ad_type_enum, numeric, numeric, boolean, integer, integer, integer, integer)
  TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.enqueue_watchlist_matches(p_ad public.ads)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_parent smallint;
  r record;
BEGIN
  SELECT parent_id INTO v_parent FROM public.categories WHERE id = p_ad.category_id;

  FOR r IN
    SELECT DISTINCT ON (s.user_id) s.id, s.user_id,
           coalesce((u.notification_preferences ->> 'watchlist_matches')::boolean, true) AS wants_push
    FROM public.saved_searches s
    JOIN public.users u ON u.id = s.user_id AND u.deleted_at IS NULL
    WHERE s.is_active
      AND s.user_id <> p_ad.user_id
      AND (s.category_id IS NULL OR s.category_id IN (p_ad.category_id, v_parent))
      AND (s.city_id IS NULL OR s.city_id = p_ad.city_id)
      AND (public.saved_search_tsquery(s.keywords) IS NULL
           OR p_ad.search_vector @@ public.saved_search_tsquery(s.keywords))
      AND (NOT s.filters ? 'ad_type' OR p_ad.ad_type::text = s.filters ->> 'ad_type')
      AND (NOT s.filters ? 'district_id' OR p_ad.district_id = (s.filters ->> 'district_id')::integer)
      AND (NOT s.filters ? 'min_price' OR p_ad.price >= (s.filters ->> 'min_price')::numeric)
      AND (NOT s.filters ? 'max_price' OR p_ad.price <= (s.filters ->> 'max_price')::numeric)
    ORDER BY s.user_id, s.created_at
  LOOP
    INSERT INTO public.watchlist_notifications (user_id, ad_id)
    VALUES (r.user_id, p_ad.id)
    ON CONFLICT (user_id, ad_id) DO NOTHING;
    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    UPDATE public.saved_searches SET last_notified_at = now() WHERE id = r.id;
    PERFORM public.enqueue_notification(
      r.user_id, 'saved_search_match', 'إعلان جديد يهمك! 🔔',
      format('لقينا إعلان "%s" يطابق بحثك المحفوظ.', p_ad.title),
      jsonb_build_object('type', 'watchlist_match', 'ad_id', p_ad.id),
      r.wants_push);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_saved_search()
RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp
AS $$
DECLARE
  k text;
BEGIN
  NEW.keywords := nullif(btrim(coalesce(NEW.keywords, '')), '');
  NEW.name := nullif(btrim(coalesce(NEW.name, '')), '');
  NEW.filters := coalesce(NEW.filters, '{}'::jsonb);

  IF jsonb_typeof(NEW.filters) <> 'object' THEN
    RAISE EXCEPTION 'filters must be an object' USING ERRCODE = '22023';
  END IF;
  FOR k IN SELECT jsonb_object_keys(NEW.filters) LOOP
    IF k NOT IN ('min_price', 'max_price', 'ad_type', 'district_id') THEN
      RAISE EXCEPTION 'unknown saved-search filter: %', k USING ERRCODE = '22023';
    END IF;
  END LOOP;
  IF (NEW.filters ? 'min_price' AND jsonb_typeof(NEW.filters -> 'min_price') <> 'number')
     OR (NEW.filters ? 'max_price' AND jsonb_typeof(NEW.filters -> 'max_price') <> 'number') THEN
    RAISE EXCEPTION 'prices must be numbers' USING ERRCODE = '22023';
  END IF;
  IF NEW.filters ? 'district_id' AND (jsonb_typeof(NEW.filters -> 'district_id') <> 'number'
     OR NOT EXISTS (SELECT 1 FROM public.districts WHERE id = (NEW.filters ->> 'district_id')::integer)) THEN
    RAISE EXCEPTION 'invalid district_id' USING ERRCODE = '22023';
  END IF;
  IF NEW.filters ? 'ad_type' AND NEW.filters ->> 'ad_type' NOT IN ('offering', 'seeking') THEN
    RAISE EXCEPTION 'invalid ad_type' USING ERRCODE = '22023';
  END IF;

  IF NEW.category_id IS NULL AND NEW.city_id IS NULL AND NEW.keywords IS NULL
     AND NOT (NEW.filters ?| ARRAY['min_price', 'max_price', 'ad_type', 'district_id']) THEN
    RAISE EXCEPTION 'a saved search needs at least one criterion' USING ERRCODE = '22023';
  END IF;

  IF TG_OP = 'INSERT' AND (SELECT count(*) FROM public.saved_searches WHERE user_id = NEW.user_id) >= 20 THEN
    RAISE EXCEPTION 'saved search limit reached' USING ERRCODE = 'P0001', HINT = 'saved_search_limit';
  END IF;
  RETURN NEW;
END;
$$;
