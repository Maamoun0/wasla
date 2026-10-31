-- 🟡13 (FR-2.4): server-side map clusters.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(8);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'seller@test.local', '+201000000001', '{}', 'authenticated', 'authenticated');

-- Three ads close together in Nasr City, one in Maadi (city centre, no coordinates), one hidden.
INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, latitude, longitude, status, is_hidden)
SELECT v.id::uuid, '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
       v.title, 'd', v.price, v.city, v.lat, v.lng, 'active', v.hidden
FROM (VALUES
  ('c1c10000-0000-0000-0000-000000000001', 'نصر 1', 100, 2, 30.0626, 31.3422, false),
  ('c1c10000-0000-0000-0000-000000000002', 'نصر 2', 200, 2, 30.0630, 31.3430, false),
  ('c1c10000-0000-0000-0000-000000000003', 'نصر 3', 300, 2, 30.0620, 31.3410, false),
  ('c1c10000-0000-0000-0000-000000000004', 'المعادي', 400, 3, NULL, NULL, false),
  ('c1c10000-0000-0000-0000-000000000005', 'مخفي', 500, 2, 30.0626, 31.3422, true)
) AS v(id, title, price, city, lat, lng, hidden);

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);

-- Greater Cairo at zoom 10: Nasr City ads in one cell, Maadi in another.
CREATE TEMP TABLE z10 AS SELECT * FROM public.ads_map_clusters(29.8, 31.1, 30.2, 31.6, 10) WHERE ad_count >= 1;
SELECT is((SELECT max(ad_count) FROM z10 WHERE lat BETWEEN 30.05 AND 30.07), 3, 'the three close ads form one cluster');
SELECT is((SELECT ad_id FROM z10 WHERE lat BETWEEN 29.95 AND 29.97), 'c1c10000-0000-0000-0000-000000000004'::uuid,
  'an ad without coordinates sits at its city''s centre, as a single ad');
SELECT is((SELECT title FROM z10 WHERE lat BETWEEN 29.95 AND 29.97), 'المعادي', 'a single-ad cell carries its title');
SELECT is((SELECT sum(ad_count)::int FROM z10 WHERE lat BETWEEN 29.95 AND 30.07), 4, 'hidden ads are not on the map');

-- Zoomed in to street level the close ads separate.
SELECT ok((SELECT count(*) FROM public.ads_map_clusters(30.061, 31.340, 30.064, 31.344, 19)) >= 2, 'zooming in splits the cluster');
-- Out of bounds: nothing.
SELECT is((SELECT count(*)::int FROM public.ads_map_clusters(31.0, 29.8, 31.3, 30.1, 10)), 0, 'only ads inside the bounds');
-- Filters apply like search.
SELECT is((SELECT sum(ad_count)::int FROM public.ads_map_clusters(29.8, 31.1, 30.2, 31.6, 10, p_min_price => 250)), 2,
  'price filter');
SELECT is((SELECT sum(ad_count)::int FROM public.ads_map_clusters(29.8, 31.1, 30.2, 31.6, 10, p_query => 'المعادي')), 1,
  'text query');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
