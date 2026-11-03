-- "Near me" (docs/ALGORITHMS.md §4): from Zamalek, an ordinary ad 0.2 km away
-- came after every featured ad within 20 km (position 41). Featured now wins
-- only inside a distance band (near_me_band_edges_km, default 1/3/10/25/50 km):
-- a nearer band always comes first. Without a position, nothing changes.

INSERT INTO public.app_configs (key, value, description) VALUES
  ('near_me_band_edges_km', '[1, 3, 10, 25, 50]',
   '"Near me": distance band edges in km; featured ads rank first only inside their band')
ON CONFLICT (key) DO NOTHING;

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
    -- Every word must match, as a prefix, or as one of its synonyms.
    SELECT public.search_tsquery_text(q.text) AS tsq FROM q
  ), cfg AS (
    SELECT greatest(public.config_numeric('search_max_ads_per_seller', 2), 1) AS per_seller,
           public.config_bool('search_collapse_duplicates', true) AS collapse,
           public.config_numeric('search_duplicate_price_band', 1.25) AS band,
           -- "Near me" distance bands (km): featured wins inside a band only.
           coalesce((SELECT array_agg(e::numeric ORDER BY e::numeric)
                     FROM public.app_configs ac, jsonb_array_elements_text(ac.value) e
                     WHERE ac.key = 'near_me_band_edges_km' AND jsonb_typeof(ac.value) = 'array'),
                    ARRAY[1, 3, 10, 25, 50]::numeric[]) AS band_edges
  ), matched AS (
    SELECT a AS ad, a.id, a.user_id, a.is_featured, a.created_at,
           CASE WHEN here.point IS NULL THEN 0 ELSE coalesce(ST_Distance(ad_loc.point, here.point), 'Infinity') END AS dist,
           CASE WHEN q.text = '' THEN 0
                ELSE ts_rank(a.search_vector, to_tsquery('simple', terms.tsq))
                     + public.word_similarity(q.text, public.normalize_arabic(a.title)) END AS relevance,
           public.ad_duplicate_key(a.title, a.category_id, a.price, cfg.band) AS dup_key,
           CASE WHEN here.point IS NULL THEN 0
                ELSE (SELECT count(*) FROM unnest(cfg.band_edges) e
                      WHERE coalesce(ST_Distance(ad_loc.point, here.point), 'Infinity') / 1000 > e) END AS dist_band
    FROM public.ads a
    CROSS JOIN q CROSS JOIN terms CROSS JOIN here CROSS JOIN cfg
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
           OR a.category_id IN (SELECT c2.id FROM public.categories c2 WHERE c2.parent_id = p_category_id))
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
  ), grouped AS (
    -- The best copy of each near-duplicate group (featured, nearest, most relevant, newest).
    SELECT m.*, row_number() OVER (PARTITION BY m.dup_key
                                   ORDER BY m.dist_band, m.is_featured DESC, m.dist, m.relevance DESC, m.created_at DESC) AS copy_rank
    FROM matched m
  ), kept AS (
    SELECT g.*, row_number() OVER (PARTITION BY g.user_id
                                   ORDER BY g.dist_band, g.is_featured DESC, g.dist, g.relevance DESC, g.created_at DESC) AS seller_rank
    FROM grouped g CROSS JOIN cfg
    WHERE NOT cfg.collapse OR g.copy_rank = 1
  )
  SELECT (k.ad).*
  FROM kept k CROSS JOIN cfg
  ORDER BY -- "Near me": nearer distance bands first; inside a band, featured first.
           k.dist_band,
           k.is_featured DESC,
           -- Every seller's first N ads before anyone's next ones.
           ceil(k.seller_rank / cfg.per_seller),
           -- "Near me": closest first (ads with no known place last).
           k.dist,
           k.relevance DESC,
           k.created_at DESC
  LIMIT least(greatest(p_limit, 1), 100)
  OFFSET greatest(p_offset, 0);
$$;
