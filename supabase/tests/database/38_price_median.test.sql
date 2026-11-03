BEGIN;
SELECT plan(6);

-- docs/ALGORITHMS.md §8: the farm's 100 copies of one too-cheap car made the
-- plain median of the cars category 33,976 EGP (real cars: ~786,000), so 72
-- real cars looked "too expensive" and the farm looked normal.
-- Here, in category 30 (motorbikes): three farm accounts with ten copies each
-- at ~30,000, one honest seller with ten ads at 2,000,000, and five honest
-- sellers with one ad each between 500,000 and 900,000.
INSERT INTO auth.users (id, phone)
SELECT ('00000000-0000-0000-0000-0000000005' || lpad(i::text, 2, '0'))::uuid, '2010999005' || lpad(i::text, 2, '0')
FROM generate_series(1, 9) i;

INSERT INTO public.ads (user_id, category_id, title, description, price, city_id, status)
SELECT ('00000000-0000-0000-0000-0000000005' || lpad(f::text, 2, '0'))::uuid, 30, 'موتوسيكل لقطة',
       'نسخة ' || c, 30000 + c * 100, 1, 'active'
FROM generate_series(1, 3) f, generate_series(1, 10) c;
INSERT INTO public.ads (user_id, category_id, title, description, price, city_id, status)
SELECT '00000000-0000-0000-0000-000000000504', 30, 'موتوسيكل فاخر رقم ' || c, 'وصف ' || c, 2000000, 1, 'active'
FROM generate_series(1, 10) c;
INSERT INTO public.ads (user_id, category_id, title, description, price, city_id, status)
SELECT ('00000000-0000-0000-0000-0000000005' || lpad(i::text, 2, '0'))::uuid, 30, 'موتوسيكل مستعمل ' || i,
       'وصف حقيقي ' || i, 500000 + (i - 5) * 100000, 1, 'active'
FROM generate_series(5, 9) i;

SELECT ok((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY price) FROM public.ads WHERE category_id = 30 AND status = 'active') < 100000,
  'the plain median sits on the farm''s price (the problem)');
SELECT is(public.category_price_median(30), 750000::numeric,
  'robust median: per-seller medians, farm copies excluded -> median of 500k..900k and 2M = 750k');
SELECT ok(public.price_outlier_ratio((SELECT id FROM public.ads WHERE category_id = 30 AND price < 40000 LIMIT 1)) < 0.2,
  'a farm ad is far below the robust median');
SELECT ok(public.price_outlier_ratio((SELECT id FROM public.ads WHERE category_id = 30 AND price = 600000 LIMIT 1)) BETWEEN 0.5 AND 2,
  'an honest ad is near it');

-- Settings: without the exclusion the farm's three sellers count (once each).
UPDATE public.app_configs SET value = 'false' WHERE key = 'price_exclude_suspicious';
SELECT is(public.category_price_median(30), 600000::numeric,
  'price_exclude_suspicious off: 9 seller medians (3 farm at ~30.5k, 500k..900k, 2M) -> 600k (one seller, one vote)');
UPDATE public.app_configs SET value = 'true' WHERE key = 'price_exclude_suspicious';
UPDATE public.app_configs SET value = '20' WHERE key = 'price_min_sellers';
SELECT is(public.category_price_median(30), NULL, 'fewer than price_min_sellers sellers: no median');

SELECT * FROM finish();
ROLLBACK;
