-- N14: the national ID is never stored. Only the last 4 digits and an HMAC
-- (computed by submit-kyc-request with a secret the database never sees);
-- the same ID cannot be live on two accounts.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(14);

-- ── Nothing can hold the full number ──────────────────────────────
SELECT hasnt_column('public', 'user_verifications', 'national_id', 'the plaintext national_id column is gone');
SELECT is(
  (SELECT array_agg(table_name || '.' || column_name ORDER BY column_name)::text
   FROM information_schema.columns
   WHERE table_schema = 'public' AND column_name ILIKE '%national%'),
  '{user_verifications.national_id_hmac,user_verifications.national_id_last4}',
  'the only national-ID columns in public are the last 4 digits and the HMAC');

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.local', '+201000000002', '{}', 'authenticated', 'authenticated');

CREATE TEMP TABLE ids (k text PRIMARY KEY, v text);
INSERT INTO ids VALUES ('h', repeat('ab', 32)), ('other', repeat('cd', 32));
GRANT SELECT ON ids TO authenticated;

SELECT throws_ok(
  $$ INSERT INTO public.user_verifications (user_id, type, status, expires_at, national_id_last4, national_id_hmac)
     VALUES ('11111111-1111-1111-1111-111111111111', 'national_id', 'pending', now() + interval '30 days',
             '29001011234567', (SELECT v FROM ids WHERE k = 'h')) $$,
  '23514', NULL, 'national_id_last4 cannot hold the full number');
SELECT throws_ok(
  $$ INSERT INTO public.user_verifications (user_id, type, status, expires_at, national_id_last4, national_id_hmac)
     VALUES ('11111111-1111-1111-1111-111111111111', 'national_id', 'pending', now() + interval '30 days',
             '4567', '29001011234567') $$,
  '23514', NULL, 'national_id_hmac only accepts a 64-hex digest');
SELECT throws_ok(
  $$ INSERT INTO public.user_verifications (user_id, type, status, expires_at, national_id_last4)
     VALUES ('11111111-1111-1111-1111-111111111111', 'national_id', 'pending', now() + interval '30 days', '4567') $$,
  '23514', NULL, 'last 4 digits and HMAC are stored together');

-- ── Duplicates ────────────────────────────────────────────────────
INSERT INTO public.user_verifications (id, user_id, type, status, expires_at, national_id_last4, national_id_hmac)
VALUES ('dddddddd-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'national_id', 'pending',
        now() + interval '30 days', '4567', (SELECT v FROM ids WHERE k = 'h'));

SELECT throws_ok(
  $$ INSERT INTO public.user_verifications (user_id, type, status, expires_at, national_id_last4, national_id_hmac)
     VALUES ('22222222-2222-2222-2222-222222222222', 'national_id', 'pending', now() + interval '30 days',
             '4567', (SELECT v FROM ids WHERE k = 'h')) $$,
  '23505', NULL, 'the same ID cannot be pending on another account');

UPDATE public.user_verifications SET status = 'approved' WHERE id = 'dddddddd-0000-0000-0000-00000000000a';
SELECT throws_ok(
  $$ INSERT INTO public.user_verifications (user_id, type, status, expires_at, national_id_last4, national_id_hmac)
     VALUES ('22222222-2222-2222-2222-222222222222', 'national_id', 'pending', now() + interval '30 days',
             '4567', (SELECT v FROM ids WHERE k = 'h')) $$,
  '23505', NULL, 'nor once it is approved on the first account');
SELECT lives_ok(
  $$ INSERT INTO public.user_verifications (user_id, type, status, expires_at, national_id_last4, national_id_hmac)
     VALUES ('22222222-2222-2222-2222-222222222222', 'national_id', 'pending', now() + interval '30 days',
             '1234', (SELECT v FROM ids WHERE k = 'other')) $$,
  'a different ID is accepted');

UPDATE public.user_verifications SET status = 'rejected' WHERE id = 'dddddddd-0000-0000-0000-00000000000a';
SELECT lives_ok(
  $$ INSERT INTO public.user_verifications (user_id, type, status, expires_at, national_id_last4, national_id_hmac)
     VALUES ('11111111-1111-1111-1111-111111111111', 'national_id', 'pending', now() + interval '30 days',
             '4567', (SELECT v FROM ids WHERE k = 'h')) $$,
  'after a rejection the same user can resubmit the same ID');
SELECT throws_ok(
  $$ INSERT INTO public.user_verifications (user_id, type, status, expires_at, national_id_last4, national_id_hmac)
     VALUES ('22222222-2222-2222-2222-222222222222', 'national_id', 'pending', now() + interval '30 days',
             '4567', (SELECT v FROM ids WHERE k = 'h')) $$,
  '23505', NULL, 'and that resubmission blocks other accounts again');

-- ── Clients ───────────────────────────────────────────────────────
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$ SELECT national_id_hmac FROM public.user_verifications $$, '42501', NULL,
  'users cannot read the HMAC, even on their own request');
SELECT throws_ok($$ SELECT code_hash FROM public.user_verifications $$, '42501', NULL,
  'nor the OTP code hash');
SELECT is((SELECT count(*)::int FROM public.user_verifications WHERE national_id_last4 = '4567'), 2,
  'users still read their own requests (status, last 4 digits)');
SELECT is((SELECT count(*)::int FROM public.user_verifications WHERE user_id <> auth.uid()), 0,
  'and only their own');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
