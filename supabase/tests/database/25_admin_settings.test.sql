-- 🟡9: the admin switches stored in app_configs are enforced.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(12);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'new@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'trusted@test.local', '+201000000002', '{}', 'authenticated', 'authenticated');
UPDATE public.users SET trust_score = 30 WHERE id = '22222222-2222-2222-2222-222222222222';

CREATE FUNCTION pg_temp.new_ad(p_user uuid, p_draft text) RETURNS uuid LANGUAGE sql AS $$
  SELECT public.create_ad_transaction(
    p_user, p_draft, (SELECT id FROM public.categories WHERE slug = 'cars'), 'إعلان', 'وصف الإعلان',
    'offering', 1000, 'fixed', (SELECT min(id) FROM public.cities), NULL, NULL, NULL,
    'low', 'ok', 2::smallint, '[]'::jsonb, '[]'::jsonb);
$$;

SELECT is((SELECT count(*)::int FROM public.app_configs
           WHERE key IN ('maintenance_mode', 'ai_moderation_enabled', 'enable_kyc_verification', 'enable_boost_feature', 'min_trust_score_to_post')),
  5, 'all five switches exist');
SELECT is(public.app_setting_int('min_trust_score_to_post', -1), 0, 'the default minimum score blocks nobody');
SELECT is(public.posting_block('11111111-1111-1111-1111-111111111111', 1), NULL, 'with the defaults a new user can post');

-- Values as the admin panel saves them (jsonb booleans and numbers).
UPDATE public.app_configs SET value = 'true'::jsonb WHERE key = 'maintenance_mode';
SELECT is(public.posting_block('22222222-2222-2222-2222-222222222222', 1), 'maintenance', 'maintenance blocks posting');
SET LOCAL ROLE service_role;
SELECT throws_ok($$ SELECT pg_temp.new_ad('22222222-2222-2222-2222-222222222222', 'm1') $$, 'P0001', 'maintenance',
  'even a direct create_ad_transaction call is refused');
RESET ROLE;
INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, status, expires_at)
VALUES ('ffff0000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', (SELECT id FROM public.categories WHERE slug = 'cars'),
        'منتهي', 'd', 1, (SELECT min(id) FROM public.cities), 'expired', now() - interval '1 day');
SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true),
       set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT is(public.renew_ad('ffff0000-0000-0000-0000-000000000001') ->> 'error', 'maintenance', 'and renewals wait too');
RESET ROLE;
UPDATE public.app_configs SET value = 'false'::jsonb WHERE key = 'maintenance_mode';

UPDATE public.app_configs SET value = '25'::jsonb WHERE key = 'min_trust_score_to_post';
SELECT is(public.posting_block('11111111-1111-1111-1111-111111111111', 1), 'trust_score_too_low', 'below the minimum score: refused');
SELECT is(public.posting_block('22222222-2222-2222-2222-222222222222', 1), NULL, 'at or above it: allowed');
SET LOCAL ROLE service_role;
SELECT throws_ok($$ SELECT pg_temp.new_ad('11111111-1111-1111-1111-111111111111', 't1') $$, 'P0001', 'trust_score_too_low',
  'create_ad_transaction applies the minimum too');
SELECT lives_ok($$ SELECT pg_temp.new_ad('22222222-2222-2222-2222-222222222222', 't2') $$, 'a trusted user posts');
RESET ROLE;

-- Reading rules: a string value from an older panel still counts; missing keys use the default.
UPDATE public.app_configs SET value = '"true"'::jsonb WHERE key = 'enable_boost_feature';
SELECT is(public.app_setting_bool('enable_boost_feature', false), true, 'a "true" string is read as true');
SELECT is(public.app_setting_bool('no_such_key', true), true, 'a missing key falls back to its default');

SELECT * FROM finish();
ROLLBACK;
