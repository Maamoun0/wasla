-- 🟡7 (FR-2.1): a feed ordered by distance from the user.
--  * search_ads gains p_near_lat/p_near_lng (closest first) and optional
--    p_radius_km (1..500). The position is a query parameter only: it is
--    not stored or logged by the database.
--  * An ad without its own coordinates (location is optional when posting)
--    is placed at its city's centre, so it still takes part.
--  * get_ads_near_me (from before the audit, unused by the app) is dropped:
--    it skipped ads without coordinates and ignored deleted_at.

DROP FUNCTION IF EXISTS public.search_ads(text, integer, integer, public.ad_type_enum, numeric, numeric, boolean, integer, integer, integer, integer);
DROP FUNCTION IF EXISTS public.get_ads_near_me(numeric, numeric, double precision, integer);

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

REVOKE ALL ON FUNCTION public.search_ads(text, integer, integer, public.ad_type_enum, numeric, numeric, boolean, integer, integer, numeric, numeric, numeric, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_ads(text, integer, integer, public.ad_type_enum, numeric, numeric, boolean, integer, integer, numeric, numeric, numeric, integer, integer)
  TO anon, authenticated, service_role;
