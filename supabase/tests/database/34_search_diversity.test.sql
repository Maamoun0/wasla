BEGIN;
SELECT plan(6);

-- The case from docs/ALGORITHMS.md §1: one seller posts the same ad over and
-- over, and three fresh accounts post copies of one text. Five honest
-- sellers have one ad each. Everything matches the word زبرجد.
INSERT INTO auth.users (id, phone)
SELECT ('00000000-0000-0000-0000-0000000001' || lpad(i::text, 2, '0'))::uuid, '2010999000' || lpad(i::text, 2, '0')
FROM generate_series(1, 9) i;

-- Seller 01: six copies, prices within a few percent.
INSERT INTO public.ads (user_id, category_id, title, description, price, city_id, status, published_at, created_at)
SELECT '00000000-0000-0000-0000-000000000101', 29, 'زبرجد عربية بسعر لقطة', 'وصف مكرر للاختبار رقم ' || i,
       30000 + i * 200, 1, 'active', now() - (i || ' minutes')::interval, now() - (i || ' minutes')::interval
FROM generate_series(1, 6) i;
-- Sellers 02-04: the same title and price band (the farm).
INSERT INTO public.ads (user_id, category_id, title, description, price, city_id, status, published_at, created_at)
SELECT ('00000000-0000-0000-0000-0000000001' || lpad(i::text, 2, '0'))::uuid, 29, 'زبرجد عربية بسعر لقطة',
       'وصف المزرعة ' || i, 31000 + i * 100, 1, 'active', now() - interval '1 hour', now() - interval '1 hour'
FROM generate_series(2, 4) i;
-- Sellers 05-09: one honest ad each, older (so recency alone would put them last).
INSERT INTO public.ads (user_id, category_id, title, description, price, city_id, status, published_at, created_at)
SELECT ('00000000-0000-0000-0000-0000000001' || lpad(i::text, 2, '0'))::uuid, 29, 'زبرجد سيارة مختلفة ' || i,
       'سيارة حقيقية ' || i, 400000 + i * 50000, 1, 'active', now() - interval '2 days', now() - interval '2 days'
FROM generate_series(5, 9) i;

CREATE TEMP TABLE top AS
SELECT row_number() OVER () AS pos, a.* FROM public.search_ads(p_query := 'زبرجد', p_limit := 10) a;

SELECT is((SELECT count(*) FROM top WHERE title = 'زبرجد عربية بسعر لقطة'), 1::bigint,
  'near-identical ads (title + category + price band) show once, across sellers');
SELECT ok((SELECT max(n) FROM (SELECT count(*) n FROM top GROUP BY user_id) s) <= 2,
  'no seller has more than search_max_ads_per_seller (2) ads on the page');
SELECT is((SELECT count(DISTINCT user_id) FROM top), 6::bigint,
  'six different sellers on the first page (the five honest ones and one copy)');

-- The limits come from app_configs.
UPDATE public.app_configs SET value = 'false' WHERE key = 'search_collapse_duplicates';
SELECT is((SELECT count(*) FROM public.search_ads(p_query := 'زبرجد', p_limit := 10)
           WHERE user_id = '00000000-0000-0000-0000-000000000101'),
  2::bigint, 'with collapsing off, the copying seller still gets only two of the first ten');
UPDATE public.app_configs SET value = 'true' WHERE key = 'search_collapse_duplicates';
UPDATE public.app_configs SET value = '1' WHERE key = 'search_max_ads_per_seller';
SELECT is((SELECT max(n) FROM (SELECT count(*) n FROM public.search_ads(p_query := 'زبرجد', p_limit := 6) GROUP BY user_id) s),
  1::bigint, 'search_max_ads_per_seller is read from app_configs');

-- The seller's other copies are not lost: the second page has them.
UPDATE public.app_configs SET value = 'false' WHERE key = 'search_collapse_duplicates';
UPDATE public.app_configs SET value = '2' WHERE key = 'search_max_ads_per_seller';
SELECT is((SELECT count(*) FROM public.search_ads(p_query := 'زبرجد', p_limit := 100)), 14::bigint,
  'without collapsing every matching ad is still returned, just ordered by tier');

SELECT * FROM finish();
ROLLBACK;
