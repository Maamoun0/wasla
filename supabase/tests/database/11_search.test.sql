-- Ad search (FR-2.2 / FR-2.3): Arabic-normalised text search with prefix and
-- typo tolerance, plus the feed filters, through search_ads().
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(17);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated');

INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, ad_type, is_featured, status, created_at)
SELECT v.id::uuid, '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = v.slug),
       v.title, v.descr, v.price, (SELECT id FROM public.cities ORDER BY id OFFSET v.city_off LIMIT 1),
       v.ad_type::public.ad_type_enum, v.featured, v.status::public.ad_status_enum, now() - v.age
FROM (VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'cars',     'تويوتا كورولا 2019 فبريكا',  'حالة ممتازة',          350000, 0, 'offering', false, 'active',  interval '1 day'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'apt-rent', 'شقه للإيجار في المعادي',     'ثلاث غرف وصالة',       9000,   1, 'offering', true,  'active',  interval '2 days'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'land',     'أرض زراعية للبيع',           'مساحة كبيرة',          900000, 0, 'offering', false, 'active',  interval '3 days'),
  ('aaaaaaaa-0000-0000-0000-000000000004', 'cars',     'تويوتا ياريس',               'مطلوب بحالة جيدة',     150000, 1, 'seeking',  false, 'active',  interval '4 days'),
  ('aaaaaaaa-0000-0000-0000-000000000005', 'cars',     'تويوتا لاند كروزر',          'إعلان قيد المراجعة',   900000, 0, 'offering', false, 'pending', interval '1 hour')
) AS v(id, slug, title, descr, price, city_off, ad_type, featured, status, age);

SELECT has_function('public', 'search_ads', 'search_ads() exists');

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);

SELECT set_eq($$ SELECT title::text FROM public.search_ads(p_query := 'تويوتا') $$,
  ARRAY['تويوتا ياريس', 'تويوتا كورولا 2019 فبريكا'], 'keyword finds matching active ads only');
SELECT results_eq($$ SELECT title::text FROM public.search_ads(p_query := 'كورو') $$,
  ARRAY['تويوتا كورولا 2019 فبريكا'], 'word prefixes match while typing');
SELECT results_eq($$ SELECT title::text FROM public.search_ads(p_query := 'تويتا كورولا') $$,
  ARRAY['تويوتا كورولا 2019 فبريكا'], 'a common misspelling still matches');
SELECT results_eq($$ SELECT title::text FROM public.search_ads(p_query := 'شقة') $$,
  ARRAY['شقه للإيجار في المعادي'], 'ة and ه are treated alike');
SELECT results_eq($$ SELECT title::text FROM public.search_ads(p_query := 'ارض') $$,
  ARRAY['أرض زراعية للبيع'], 'أ and ا are treated alike');
SELECT results_eq($$ SELECT title::text FROM public.search_ads(p_query := 'غرف') $$,
  ARRAY['شقه للإيجار في المعادي'], 'description is searched too');
SELECT is_empty($$ SELECT * FROM public.search_ads(p_query := 'لابتوب') $$, 'no false positives for unrelated words');

SELECT is((SELECT count(*)::int FROM public.search_ads()), 4, 'empty query lists every active ad');
SELECT is((SELECT title::text FROM public.search_ads() LIMIT 1), 'شقه للإيجار في المعادي', 'featured ads come first');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_category_id := (SELECT id FROM public.categories WHERE slug = 'vehicles'))), 2,
  'a main category includes its subcategories');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_category_id := (SELECT id FROM public.categories WHERE slug = 'cars'))), 2,
  'a subcategory filter works');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_min_price := 100000, p_max_price := 400000)), 2, 'price range filter');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_ad_type := 'seeking')), 1, 'ad type filter (wanted / offered)');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_city_id := (SELECT id FROM public.cities ORDER BY id LIMIT 1))), 2, 'city filter');
SELECT is((SELECT count(*)::int FROM public.search_ads(p_featured_only := true)), 1, 'featured-only filter');
SELECT is((SELECT array_agg(t) FROM (SELECT title::text AS t FROM public.search_ads(p_limit := 2, p_offset := 2)) x),
  ARRAY['أرض زراعية للبيع', 'تويوتا ياريس'], 'pagination (limit/offset) after featured-first ordering');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
