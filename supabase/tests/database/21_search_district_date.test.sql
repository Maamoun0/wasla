-- 🟡4 (FR-2.3): search by district and by posting date; saved searches
-- carry the district and their alerts match it.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(10);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'seller@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'w@test.local', '+201000000002', '{}', 'authenticated', 'authenticated'),
  ('44444444-4444-4444-4444-444444444444', 'mod@test.local', '+201000000004', '{}', 'authenticated', 'authenticated');
UPDATE public.users SET user_type = 'moderator' WHERE id = '44444444-4444-4444-4444-444444444444';

-- Two districts of the same city.
CREATE TEMP TABLE d AS
  SELECT city_id, min(id) AS d1, max(id) AS d2 FROM public.districts GROUP BY city_id HAVING count(*) >= 2 ORDER BY city_id LIMIT 1;
GRANT SELECT ON d TO anon, authenticated;

INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, district_id, status, published_at)
SELECT v.id::uuid, '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
       v.title, 'desc', 1000, d.city_id, CASE v.which WHEN 1 THEN d.d1 ELSE d.d2 END, 'active', now() - v.age
FROM d, (VALUES
  ('cccccccc-1111-0000-0000-000000000001', 'إعلان الحي الأول جديد', 1, interval '1 hour'),
  ('cccccccc-1111-0000-0000-000000000002', 'إعلان الحي الأول قديم', 1, interval '20 days'),
  ('cccccccc-1111-0000-0000-000000000003', 'إعلان الحي التاني', 2, interval '2 days')
) AS v(id, title, which, age);

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);
SELECT is((SELECT count(*)::int FROM public.search_ads(p_district_id => (SELECT d1 FROM d))), 2,
  'district filter returns only that district''s ads');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_city_id => (SELECT city_id FROM d), p_posted_within_days => 7)), 2,
  'posted within 7 days excludes older ads');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_district_id => (SELECT d1 FROM d), p_posted_within_days => 1)), 1,
  'district and date combine');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_city_id => (SELECT city_id FROM d), p_posted_within_days => 0)), 1,
  'a date window below 1 day is treated as 1 day');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_city_id => (SELECT city_id FROM d))), 3,
  'without the new filters every ad in the city is returned (existing callers unchanged)');
RESET ROLE;

-- ── Saved searches with a district ────────────────────────────────
SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true),
       set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT lives_ok($$ INSERT INTO public.saved_searches (user_id, city_id, keywords, filters)
                   SELECT auth.uid(), city_id, 'شقة', jsonb_build_object('district_id', d2) FROM d $$,
  'a saved search can carry a district');
SELECT throws_ok($$ INSERT INTO public.saved_searches (user_id, keywords, filters) VALUES (auth.uid(), 'x', '{"district_id": 99999999}') $$,
  '22023', NULL, 'an unknown district is refused');
RESET ROLE;

INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, district_id, status)
SELECT v.id::uuid, '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
       'شقة للبيع', 'desc', 1000, d.city_id, CASE v.which WHEN 1 THEN d.d1 ELSE d.d2 END, 'pending'
FROM d, (VALUES ('cccccccc-2222-0000-0000-000000000001', 1), ('cccccccc-2222-0000-0000-000000000002', 2)) AS v(id, which);
SET LOCAL ROLE service_role;
SELECT public.moderate_ad('cccccccc-2222-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 'approved', NULL);
SELECT public.moderate_ad('cccccccc-2222-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', 'approved', NULL);
RESET ROLE;

SELECT is((SELECT count(*)::int FROM public.notifications_outbox
           WHERE user_id = '22222222-2222-2222-2222-222222222222' AND data ->> 'type' = 'watchlist_match'), 1,
  'the alert fires only for the saved district');
SELECT is((SELECT data ->> 'ad_id' FROM public.notifications_outbox
           WHERE user_id = '22222222-2222-2222-2222-222222222222' AND data ->> 'type' = 'watchlist_match'),
  'cccccccc-2222-0000-0000-000000000002', 'for the ad in that district');
SELECT has_function('public', 'search_ads',
  ARRAY['text', 'integer', 'integer', 'ad_type_enum', 'numeric', 'numeric', 'boolean', 'integer', 'integer', 'numeric', 'numeric', 'numeric', 'integer', 'integer'],
  'one search_ads with the district/date parameters (later also near-me, 🟡7)');

SELECT * FROM finish();
ROLLBACK;
