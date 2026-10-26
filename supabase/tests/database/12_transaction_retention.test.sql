-- Financial records outlive the account (retention decision, docs/
-- wasla_security_privacy_plan.md §6): when a user is purged, their payment
-- transactions stay with amount, currency, package, status, dates and the
-- Paymob ids, and nothing that links them to the person.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(14);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'mona@test.local', '+201011112222', '{}', 'authenticated', 'authenticated');
UPDATE public.users SET full_name = 'منى أحمد' WHERE id = '11111111-1111-1111-1111-111111111111';

INSERT INTO public.ads (id, user_id, category_id, title, description, city_id, status) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   (SELECT id FROM public.categories WHERE slug = 'cars'), 'سيارة', 'desc', (SELECT min(id) FROM public.cities), 'active');

-- One record in the current format, one with everything the legacy code stored.
INSERT INTO public.transactions (id, user_id, type, reference_id, reference_type, amount, currency, payment_method,
                                 payment_gateway, gateway_transaction_id, status, package_id, metadata, created_at, completed_at)
VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'ad_boost',
   'aaaaaaaa-0000-0000-0000-000000000001', 'ad', 60, 'EGP', 'card', 'paymob', '88776655', 'completed', 'boost_featured_7d',
   '{"gateway": {"id": 192837465, "order_id": "88776655", "amount_cents": 6000, "currency": "EGP", "success": true,
                 "pending": false, "source_type": "card", "created_at": "2026-10-20T10:00:00"}}',
   '2026-10-20 10:00+00', '2026-10-20 10:01+00'),
  ('bbbbbbbb-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'subscription',
   NULL, NULL, 199, 'EGP', 'card', 'paymob', '99887766', 'failed', 'sub_premium_monthly',
   '{"failure_reason": "gateway_init_failed",
     "billing": {"firstName": "منى", "lastName": "أحمد", "userEmail": "mona@test.local", "userPhone": "+201011112222"},
     "paymob_payment_key": "ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5",
     "boost_package_key": "x",
     "paymob_callback_payload": {"id": 5, "billing_data": {"email": "mona@test.local", "phone_number": "+201011112222",
                                 "first_name": "منى"}, "source_data": {"pan": "2346", "type": "card"}},
     "gateway": {"id": 5, "order_id": "99887766", "amount_cents": 19900, "currency": "EGP", "success": false,
                 "pending": false, "source_type": "card", "created_at": "2026-10-21T10:00:00",
                 "billing_data": {"email": "mona@test.local"}}}',
   '2026-10-21 10:00+00', '2026-10-21 10:05+00');

-- Purge, as the Auth API does.
DELETE FROM auth.users WHERE id = '11111111-1111-1111-1111-111111111111';

SELECT is((SELECT count(*)::int FROM public.transactions WHERE id::text LIKE 'bbbbbbbb-%'), 2, 'both transactions survive the purge');
SELECT is((SELECT count(*)::int FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'), 0, 'the person is gone');

SELECT results_eq(
  $$ SELECT amount, currency::text, package_id, status::text, type::text, created_at, completed_at, gateway_transaction_id::text
     FROM public.transactions WHERE id = 'bbbbbbbb-0000-0000-0000-000000000001' $$,
  $$ VALUES (60.00::numeric, 'EGP', 'boost_featured_7d', 'completed', 'ad_boost',
             '2026-10-20 10:00+00'::timestamptz, '2026-10-20 10:01+00'::timestamptz, '88776655') $$,
  'amount, currency, package, status, type, dates and Paymob order id are kept');
SELECT is((SELECT metadata #>> '{gateway,id}' FROM public.transactions WHERE id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  '192837465', 'the Paymob transaction id is kept');
SELECT is((SELECT metadata ->> 'failure_reason' FROM public.transactions WHERE id = 'bbbbbbbb-0000-0000-0000-000000000002'),
  'gateway_init_failed', 'the failure reason is kept');

SELECT is((SELECT count(*)::int FROM public.transactions WHERE id::text LIKE 'bbbbbbbb-%' AND user_id IS NOT NULL), 0, 'user_id is cleared');
SELECT is((SELECT count(*)::int FROM public.transactions WHERE id::text LIKE 'bbbbbbbb-%' AND reference_id IS NOT NULL), 0,
  'the reference to the person''s ad is cleared');
SELECT is(
  (SELECT count(*)::int FROM public.transactions t, jsonb_object_keys(t.metadata) k
    WHERE t.id::text LIKE 'bbbbbbbb-%' AND k NOT IN ('gateway', 'failure_reason', 'amount_mismatch')),
  0, 'only non-personal metadata keys remain');
SELECT is(
  (SELECT count(*)::int FROM public.transactions t, jsonb_object_keys(coalesce(t.metadata -> 'gateway', '{}')) k
    WHERE t.id::text LIKE 'bbbbbbbb-%'
      AND k NOT IN ('id', 'order_id', 'amount_cents', 'currency', 'success', 'pending', 'source_type', 'created_at')),
  0, 'only non-personal gateway fields remain');
SELECT is((SELECT count(*)::int FROM public.transactions
            WHERE id::text LIKE 'bbbbbbbb-%'
              AND (metadata::text ILIKE '%mona@test.local%' OR metadata::text LIKE '%01011112222%'
                   OR metadata::text LIKE '%منى%' OR metadata::text LIKE '%2346%')),
  0, 'no email, phone, name or card digits anywhere in the record');

-- Structural guarantees for any future purge.
SELECT is(
  (SELECT count(*)::int FROM pg_constraint c
    WHERE c.contype = 'f' AND c.conrelid = 'public.transactions'::regclass
      AND c.confrelid IN ('public.users'::regclass, 'auth.users'::regclass) AND c.confdeltype <> 'n'),
  0, 'every link from transactions to a user is ON DELETE SET NULL');
SELECT col_is_null('public', 'transactions', 'user_id', 'transactions.user_id is nullable');

SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true),
       set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT is_empty($$ SELECT id FROM public.transactions WHERE id::text LIKE 'bbbbbbbb-%' $$,
  'anonymised records are not visible to app users');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT is((SELECT count(*)::int FROM public.transactions WHERE id::text LIKE 'bbbbbbbb-%'), 2,
  'finance (service role / admin) still sees them');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
