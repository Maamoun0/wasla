-- 🟡12: views are counted (not the owner's, once a day per viewer, guests
-- capped) and the owner sees totals and a 30-day series.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(11);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'seller@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'buyer@test.local', '+201000000002', '{}', 'authenticated', 'authenticated');
INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, status) VALUES
  ('9e9e0000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
   'إعلان', 'd', 1, (SELECT min(id) FROM public.cities), 'active');

CREATE FUNCTION pg_temp.as_user(uid text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claim.sub', uid, true),
         set_config('request.jwt.claims', format('{"sub":"%s","role":"authenticated"}', uid), true);
$$;

SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222');
SET LOCAL ROLE authenticated;
SELECT is(public.record_ad_view('9e9e0000-0000-0000-0000-000000000001'), true, 'a buyer''s view is counted');
SELECT is(public.record_ad_view('9e9e0000-0000-0000-0000-000000000001'), false, 'once a day');
SELECT reveal FROM (SELECT public.reveal_seller_phone('9e9e0000-0000-0000-0000-000000000001', 'whatsapp') AS reveal) r;
SELECT throws_ok($$ SELECT public.ad_performance('9e9e0000-0000-0000-0000-000000000001') $$, '42501', NULL,
  'only the owner sees the numbers');
SELECT throws_ok($$ SELECT 1 FROM public.ad_views $$, '42501', NULL, 'clients cannot read who viewed');
RESET ROLE;

SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111');
SET LOCAL ROLE authenticated;
SELECT is(public.record_ad_view('9e9e0000-0000-0000-0000-000000000001'), false, 'the owner''s own views do not count');
RESET ROLE;

SELECT set_config('request.jwt.claims', '{"role":"anon"}', true), set_config('request.jwt.claim.sub', '', true);
SET LOCAL ROLE anon;
SELECT is((SELECT count(*)::int FROM generate_series(1, 40) g WHERE public.record_ad_view('9e9e0000-0000-0000-0000-000000000001')), 30,
  'guest views are capped at 30 per ad per minute');
RESET ROLE;

SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111');
SET LOCAL ROLE authenticated;
CREATE TEMP TABLE perf AS SELECT public.ad_performance('9e9e0000-0000-0000-0000-000000000001') AS p;
RESET ROLE;
SELECT is((SELECT (p ->> 'views')::int FROM perf), 31, 'total views: 1 buyer + 30 guests');
SELECT is((SELECT (p ->> 'whatsapp')::int FROM perf), 1, 'WhatsApp contacts come from contact_logs');
SELECT is((SELECT (p ->> 'calls')::int FROM perf), 0, 'calls counted separately');
SELECT is((SELECT jsonb_array_length(p -> 'daily') FROM perf), 30, 'a 30-day daily series');
SELECT is((SELECT (p -> 'daily' -> 29 ->> 'views')::int FROM perf), 31, 'today''s views in the last point');

SELECT * FROM finish();
ROLLBACK;
