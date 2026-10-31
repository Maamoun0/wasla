-- 🟡1: saved searches written from the app match like search does
-- (Arabic-normalised, word prefixes, ad type) and are validated on write.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(14);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'seller@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'w1@test.local', '+201000000002', '{}', 'authenticated', 'authenticated'),
  ('33333333-3333-3333-3333-333333333333', 'w2@test.local', '+201000000003', '{}', 'authenticated', 'authenticated'),
  ('55555555-5555-5555-5555-555555555555', 'w3@test.local', '+201000000005', '{}', 'authenticated', 'authenticated'),
  ('44444444-4444-4444-4444-444444444444', 'mod@test.local', '+201000000004', '{}', 'authenticated', 'authenticated');
UPDATE public.users SET user_type = 'moderator' WHERE id = '44444444-4444-4444-4444-444444444444';

INSERT INTO public.saved_searches (user_id, name, keywords, filters) VALUES
  ('22222222-2222-2222-2222-222222222222', 'سيارة', 'سيارة', '{}'),
  ('33333333-3333-3333-3333-333333333333', 'كورولا تويوتا', 'كورولا تويوتا', '{}'),
  ('55555555-5555-5555-5555-555555555555', 'مطلوب سيارة', 'سيارة', '{"ad_type": "seeking"}');

INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, status, ad_type) VALUES
  ('aaaaaaaa-0000-0000-0000-0000000000a1', '11111111-1111-1111-1111-111111111111',
   (SELECT id FROM public.categories WHERE slug = 'cars'), 'سياره تويوتا كورولا 2015 للبيع', 'حالة ممتازة', 400000,
   (SELECT min(id) FROM public.cities), 'pending', 'offering');

SET LOCAL ROLE service_role;
SELECT public.moderate_ad('aaaaaaaa-0000-0000-0000-0000000000a1', '44444444-4444-4444-4444-444444444444', 'approved', NULL);
RESET ROLE;

SELECT is((SELECT count(*)::int FROM public.notifications_outbox
           WHERE user_id = '22222222-2222-2222-2222-222222222222' AND data ->> 'type' = 'watchlist_match'), 1,
  'a saved "سيارة" matches an ad that says "سياره" (Arabic normalisation)');
SELECT is((SELECT count(*)::int FROM public.notifications_outbox
           WHERE user_id = '33333333-3333-3333-3333-333333333333' AND data ->> 'type' = 'watchlist_match'), 1,
  'every saved word must appear, in any order');
SELECT is((SELECT count(*)::int FROM public.notifications_outbox
           WHERE user_id = '55555555-5555-5555-5555-555555555555' AND data ->> 'type' = 'watchlist_match'), 0,
  'a search for "wanted" ads is not alerted about an "offering" ad');
SELECT is(public.saved_search_tsquery('  '), NULL, 'blank keywords mean no keyword filter');

-- ── Writes from the app ───────────────────────────────────────────
SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true),
       set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT lives_ok(
  $$ INSERT INTO public.saved_searches (user_id, name, category_id, city_id, keywords, filters)
     VALUES (auth.uid(), 'شقق', (SELECT id FROM public.categories WHERE slug = 'real-estate'), (SELECT min(id) FROM public.cities),
             ' شقة ', '{"min_price": 100000, "max_price": 900000, "ad_type": "offering"}') $$,
  'the app saves a search with category, city, keywords, price range and type');
SELECT is((SELECT keywords FROM public.saved_searches WHERE name = 'شقق'), 'شقة', 'keywords are trimmed');
SELECT throws_ok($$ INSERT INTO public.saved_searches (user_id, name) VALUES (auth.uid(), 'كل شيء') $$,
  '22023', NULL, 'a search without any criterion is refused (it would alert on every ad)');
SELECT throws_ok($$ INSERT INTO public.saved_searches (user_id, keywords, filters) VALUES (auth.uid(), 'x', '{"radius": 5}') $$,
  '22023', NULL, 'unknown filter keys are refused');
SELECT throws_ok($$ INSERT INTO public.saved_searches (user_id, keywords, filters) VALUES (auth.uid(), 'x', '{"min_price": "cheap"}') $$,
  '22023', NULL, 'prices must be numbers');
SELECT throws_ok($$ INSERT INTO public.saved_searches (user_id, keywords) VALUES ('33333333-3333-3333-3333-333333333333', 'x') $$,
  '42501', NULL, 'users cannot save searches for someone else');
SELECT throws_ok($$ UPDATE public.saved_searches SET last_notified_at = now() WHERE user_id = auth.uid() $$,
  '42501', NULL, 'users cannot touch last_notified_at');
SELECT lives_ok($$ UPDATE public.saved_searches SET name = 'سيارات', is_active = false WHERE user_id = auth.uid() AND keywords = 'سيارة' $$,
  'users rename and pause their own searches');
SELECT lives_ok($$ INSERT INTO public.saved_searches (user_id, keywords)
                   SELECT auth.uid(), 'بحث ' || g FROM generate_series(1, 18) g $$,
  'up to 20 saved searches per user');
SELECT throws_ok($$ INSERT INTO public.saved_searches (user_id, keywords) VALUES (auth.uid(), 'واحد زيادة') $$,
  'P0001', 'saved search limit reached', 'the 21st is refused');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
