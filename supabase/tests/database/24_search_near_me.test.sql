-- 🟡7 (FR-2.1): "near me" orders ads by distance; ads without their own
-- coordinates use their city's centre; an optional radius limits the feed.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(8);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated');

-- Seed cities: 1 Downtown Cairo, 3 Maadi, 9 Fifth Settlement, 25 Smouha (Alexandria).
INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, latitude, longitude, status, is_featured) VALUES
  ('eeee0000-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
   'المعادي بدون إحداثيات', 'd', 1, 3, NULL, NULL, 'active', false),
  ('eeee0000-0000-0000-0000-00000000000b', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
   'الزمالك بإحداثيات', 'd', 1, 1, 30.0659, 31.2195, 'active', false),
  ('eeee0000-0000-0000-0000-00000000000c', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
   'التجمع', 'd', 1, 9, NULL, NULL, 'active', false),
  ('eeee0000-0000-0000-0000-00000000000d', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
   'سموحة', 'd', 1, 25, NULL, NULL, 'active', false);

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);
-- From Downtown Cairo (30.0444, 31.2357).
SELECT results_eq(
  $$ SELECT title::text FROM public.search_ads(p_near_lat => 30.0444, p_near_lng => 31.2357)
     WHERE id::text LIKE 'eeee0000%' $$,
  $$ VALUES ('الزمالك بإحداثيات'), ('المعادي بدون إحداثيات'), ('التجمع'), ('سموحة') $$,
  'closest first; ads without coordinates are placed at their city''s centre');
SELECT results_eq(
  $$ SELECT title::text FROM public.search_ads(p_near_lat => 30.0444, p_near_lng => 31.2357, p_radius_km => 15)
     WHERE id::text LIKE 'eeee0000%' $$,
  $$ VALUES ('الزمالك بإحداثيات'), ('المعادي بدون إحداثيات') $$,
  'a 15 km radius keeps only nearby ads');
SELECT results_eq(
  $$ SELECT title::text FROM public.search_ads(p_near_lat => 31.2, p_near_lng => 29.95)
     WHERE id::text LIKE 'eeee0000%' LIMIT 1 $$,
  $$ VALUES ('سموحة') $$,
  'from Alexandria the Alexandria ad comes first');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_near_lat => 999, p_near_lng => 31.2357) WHERE id::text LIKE 'eeee0000%'), 4,
  'an invalid position is ignored instead of failing');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_near_lat => 30.0444, p_near_lng => 31.2357, p_radius_km => 0) WHERE id::text LIKE 'eeee0000%'), 0,
  'a radius below 1 km is treated as 1 km (the nearest ad is ~2.5 km away)');
RESET ROLE;

-- Featured ads keep their paid placement inside their distance band only
-- (near_me_band_edges_km): a featured ad ~25 km away no longer jumps ahead
-- of ads 2–10 km away. With one wide band, it does again.
UPDATE public.ads SET is_featured = true WHERE id = 'eeee0000-0000-0000-0000-00000000000c';
SET LOCAL ROLE anon;
SELECT results_eq(
  $$ SELECT title::text FROM public.search_ads(p_near_lat => 30.0444, p_near_lng => 31.2357, p_radius_km => 50)
     WHERE id::text LIKE 'eeee0000%' LIMIT 2 $$,
  $$ VALUES ('الزمالك بإحداثيات'), ('المعادي بدون إحداثيات') $$,
  'a featured ad in a farther distance band does not jump ahead of nearer ads');
RESET ROLE;
UPDATE public.app_configs SET value = '[50]' WHERE key = 'near_me_band_edges_km';
SET LOCAL ROLE anon;
SELECT results_eq(
  $$ SELECT title::text FROM public.search_ads(p_near_lat => 30.0444, p_near_lng => 31.2357, p_radius_km => 50)
     WHERE id::text LIKE 'eeee0000%' LIMIT 2 $$,
  $$ VALUES ('التجمع'), ('الزمالك بإحداثيات') $$,
  'inside one band the featured ad comes first, then the closest');
RESET ROLE;
SELECT hasnt_function('public', 'get_ads_near_me', 'the old near-me function is gone');

SELECT * FROM finish();
ROLLBACK;
