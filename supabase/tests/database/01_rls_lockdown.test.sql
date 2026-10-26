-- (أ) Client lockdown: RLS on every table, no client EXECUTE on privileged RPCs,
-- no client writes to role / verification / balance / payment / KYC state,
-- phone and email hidden from everyone except the owner.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(40);

-- ── Fixtures (superuser) ──────────────────────────────────────────
INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.local', '+201000000002', '{}', 'authenticated', 'authenticated');

-- Fixture ads are inserted with triggers off: the legacy watchlist trigger calls
-- net.http_post, which fails until the notifications_outbox replacement lands.
SET LOCAL session_replication_role = replica;
INSERT INTO public.ads (id, user_id, category_id, title, description, city_id, status) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
   (SELECT id FROM public.categories WHERE slug = 'cars'), 'B active ad', 'desc',
   (SELECT min(id) FROM public.cities), 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222',
   (SELECT id FROM public.categories WHERE slug = 'cars'), 'B pending ad', 'desc',
   (SELECT min(id) FROM public.cities), 'pending');
SET LOCAL session_replication_role = origin;

INSERT INTO public.user_verifications (id, user_id, type, status, expires_at) VALUES
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'national_id', 'pending', now() + interval '30 days');

-- ── Catalog-level checks ──────────────────────────────────────────
SELECT is(
  (SELECT count(*)::int FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity
      AND c.relname <> 'spatial_ref_sys'),
  0, 'RLS is enabled on every public table (except PostGIS spatial_ref_sys)');

SELECT is(
  (SELECT count(*)::int FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('moderate_ad', 'moderate_kyc', 'handle_report', 'create_ad_transaction')
      AND (has_function_privilege('anon', p.oid, 'EXECUTE')
           OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))),
  0, 'anon/authenticated cannot EXECUTE moderation or create_ad_transaction RPCs');

SELECT is(
  (SELECT count(*)::int FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prosecdef
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
      AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) cfg WHERE cfg LIKE 'search_path=%')),
  0, 'every SECURITY DEFINER function in public pins search_path');

SELECT hasnt_trigger('public', 'user_verifications', 'trg_mock_face_verification',
  'mock KYC auto-approval trigger is gone');

-- ── anon ──────────────────────────────────────────────────────────
SET LOCAL ROLE anon;
SELECT throws_ok($$ SELECT phone FROM public.users $$, '42501', NULL, 'anon cannot read users.phone');
SELECT throws_ok($$ SELECT email FROM public.users $$, '42501', NULL, 'anon cannot read users.email');
SELECT lives_ok($$ SELECT id, full_name, avatar_url, trust_score, is_id_verified FROM public.users $$,
  'anon can read public profile columns');
SELECT isnt_empty($$ SELECT id FROM public.categories $$, 'anon can read categories');
SELECT throws_ok($$ INSERT INTO public.subscription_plans (name, name_ar, price_monthly) VALUES ('x','x',1) $$,
  '42501', NULL, 'anon cannot insert subscription_plans');
SELECT throws_ok($$ UPDATE public.app_configs SET value = '0' $$, '42501', NULL, 'anon cannot update app_configs');
SELECT throws_ok($$ UPDATE public.category_fields SET label_ar = 'x' $$, '42501', NULL, 'anon cannot update category_fields');
SELECT throws_ok($$ SELECT public.moderate_ad('aaaaaaaa-0000-0000-0000-000000000002',
                     '11111111-1111-1111-1111-111111111111', 'approved', NULL) $$,
  '42501', NULL, 'anon cannot call moderate_ad');
SELECT throws_ok($$ SELECT public.get_ad_contact('aaaaaaaa-0000-0000-0000-000000000001', 'phone') $$,
  '42501', NULL, 'anon cannot call get_ad_contact');
SELECT throws_ok($$ INSERT INTO public.users (id) VALUES ('22222222-2222-2222-2222-222222222222') $$,
  '42501', NULL, 'anon cannot insert users');
RESET ROLE;

-- ── authenticated user A ─────────────────────────────────────────
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT phone FROM public.users WHERE id = '22222222-2222-2222-2222-222222222222' $$,
  '42501', NULL, 'A cannot read B phone');
SELECT is((SELECT phone FROM public.get_my_profile()), '+201000000001', 'A reads own phone via get_my_profile()');
SELECT is((SELECT email FROM public.get_my_profile())::text, 'a@test.local', 'A reads own email via get_my_profile()');

SELECT lives_ok($$ UPDATE public.users SET full_name = 'A renamed', bio = 'hi' WHERE id = auth.uid() $$,
  'A can update own full_name/bio');
SELECT throws_ok($$ UPDATE public.users SET user_type = 'admin' WHERE id = auth.uid() $$,
  '42501', NULL, 'A cannot change own user_type');
SELECT throws_ok($$ UPDATE public.users SET is_id_verified = true WHERE id = auth.uid() $$,
  '42501', NULL, 'A cannot set own is_id_verified');
SELECT throws_ok($$ UPDATE public.users SET trust_score = 100 WHERE id = auth.uid() $$,
  '42501', NULL, 'A cannot set own trust_score');
SELECT throws_ok($$ UPDATE public.users SET status = 'active' WHERE id = auth.uid() $$,
  '42501', NULL, 'A cannot set own status');
SELECT lives_ok($$ UPDATE public.users SET full_name = 'hacked'
                   WHERE id = '22222222-2222-2222-2222-222222222222' $$,
  'A update on B profile runs (RLS filters it; checked below)');

SELECT throws_ok($$ UPDATE public.user_credits SET balance = 999999 WHERE user_id = auth.uid() $$,
  '42501', NULL, 'A cannot change own credit balance');
SELECT lives_ok($$ SELECT balance FROM public.user_credits WHERE user_id = auth.uid() $$,
  'A can read own credit balance');
SELECT throws_ok($$ INSERT INTO public.user_subscriptions (user_id, plan_id, expires_at)
                    VALUES (auth.uid(), (SELECT min(id) FROM public.subscription_plans), now() + interval '30 days') $$,
  '42501', NULL, 'A cannot grant self a subscription');
SELECT throws_ok($$ INSERT INTO public.transactions (user_id, type, amount, payment_method, payment_gateway, status)
                    VALUES (auth.uid(), 'ad_boost', 1, 'card', 'paymob', 'completed') $$,
  '42501', NULL, 'A cannot insert transactions');
SELECT throws_ok($$ INSERT INTO public.ad_boosts (ad_id, user_id, boost_type, expires_at)
                    VALUES ('aaaaaaaa-0000-0000-0000-000000000001', auth.uid(), 'featured', now() + interval '365 days') $$,
  '42501', NULL, 'A cannot insert ad_boosts');

SELECT throws_ok($$ INSERT INTO public.user_verifications (user_id, type, status, expires_at)
                    VALUES (auth.uid(), 'national_id', 'approved', now() + interval '1 day') $$,
  '42501', NULL, 'A cannot insert a KYC row (approved or otherwise)');
SELECT throws_ok($$ UPDATE public.user_verifications SET status = 'approved' WHERE user_id = auth.uid() $$,
  '42501', NULL, 'A cannot change own KYC status');
SELECT throws_ok($$ SELECT public.moderate_kyc('cccccccc-0000-0000-0000-000000000001',
                     '11111111-1111-1111-1111-111111111111', 'approved', NULL) $$,
  '42501', NULL, 'A cannot call moderate_kyc');
SELECT throws_ok($$ SELECT public.create_ad_transaction('22222222-2222-2222-2222-222222222222', 'draft-x',
                     (SELECT id FROM public.categories WHERE slug = 'cars'), 'spoof', 'spoof', 'offering', 1, 'fixed',
                     (SELECT min(id) FROM public.cities), NULL, NULL, NULL, 'low', 'x', 2::smallint, '[]'::jsonb, '[]'::jsonb) $$,
  '42501', NULL, 'A cannot call create_ad_transaction');

SELECT throws_ok($$ INSERT INTO public.contact_logs (ad_id, user_id, contact_type)
                    VALUES ('aaaaaaaa-0000-0000-0000-000000000001', auth.uid(), 'phone') $$,
  '42501', NULL, 'A cannot write contact_logs directly');
SELECT is((public.get_ad_contact('aaaaaaaa-0000-0000-0000-000000000001', 'whatsapp') ->> 'phone'),
  '+201000000002', 'A gets seller phone for an active ad via get_ad_contact');
SELECT is((SELECT count(*)::int FROM public.contact_logs
            WHERE user_id = auth.uid() AND ad_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  1, 'get_ad_contact logged exactly one contact');
SELECT throws_ok($$ SELECT public.get_ad_contact('aaaaaaaa-0000-0000-0000-000000000002', 'phone') $$,
  'P0002', NULL, 'get_ad_contact refuses non-active ads');

RESET ROLE;

SELECT isnt((SELECT full_name FROM public.users WHERE id = '22222222-2222-2222-2222-222222222222')::text,
  'hacked', 'B profile was not changed by A');
-- Trust-score triggers update other users' rows, which clients can no longer
-- write; they must run as owner.
SELECT is(
  (SELECT count(*)::int FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname IN ('update_trust_score', 'refresh_user_trust_score')
      AND NOT p.prosecdef),
  0, 'trust-score trigger functions run as SECURITY DEFINER');

-- ── service_role keeps full access (Edge Functions, admin panel) ──
SET LOCAL ROLE service_role;
SELECT lives_ok($$ UPDATE public.users SET user_type = 'moderator'
                   WHERE id = '22222222-2222-2222-2222-222222222222' $$,
  'service_role can still change user_type');
SELECT lives_ok($$ SELECT phone, email FROM public.users $$, 'service_role can read phone/email');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
