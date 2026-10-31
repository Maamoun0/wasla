-- N25: no duplicate cities or districts, and the same name written
-- differently cannot be added twice.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(8);

SELECT is((SELECT count(*)::int FROM (SELECT 1 FROM public.cities GROUP BY governorate_id, public.place_name_key(name_ar) HAVING count(*) > 1) d),
  0, 'no city appears twice in a governorate');
SELECT is((SELECT count(*)::int FROM (SELECT 1 FROM public.districts GROUP BY city_id, public.place_name_key(name_ar) HAVING count(*) > 1) d),
  0, 'no district appears twice in a city');
SELECT is((SELECT count(*)::int FROM public.cities WHERE name_ar = 'سموحة'), 1, 'Smouha (25 and 54 in the old seed) is listed once');
SELECT is((SELECT count(*)::int FROM public.districts d LEFT JOIN public.cities c ON c.id = d.city_id WHERE c.id IS NULL), 0,
  'every district still points at an existing city');

SELECT throws_ok($$ INSERT INTO public.cities (governorate_id, name_ar, name_en) VALUES (2, '  سموحه ', 'dup') $$,
  '23505', NULL, 'the same city with other spacing or ه/ة is refused');
SELECT throws_ok($$ INSERT INTO public.cities (governorate_id, name_ar, name_en)
                   SELECT governorate_id, replace(name_ar, 'ا', 'أ'), 'dup' FROM public.cities WHERE name_ar LIKE '%ا%' LIMIT 1 $$,
  '23505', NULL, 'and with أ/ا variants');
SELECT lives_ok($$ INSERT INTO public.cities (governorate_id, name_ar, name_en) VALUES (1, 'مدينة اختبار جديدة', 'Test') $$,
  'a genuinely new city is accepted');
SELECT throws_ok($$ INSERT INTO public.districts (city_id, name_ar)
                   SELECT city_id, name_ar || ' ' FROM public.districts LIMIT 1 $$,
  '23505', NULL, 'a district cannot be added twice to its city');

SELECT * FROM finish();
ROLLBACK;
