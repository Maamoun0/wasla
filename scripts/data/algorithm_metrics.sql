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

\echo === 3b. pairs where a 1-review seller outranks a seller with 6+ reviews averaging 4+ (same verification), old formula vs current
WITH s AS (
  SELECT u.id, u.is_id_verified v, u.trust_score AS cur,
         count(r.*) n, avg(r.rating) a,
         -- the formula before the Bayesian average
         CASE WHEN u.is_id_verified THEN 30 ELSE 0 END + coalesce(avg(r.rating), 0) / 5 * 40 + least(count(r.*), 20)
           + least(floor(extract(epoch FROM now() - u.created_at) / 2592000)::int, 10) AS old
  FROM public.users u LEFT JOIN public.reviews r ON r.reviewed_user_id = u.id AND r.status = 'active'
  WHERE u.is_seed
    -- The planted ring sellers are measured in 4/4b (their fake reviews now
    -- weigh little, so ranking below a one-review seller is intended).
    AND NOT EXISTS (SELECT 1 FROM public.reviews x JOIN public.users xr ON xr.id = x.reviewer_id
                    WHERE x.reviewed_user_id = u.id AND xr.full_name LIKE 'مستخدم %')
  GROUP BY u.id
)
SELECT count(*) FILTER (WHERE one.old > many.old) AS inversions_old,
       count(*) FILTER (WHERE one.cur > many.cur) AS inversions_now,
       count(*) AS pairs
FROM s one JOIN s many ON one.v = many.v
WHERE one.n = 1 AND many.n >= 6 AND many.a >= 4;

\echo === 4. review rings: trust rank of the five ring sellers among all seed users
WITH ring AS (
  SELECT r.reviewed_user_id AS id FROM public.reviews r JOIN public.users rv ON rv.id = r.reviewer_id
  WHERE rv.full_name LIKE 'مستخدم %' GROUP BY 1
), ranked AS (SELECT id, trust_score, rank() OVER (ORDER BY trust_score DESC) rk FROM public.users WHERE is_seed)
SELECT string_agg(rk::text || ' (' || trust_score || ')', ', ' ORDER BY rk) AS ring_ranks FROM ranked WHERE id IN (SELECT id FROM ring);

\echo === 4b. flagged reviews: ring (planted) vs everyone else (false positives), when the column exists
SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reviews' AND column_name = 'flagged_at')
       THEN (SELECT format('ring %s of %s flagged; others %s of %s flagged',
                count(*) FILTER (WHERE ring AND flagged), count(*) FILTER (WHERE ring),
                count(*) FILTER (WHERE NOT ring AND flagged), count(*) FILTER (WHERE NOT ring))
             FROM (SELECT rv.full_name LIKE 'مستخدم %' AS ring, (to_jsonb(r) ->> 'flagged_at') IS NOT NULL AS flagged
                   FROM public.reviews r JOIN public.users rv ON rv.id = r.reviewer_id WHERE r.is_seed) x)
       ELSE 'no flagging yet' END AS flags;

\echo === 5. cars (category 29): plain vs robust median; real cars flagged "too expensive" (> 5x); farm ads flagged "too cheap" (< 1/5)
WITH plain AS (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS m FROM public.ads WHERE category_id = 29 AND status = 'active' AND price > 0),
robust AS (SELECT CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'category_price_median')
                       THEN public.category_price_median(29) END AS m),
cars AS (SELECT price, title = 'عربية بسعر لقطة للبيع فوراً' AS farm FROM public.ads WHERE category_id = 29 AND status = 'active' AND price > 0)
SELECT round((SELECT m FROM plain)) AS plain_median, round((SELECT m FROM robust)) AS robust_median,
       count(*) FILTER (WHERE NOT farm AND price > 5 * (SELECT m FROM plain)) AS real_high_plain,
       count(*) FILTER (WHERE NOT farm AND price > 5 * (SELECT m FROM robust)) AS real_high_robust,
       count(*) FILTER (WHERE farm AND price < (SELECT m FROM plain) / 5) AS farm_low_plain,
       count(*) FILTER (WHERE farm AND price < (SELECT m FROM robust) / 5) AS farm_low_robust,
       count(*) FILTER (WHERE farm) AS farm_active
FROM cars;
