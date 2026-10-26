-- (ب) Payments: prices live on the server, fulfilment is atomic and idempotent,
-- the paid amount must match, and clients cannot reach any of it.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(26);

-- ── Fixtures ──────────────────────────────────────────────────────
INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated');

-- Ads inserted with triggers off: the legacy watchlist trigger needs pg_net.
SET LOCAL session_replication_role = replica;
INSERT INTO public.ads (id, user_id, category_id, title, description, city_id, status) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   (SELECT id FROM public.categories WHERE slug = 'cars'), 'A ad', 'desc', (SELECT min(id) FROM public.cities), 'active');
SET LOCAL session_replication_role = origin;

INSERT INTO public.payment_packages (id, kind, name_ar, price_egp, credit_amount)
VALUES ('test_credit_100', 'credit_purchase', 'رصيد 100', 95, 100);

-- One pending transaction per scenario, priced from its package.
INSERT INTO public.transactions (id, user_id, type, reference_id, amount, payment_method, payment_gateway, status, package_id)
SELECT v.id::uuid, '11111111-1111-1111-1111-111111111111', v.kind::public.transaction_type_enum, v.ref::uuid,
       p.price_egp, 'card', 'paymob', 'pending', p.id
FROM (VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', 'ad_boost',        'aaaaaaaa-0000-0000-0000-000000000001', 'boost_featured_7d'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'ad_boost',        'aaaaaaaa-0000-0000-0000-000000000001', 'boost_urgent_7d'),
  ('bbbbbbbb-0000-0000-0000-000000000003', 'subscription',    NULL,                                   'sub_premium_monthly'),
  ('bbbbbbbb-0000-0000-0000-000000000004', 'credit_purchase', NULL,                                   'test_credit_100'),
  ('bbbbbbbb-0000-0000-0000-000000000005', 'ad_boost',        'aaaaaaaa-0000-0000-0000-000000000001', 'boost_featured_3d')
) AS v(id, kind, ref, pkg)
JOIN public.payment_packages p ON p.id = v.pkg;

-- ── Price table ───────────────────────────────────────────────────
SELECT is((SELECT price_egp FROM public.payment_packages WHERE id = 'boost_featured_7d'), 60.00::numeric,
  'boost prices are seeded from app_configs');
SELECT is((SELECT price_egp FROM public.payment_packages WHERE id = 'sub_premium_monthly'), 199.00::numeric,
  'subscription prices are seeded from subscription_plans.price_monthly');
SELECT is((SELECT count(*)::int FROM public.transactions WHERE id::text LIKE 'bbbbbbbb-%'), 5,
  'all scenario transactions were created from packages');

-- ── Clients ───────────────────────────────────────────────────────
SET LOCAL ROLE anon;
SELECT isnt_empty($$ SELECT id, price_egp FROM public.payment_packages $$, 'anon can read active packages');
SELECT throws_ok($$ UPDATE public.payment_packages SET price_egp = 1 $$, '42501', NULL, 'anon cannot change prices');
SELECT throws_ok($$ SELECT public.fulfill_payment('bbbbbbbb-0000-0000-0000-000000000001', true, 6000, 'EGP', '{}') $$,
  '42501', NULL, 'anon cannot call fulfill_payment');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$ INSERT INTO public.payment_packages (id, kind, name_ar, price_egp, boost_type) VALUES ('x', 'ad_boost', 'x', 1, 'featured') $$,
  '42501', NULL, 'A cannot create packages');
SELECT throws_ok($$ SELECT public.fulfill_payment('bbbbbbbb-0000-0000-0000-000000000001', true, 6000, 'EGP', '{}') $$,
  '42501', NULL, 'A cannot call fulfill_payment');
SELECT throws_ok($$ UPDATE public.ads SET is_featured = true WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  '42501', NULL, 'A cannot set is_featured on own ad');
SELECT throws_ok($$ UPDATE public.ads SET refreshed_at = now() WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  '42501', NULL, 'A cannot bump own ad without paying');
SELECT lives_ok($$ UPDATE public.ads SET status = 'paused' WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'A can still pause own ad');
RESET ROLE;
SET LOCAL session_replication_role = replica;
UPDATE public.ads SET status = 'active' WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001';
SET LOCAL session_replication_role = origin;

-- ── Fulfilment (as service_role, like the webhook) ───────────────
SET LOCAL ROLE service_role;

SELECT is(public.fulfill_payment('bbbbbbbb-0000-0000-0000-000000000001', true, 100, 'EGP', '{"id":1}'),
  'amount_mismatch', 'underpaid callback is rejected');
SELECT is((SELECT status::text FROM public.transactions WHERE id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'failed', 'underpaid transaction is marked failed');
SELECT is((SELECT is_featured FROM public.ads WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  false, 'underpaid boost was not activated');
SELECT is(public.fulfill_payment('bbbbbbbb-0000-0000-0000-000000000001', true, 6000, 'EGP', '{"id":1}'),
  'already_processed', 'a later correct callback cannot revive a failed transaction');

SELECT is(public.fulfill_payment('bbbbbbbb-0000-0000-0000-000000000005', true, 3000, 'USD', '{"id":5}'),
  'amount_mismatch', 'wrong currency is rejected');

SELECT is(public.fulfill_payment('bbbbbbbb-0000-0000-0000-000000000002', true, 4000, 'EGP', '{"id":2}'),
  'completed', 'correct urgent boost callback completes');
SELECT is(public.fulfill_payment('bbbbbbbb-0000-0000-0000-000000000002', true, 4000, 'EGP', '{"id":2}'),
  'already_processed', 'duplicate callback is ignored');
SELECT is((SELECT count(*)::int FROM public.ad_boosts WHERE ad_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  1, 'duplicate callback did not create a second boost');
SELECT is((SELECT is_urgent FROM public.ads WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  true, 'urgent flag set on the ad');
SELECT ok((SELECT expires_at BETWEEN now() + interval '7 days' - interval '1 minute' AND now() + interval '7 days' + interval '1 minute'
           FROM public.ad_boosts WHERE ad_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'boost duration comes from the package (7 days)');

SELECT is(public.fulfill_payment('bbbbbbbb-0000-0000-0000-000000000003', true, 19900, 'EGP', '{"id":3}'),
  'completed', 'subscription callback completes');
SELECT is((SELECT sp.name::text FROM public.user_subscriptions us JOIN public.subscription_plans sp ON sp.id = us.plan_id
           WHERE us.user_id = '11111111-1111-1111-1111-111111111111' AND us.status = 'active'),
  'premium', 'premium subscription is active');

SELECT is(public.fulfill_payment('bbbbbbbb-0000-0000-0000-000000000004', true, 9500, 'EGP', '{"id":4}'),
  'completed', 'credit purchase completes');
SELECT is((SELECT balance FROM public.user_credits WHERE user_id = '11111111-1111-1111-1111-111111111111'),
  100.00::numeric, 'credits added (previously credit purchases granted nothing)');

SELECT is(public.fulfill_payment('00000000-0000-0000-0000-000000000000', true, 1, 'EGP', '{}'),
  'not_found', 'unknown transaction is reported, not created');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
