-- 🟡5 (FR-3.3): ads run for ad_expiry_days from approval, owners cannot
-- move the dates themselves, and renew_ad extends expired or expiring ads.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(15);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.local', '+201000000002', '{}', 'authenticated', 'authenticated'),
  ('44444444-4444-4444-4444-444444444444', 'mod@test.local', '+201000000004', '{}', 'authenticated', 'authenticated');
UPDATE public.users SET user_type = 'moderator' WHERE id = '44444444-4444-4444-4444-444444444444';

-- Waited 10 days and 40 days for review (expires_at as the old default left it).
INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, status, created_at, expires_at)
SELECT v.id::uuid, '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
       'إعلان', 'desc', 1000, (SELECT min(id) FROM public.cities), 'pending', now() - v.age, now() - v.age + interval '30 days'
FROM (VALUES ('dddd0000-0000-0000-0000-000000000001', interval '10 days'),
             ('dddd0000-0000-0000-0000-000000000002', interval '40 days')) AS v(id, age);

SET LOCAL ROLE service_role;
SELECT public.moderate_ad('dddd0000-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 'approved', NULL);
SELECT public.moderate_ad('dddd0000-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', 'approved', NULL);
RESET ROLE;

SELECT ok((SELECT expires_at BETWEEN now() + interval '30 days' - interval '1 minute' AND now() + interval '30 days' + interval '1 minute'
           FROM public.ads WHERE id = 'dddd0000-0000-0000-0000-000000000001'),
  'an ad that waited 10 days for review still gets the full 30 days from approval');
SELECT ok((SELECT published_at >= now() - interval '1 minute' FROM public.ads WHERE id = 'dddd0000-0000-0000-0000-000000000001'),
  'published_at is the approval time');

-- The hourly expire-ads job.
UPDATE public.ads SET status = 'expired' WHERE status = 'active' AND expires_at < now() AND deleted_at IS NULL;
SELECT is((SELECT status::text FROM public.ads WHERE id = 'dddd0000-0000-0000-0000-000000000002'), 'active',
  'an ad that waited over 30 days is not expired right after approval');

UPDATE public.app_configs SET value = '14' WHERE key = 'ad_expiry_days';
INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, status)
VALUES ('dddd0000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
        (SELECT id FROM public.categories WHERE slug = 'cars'), 'إعلان', 'desc', 1000, (SELECT min(id) FROM public.cities), 'pending');
SET LOCAL ROLE service_role;
SELECT public.moderate_ad('dddd0000-0000-0000-0000-000000000003', '44444444-4444-4444-4444-444444444444', 'approved', NULL);
RESET ROLE;
SELECT ok((SELECT expires_at < now() + interval '15 days' AND expires_at > now() + interval '13 days'
           FROM public.ads WHERE id = 'dddd0000-0000-0000-0000-000000000003'),
  'the lifetime comes from app_configs.ad_expiry_days');
UPDATE public.app_configs SET value = '30' WHERE key = 'ad_expiry_days';

-- Ad 1: 2 days left. Ad 2: 20 days left. Ad 3: expired.
UPDATE public.ads SET expires_at = now() + interval '2 days' WHERE id = 'dddd0000-0000-0000-0000-000000000001';
UPDATE public.ads SET expires_at = now() + interval '20 days' WHERE id = 'dddd0000-0000-0000-0000-000000000002';
UPDATE public.ads SET status = 'expired', expires_at = now() - interval '1 day' WHERE id = 'dddd0000-0000-0000-0000-000000000003';
CREATE TEMP TABLE before AS SELECT id, published_at FROM public.ads WHERE id = 'dddd0000-0000-0000-0000-000000000003';
CREATE TEMP TABLE notif_before AS SELECT count(*) AS n FROM public.notifications WHERE user_id = '11111111-1111-1111-1111-111111111111';
GRANT SELECT ON before, notif_before TO authenticated;

SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$ UPDATE public.ads SET expires_at = now() + interval '10 years' WHERE id = 'dddd0000-0000-0000-0000-000000000002' $$,
  '42501', NULL, 'owners cannot move expires_at themselves');
SELECT throws_ok($$ UPDATE public.ads SET published_at = now() - interval '1 year' WHERE id = 'dddd0000-0000-0000-0000-000000000002' $$,
  '42501', NULL, 'nor published_at');
SELECT is(public.renew_ad('dddd0000-0000-0000-0000-000000000002') ->> 'error', 'not_renewable',
  'an ad with 20 days left cannot be renewed yet');
SELECT is(public.renew_ad('dddd0000-0000-0000-0000-000000000001') ->> 'success', 'true', 'an ad in its last 3 days is renewed');
SELECT is(public.renew_ad('dddd0000-0000-0000-0000-000000000003') ->> 'success', 'true', 'an expired ad is renewed');
RESET ROLE;

SELECT ok((SELECT expires_at > now() + interval '29 days' FROM public.ads WHERE id = 'dddd0000-0000-0000-0000-000000000001'),
  'renewal gives a fresh 30 days');
SELECT is((SELECT status::text FROM public.ads WHERE id = 'dddd0000-0000-0000-0000-000000000003'), 'active',
  'the expired ad is active again');
SELECT is((SELECT published_at FROM public.ads WHERE id = 'dddd0000-0000-0000-0000-000000000003'), (SELECT published_at FROM before),
  'renewal does not make the ad look newly published');
SELECT is((SELECT count(*) FROM public.notifications WHERE user_id = '11111111-1111-1111-1111-111111111111'), (SELECT n FROM notif_before),
  'renewal does not send another "approved" notification');

SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true),
       set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT is(public.renew_ad('dddd0000-0000-0000-0000-000000000001') ->> 'error', 'not_found', 'users cannot renew someone else''s ad');
RESET ROLE;
SET LOCAL ROLE anon;
SELECT throws_ok($$ SELECT public.renew_ad('dddd0000-0000-0000-0000-000000000001') $$, '42501', NULL, 'guests cannot call renew_ad');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
