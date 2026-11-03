-- A category's typical price (docs/ALGORITHMS.md §8). On the seed data the
-- plain median of cars was 33,976 EGP because 100 of 173 ads were one farm's
-- copies; real cars sit around 786,000, so 72 of them looked too expensive.
--
--   1. Leave out suspicious ads: near-duplicates (ad_duplicate_key: title,
--      category, price band) posted by ≥ price_suspicious_accounts sellers.
--   2. Take each seller's median (one seller, one vote: ten copies count once).
--   3. The category's price is the median of those, if ≥ price_min_sellers sellers.
-- price_outlier_ratio(ad) = ad price / that median (e.g. 0.1 = a missing zero).
-- The settings are app_configs values.

INSERT INTO public.app_configs (key, value, description) VALUES
  ('price_exclude_suspicious', 'true', 'Price median: leave out near-duplicates posted by several accounts'),
  ('price_suspicious_accounts', '3', 'Price median: a near-duplicate posted by this many sellers is suspicious'),
  ('price_min_sellers', '5', 'Price median: fewer sellers than this and the category has no median')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.category_price_median(p_category_id integer)
RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  WITH cfg AS (
    SELECT public.config_bool('price_exclude_suspicious', true) AS exclude,
           public.config_numeric('price_suspicious_accounts', 3) AS accounts,
           public.config_numeric('price_min_sellers', 5) AS min_sellers,
           public.config_numeric('search_duplicate_price_band', 1.25) AS band
  ), ads AS (
    SELECT a.user_id, a.price, public.ad_duplicate_key(a.title, a.category_id, a.price, cfg.band) AS dup_key
    FROM public.ads a, cfg
    WHERE a.category_id = p_category_id AND a.status = 'active' AND a.deleted_at IS NULL AND a.price > 0
  ), clean AS (
    SELECT a.* FROM ads a, cfg
    WHERE NOT cfg.exclude
       OR (SELECT count(DISTINCT b.user_id) FROM ads b WHERE b.dup_key = a.dup_key) < cfg.accounts
  ), per_seller AS (
    SELECT user_id, percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS med FROM clean GROUP BY user_id
  )
  SELECT CASE WHEN count(*) >= (SELECT min_sellers FROM cfg)
              THEN round(percentile_cont(0.5) WITHIN GROUP (ORDER BY med)::numeric, 2) END
  FROM per_seller;
$$;

CREATE OR REPLACE FUNCTION public.price_outlier_ratio(p_ad_id uuid)
RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT round(a.price / nullif(public.category_price_median(a.category_id), 0), 4)
  FROM public.ads a WHERE a.id = p_ad_id;
$$;

-- Prices of active ads are public anyway; the functions add no access.
GRANT EXECUTE ON FUNCTION public.category_price_median(integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.price_outlier_ratio(uuid) TO anon, authenticated, service_role;
