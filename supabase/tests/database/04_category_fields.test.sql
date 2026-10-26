-- Post Ad Wizard dynamic fields: every subcategory the wizard can pick has
-- fields, fetched through get_category_fields() (parent fields + its own).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(14);

SELECT has_function('public', 'get_category_fields', ARRAY['integer'], 'get_category_fields(int) exists');

SELECT is(
  (SELECT count(*)::int FROM public.categories c
    WHERE c.level = 2 AND c.is_active
      AND NOT EXISTS (SELECT 1 FROM public.get_category_fields(c.id))),
  0, 'every active subcategory has at least one dynamic field');

SELECT is(
  (SELECT count(*)::int FROM public.categories c
    WHERE c.level = 2 AND c.is_active
      AND NOT EXISTS (SELECT 1 FROM public.category_fields f WHERE f.category_id = c.id)),
  0, 'every active subcategory also has fields of its own');

SELECT ok((SELECT count(*) FROM public.category_fields WHERE category_id = (SELECT id FROM public.categories WHERE slug = 'services')) > 0,
  'Services (خدمات) has shared fields');
SELECT ok((SELECT count(*) FROM public.category_fields WHERE category_id = (SELECT id FROM public.categories WHERE slug = 'goods')) > 0,
  'Goods (سلع) has shared fields');

SELECT is(
  (SELECT count(*)::int FROM public.category_fields
    WHERE field_type = 'select'
      AND (options IS NULL OR jsonb_typeof(options) <> 'array' OR jsonb_array_length(options) = 0)),
  0, 'every select field has a non-empty options array');

SELECT is(
  (SELECT count(*)::int FROM (
     SELECT c.id, f.field_name FROM public.categories c, LATERAL public.get_category_fields(c.id) f
     WHERE c.level = 2 GROUP BY 1, 2 HAVING count(*) > 1) d),
  0, 'no subcategory gets the same field twice');

SELECT ok(
  (SELECT array_agg(field_name::text) FROM public.get_category_fields((SELECT id FROM public.categories WHERE slug = 'apt-rent')))
    @> ARRAY['area_sqm', 'rooms'],
  'apartment-for-rent gets the parent field (area_sqm) and its own (rooms)');

SELECT is(
  (SELECT field_name::text FROM public.get_category_fields((SELECT id FROM public.categories WHERE slug = 'apt-rent')) LIMIT 1),
  'area_sqm', 'parent fields come first');

SELECT ok(
  NOT EXISTS (SELECT 1 FROM public.get_category_fields((SELECT id FROM public.categories WHERE slug = 'motorcycles')) f
              WHERE f.options ? 'تويوتا'),
  'motorcycles no longer show car brands');

SELECT ok(
  EXISTS (SELECT 1 FROM public.get_category_fields((SELECT id FROM public.categories WHERE slug = 'cars')) f
          WHERE f.field_name = 'brand' AND f.options ? 'تويوتا'),
  'cars still offer car brands');

SET LOCAL ROLE anon;
SELECT isnt_empty($$ SELECT * FROM public.get_category_fields((SELECT id FROM public.categories WHERE slug = 'plumbing')) $$,
  'anon (wizard before sign-in) can read fields');
SELECT is_empty($$ SELECT * FROM public.get_category_fields(-1) $$, 'unknown category returns no fields');
SELECT throws_ok($$ DELETE FROM public.category_fields $$, '42501', NULL, 'clients cannot change field definitions');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
