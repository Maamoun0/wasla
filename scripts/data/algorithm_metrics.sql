-- Before/after numbers for docs/ALGORITHMS.md, on a database with the
-- staging seed (scripts/data/staging_seed.sql). Read-only.
--   npx -y supabase@2.120.0 db query --linked -f scripts/data/algorithm_metrics.sql
-- Steps that need a function added later are guarded, so this runs before and after.

\pset footer off

\echo === 1. search "عربية": distinct sellers / farm copies in the first 20
SELECT count(DISTINCT user_id) AS distinct_sellers,
       count(*) FILTER (WHERE title = 'عربية بسعر لقطة للبيع فوراً') AS farm_copies,
       max(n) AS max_ads_one_seller
FROM (SELECT a.*, count(*) OVER (PARTITION BY user_id) n FROM public.search_ads(p_query := 'عربية', p_limit := 20) a) s;

\echo === 1a. cars feed (category 29), first 20: farm copies and distinct sellers, old order vs search_ads
WITH old AS (  -- the order before search diversity: featured, then newest
  SELECT user_id, title FROM public.ads
  WHERE status = 'active' AND category_id = 29 AND deleted_at IS NULL
  ORDER BY is_featured DESC, created_at DESC LIMIT 20
), new AS (SELECT user_id, title FROM public.search_ads(p_category_id := 29, p_limit := 20))
SELECT 'old' AS ordering, count(*) FILTER (WHERE title = 'عربية بسعر لقطة للبيع فوراً') farm_copies, count(DISTINCT user_id) sellers FROM old
UNION ALL
SELECT 'search_ads', count(*) FILTER (WHERE title = 'عربية بسعر لقطة للبيع فوراً'), count(DISTINCT user_id) FROM new;

\echo === 1b. default feed: distinct sellers in the first 20
SELECT count(DISTINCT user_id) AS distinct_sellers FROM public.search_ads(p_limit := 20);

\echo === 2. near me (Zamalek, 20 km): position and distance of the nearest regular ad; farthest ad in the first 10
WITH r AS (
  SELECT row_number() OVER () pos, is_featured,
         round((ST_Distance(location_point, ST_SetSRID(ST_MakePoint(31.2194, 30.0609), 4326)::geography) / 1000)::numeric, 1) km
  FROM public.search_ads(p_near_lat := 30.0609, p_near_lng := 31.2194, p_radius_km := 20, p_limit := 100)
)
SELECT (SELECT min(pos) FROM r WHERE NOT is_featured) AS first_regular_pos,
       (SELECT km FROM r WHERE NOT is_featured ORDER BY pos LIMIT 1) AS its_km,
       (SELECT max(km) FROM r WHERE pos <= 10) AS farthest_km_in_top10;

\echo === 3. trust: one 5-star review vs six reviews averaging 4 (best of each)
SELECT (SELECT max(u.trust_score) FROM public.users u WHERE u.is_seed AND NOT u.is_id_verified
          AND (SELECT count(*) FROM public.reviews r WHERE r.reviewed_user_id = u.id) = 1
          AND (SELECT min(rating) FROM public.reviews r WHERE r.reviewed_user_id = u.id) = 5) AS one_5star_unverified,
       (SELECT max(u.trust_score) FROM public.users u WHERE u.is_seed AND NOT u.is_id_verified
          AND (SELECT count(*) FROM public.reviews r WHERE r.reviewed_user_id = u.id) >= 6
          AND (SELECT avg(rating) FROM public.reviews r WHERE r.reviewed_user_id = u.id) >= 4) AS six_plus_avg4_unverified;

\echo === 4. review rings: trust rank of the five ring sellers among all seed users
WITH ring AS (
  SELECT r.reviewed_user_id AS id FROM public.reviews r JOIN public.users rv ON rv.id = r.reviewer_id
  WHERE rv.full_name LIKE 'مستخدم %' GROUP BY 1
), ranked AS (SELECT id, trust_score, rank() OVER (ORDER BY trust_score DESC) rk FROM public.users WHERE is_seed)
SELECT string_agg(rk::text || ' (' || trust_score || ')', ', ' ORDER BY rk) AS ring_ranks FROM ranked WHERE id IN (SELECT id FROM ring);

\echo === 5. car (category 29) price median, plain vs robust
SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY price)) AS plain_median
FROM public.ads WHERE is_seed AND category_id = 29 AND price > 0;
