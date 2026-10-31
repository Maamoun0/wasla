-- 🟡11 (FR-2.2): search and saved-search alerts understand synonyms.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(10);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'seller@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'watcher@test.local', '+201000000002', '{}', 'authenticated', 'authenticated'),
  ('44444444-4444-4444-4444-444444444444', 'mod@test.local', '+201000000004', '{}', 'authenticated', 'authenticated');
UPDATE public.users SET user_type = 'moderator' WHERE id = '44444444-4444-4444-4444-444444444444';

INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, status) VALUES
  ('5a5a0000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
   'عربية مستعملة للبيع', 'فبريكة', 1, (SELECT min(id) FROM public.cities), 'active'),
  ('5a5a0000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
   'جوال سامسونج', 'حالة ممتازة', 1, (SELECT min(id) FROM public.cities), 'active'),
  ('5a5a0000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
   'لاب توب ديل', 'رام 16', 1, (SELECT min(id) FROM public.cities), 'active');

CREATE FUNCTION pg_temp.found(q text) RETURNS text[] LANGUAGE sql AS $$
  SELECT coalesce(array_agg(title::text ORDER BY title), '{}') FROM public.search_ads(p_query => q) WHERE id::text LIKE '5a5a0000%';
$$;

SELECT is(pg_temp.found('سيارة'), ARRAY['عربية مستعملة للبيع'], 'سيارة finds an ad that says عربية');
SELECT is(pg_temp.found('سياره'), ARRAY['عربية مستعملة للبيع'], 'also typed with ه');
SELECT is(pg_temp.found('موبايل'), ARRAY['جوال سامسونج'], 'موبايل finds جوال');
SELECT is(pg_temp.found('لابتوب'), ARRAY['لاب توب ديل'], 'لابتوب finds the phrase لاب توب');
SELECT is(pg_temp.found('عربية فبريكة'), ARRAY['عربية مستعملة للبيع'], 'every word must still match (here via title and description)');
SELECT is(pg_temp.found('سيارة حمراء'), '{}'::text[], 'a word with no match keeps the ad out');
SELECT is(pg_temp.found('شقة'), '{}'::text[], 'unrelated groups do not leak into each other');

-- Saved-search alerts use the same expansion.
INSERT INTO public.saved_searches (user_id, keywords) VALUES ('22222222-2222-2222-2222-222222222222', 'تلاجة');
INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, status) VALUES
  ('5a5a0000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
   'ثلاجة توشيبا', 'نوفروست', 1, (SELECT min(id) FROM public.cities), 'pending');
SET LOCAL ROLE service_role;
SELECT public.moderate_ad('5a5a0000-0000-0000-0000-000000000004', '44444444-4444-4444-4444-444444444444', 'approved', NULL);
RESET ROLE;
SELECT is((SELECT count(*)::int FROM public.notifications_outbox
           WHERE user_id = '22222222-2222-2222-2222-222222222222' AND data ->> 'ad_id' = '5a5a0000-0000-0000-0000-000000000004'), 1,
  'a saved "تلاجة" alerts on an ad saying ثلاجة');

-- Adding a synonym is data only, stored normalised.
INSERT INTO public.search_synonyms (group_id, term) VALUES ((SELECT group_id FROM public.search_synonyms WHERE term = 'جوال'), 'سمارت فون');
SELECT is((SELECT count(*)::int FROM public.search_synonyms WHERE term = 'سمارت فون'), 1, 'new synonyms are inserted as data');
SET LOCAL ROLE anon;
SELECT throws_ok($$ SELECT 1 FROM public.search_synonyms $$, '42501', NULL, 'clients cannot read or change the synonym list');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
