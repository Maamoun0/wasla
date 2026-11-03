BEGIN;
SELECT plan(4);

-- docs/ALGORITHMS.md §4: from Zamalek, an ordinary ad 0.2 km away came after
-- every featured ad within 20 km (position 41). Featured should win inside a
-- distance band, never across bands.
-- Me: 30.0609, 31.2194. One degree of latitude ≈ 111 km.
INSERT INTO auth.users (id, phone) VALUES ('00000000-0000-0000-0000-000000000201', '201099900201');

INSERT INTO public.ads (user_id, category_id, title, description, price, city_id, status, is_featured,
                        latitude, longitude, published_at, created_at)
VALUES
  ('00000000-0000-0000-0000-000000000201', 29, 'ياقوت قريب جداً', 'إعلان عادي على بعد 200 متر', 1000, 1, 'active', false,
   30.0609 + 0.2 / 111, 31.2194, now(), now()),
  ('00000000-0000-0000-0000-000000000201', 29, 'ياقوت مميز 5 كم', 'إعلان مميز على بعد 5 كم', 2000, 1, 'active', true,
   30.0609 + 5.0 / 111, 31.2194, now(), now()),
  ('00000000-0000-0000-0000-000000000201', 29, 'ياقوت عادي 8 كم', 'إعلان عادي على بعد 8 كم', 3000, 1, 'active', false,
   30.0609 + 8.0 / 111, 31.2194, now(), now()),
  ('00000000-0000-0000-0000-000000000201', 29, 'ياقوت مميز 15 كم', 'إعلان مميز على بعد 15 كم', 4000, 1, 'active', true,
   30.0609 + 15.0 / 111, 31.2194, now(), now());
UPDATE public.app_configs SET value = '10' WHERE key = 'search_max_ads_per_seller';

CREATE TEMP TABLE r AS
SELECT row_number() OVER () AS pos, title
FROM public.search_ads(p_query := 'ياقوت', p_near_lat := 30.0609, p_near_lng := 31.2194, p_radius_km := 20, p_limit := 10);

SELECT is((SELECT title FROM r WHERE pos = 1), 'ياقوت قريب جداً', 'the ad 200 m away comes first, before featured ads farther out');
SELECT is((SELECT title FROM r WHERE pos = 2), 'ياقوت مميز 5 كم', 'inside the 3–10 km band, featured comes first');
SELECT is((SELECT title FROM r WHERE pos = 3), 'ياقوت عادي 8 كم', 'then the regular ad of the same band');

-- The bands come from app_configs: one band of 50 km makes featured win everywhere again.
UPDATE public.app_configs SET value = '[50]' WHERE key = 'near_me_band_edges_km';
SELECT is((SELECT title FROM public.search_ads(p_query := 'ياقوت', p_near_lat := 30.0609, p_near_lng := 31.2194,
                                                p_radius_km := 20, p_limit := 1)),
  'ياقوت مميز 5 كم', 'near_me_band_edges_km is read from app_configs');

SELECT * FROM finish();
ROLLBACK;
