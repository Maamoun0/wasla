-- Seller phone is revealed only to signed-in users, through
-- reveal_seller_phone(), which rate-limits per user and logs every request.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(20);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.local', '+201000000002', '{}', 'authenticated', 'authenticated');

INSERT INTO public.ads (id, user_id, category_id, title, description, city_id, status)
SELECT ('aaaaaaaa-0000-0000-0000-00000000000' || n)::uuid, '22222222-2222-2222-2222-222222222222',
       (SELECT id FROM public.categories WHERE slug = 'cars'), 'B ad ' || n, 'desc',
       (SELECT min(id) FROM public.cities), CASE WHEN n = 9 THEN 'pending' ELSE 'active' END::public.ad_status_enum
FROM generate_series(1, 9) AS n;

-- Tight limit for the test: 2 distinct ads per hour.
UPDATE public.app_configs SET value = '2' WHERE key = 'phone_reveal_limit_per_hour';

SELECT is((SELECT count(*)::int FROM pg_proc WHERE proname = 'get_ad_contact'), 0,
  'old get_ad_contact RPC is removed');

SET LOCAL ROLE anon;
SELECT throws_ok($$ SELECT public.reveal_seller_phone('aaaaaaaa-0000-0000-0000-000000000001') $$,
  '42501', NULL, 'anon cannot reveal a phone');
SELECT throws_ok($$ SELECT * FROM public.phone_reveal_log $$, '42501', NULL, 'anon cannot read the reveal log');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT is(public.reveal_seller_phone('aaaaaaaa-0000-0000-0000-000000000001') ->> 'phone', '+201000000002',
  'signed-in user gets the seller phone');
SELECT is(public.reveal_seller_phone('aaaaaaaa-0000-0000-0000-000000000001', 'whatsapp') ->> 'status', 'ok',
  'revealing the same ad again (WhatsApp) does not use more quota');
SELECT is(public.reveal_seller_phone('aaaaaaaa-0000-0000-0000-000000000002') ->> 'status', 'ok',
  'second distinct ad within the limit');
SELECT is(public.reveal_seller_phone('aaaaaaaa-0000-0000-0000-000000000003') ->> 'status', 'rate_limited',
  'third distinct ad in the hour is rate limited');
SELECT is(public.reveal_seller_phone('aaaaaaaa-0000-0000-0000-000000000003') -> 'phone', NULL,
  'a rate-limited response carries no phone');
SELECT ok((public.reveal_seller_phone('aaaaaaaa-0000-0000-0000-000000000004') ->> 'retry_after_seconds')::int > 0,
  'rate-limited response says when to retry');
SELECT is(public.reveal_seller_phone('aaaaaaaa-0000-0000-0000-000000000001') ->> 'phone', '+201000000002',
  'an already revealed ad stays available while limited');
SELECT is(public.reveal_seller_phone('aaaaaaaa-0000-0000-0000-000000000009') ->> 'status', 'not_available',
  'non-active ad is not revealed');
SELECT throws_ok($$ SELECT public.reveal_seller_phone('aaaaaaaa-0000-0000-0000-000000000001', 'sms') $$,
  '22023', NULL, 'unsupported contact type is rejected');

SELECT throws_ok($$ SELECT * FROM public.phone_reveal_log $$, '42501', NULL, 'users cannot read the reveal log');
SELECT throws_ok($$ INSERT INTO public.phone_reveal_log (user_id, ad_id, outcome) VALUES (auth.uid(), NULL, 'revealed') $$,
  '42501', NULL, 'users cannot write the reveal log');
SELECT throws_ok($$ DELETE FROM public.phone_reveal_log $$, '42501', NULL, 'users cannot erase the reveal log');
SELECT is((SELECT count(*)::int FROM public.contact_logs WHERE user_id = auth.uid()), 4,
  'each successful reveal is also a contact (analytics, review eligibility)');
RESET ROLE;

-- Every request is logged, including refusals.
SELECT is((SELECT count(*)::int FROM public.phone_reveal_log WHERE user_id = '11111111-1111-1111-1111-111111111111'),
  8, 'all 8 completed requests are in the log');
SELECT is((SELECT count(*)::int FROM public.phone_reveal_log
            WHERE user_id = '11111111-1111-1111-1111-111111111111' AND outcome = 'rate_limited'), 3,
  'rate-limited requests are logged');
SELECT is((SELECT count(*)::int FROM public.phone_reveal_log
            WHERE user_id = '11111111-1111-1111-1111-111111111111' AND outcome = 'not_available'), 1,
  'refusals for unavailable ads are logged');
SELECT is((SELECT count(DISTINCT ad_id)::int FROM public.phone_reveal_log
            WHERE user_id = '11111111-1111-1111-1111-111111111111' AND outcome = 'revealed'), 2,
  'only two distinct ads were ever revealed');

SELECT * FROM finish();
ROLLBACK;
