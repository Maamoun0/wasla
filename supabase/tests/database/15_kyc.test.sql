-- KYC-01: approving sets the verified badge; identity documents are deleted
-- 7 days after approval and 30 days after rejection (appeal window), while
-- the decision record stays.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(18);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.local', '+201000000002', '{}', 'authenticated', 'authenticated'),
  ('44444444-4444-4444-4444-444444444444', 'mod@test.local', '+201000000004', '{}', 'authenticated', 'authenticated');
UPDATE public.users SET user_type = 'moderator' WHERE id = '44444444-4444-4444-4444-444444444444';

INSERT INTO public.user_verifications (id, user_id, type, status, expires_at, document_url, document_back_url) VALUES
  ('cccccccc-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'national_id', 'pending',
   now() + interval '30 days', '11111111-1111-1111-1111-111111111111/kyc/1/front.jpg', '11111111-1111-1111-1111-111111111111/kyc/1/back.jpg'),
  ('cccccccc-0000-0000-0000-00000000000b', '22222222-2222-2222-2222-222222222222', 'national_id', 'pending',
   now() + interval '30 days', '22222222-2222-2222-2222-222222222222/kyc/1/front.jpg', '22222222-2222-2222-2222-222222222222/kyc/1/back.jpg');

SET LOCAL ROLE service_role;
SELECT public.moderate_kyc('cccccccc-0000-0000-0000-00000000000a', '44444444-4444-4444-4444-444444444444', 'approved', NULL);
SELECT public.moderate_kyc('cccccccc-0000-0000-0000-00000000000b', '44444444-4444-4444-4444-444444444444', 'rejected', 'صورة غير واضحة');
RESET ROLE;

-- ── Badge ─────────────────────────────────────────────────────────
SELECT is((SELECT is_id_verified FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'), true,
  'approval sets is_id_verified (the ✓ badge)');
SELECT is((SELECT trust_score FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'), 30.00::numeric,
  'approval adds the 30 verification points of the trust formula (no ad-hoc override)');
SELECT is((SELECT is_id_verified FROM public.users WHERE id = '22222222-2222-2222-2222-222222222222'), false,
  'rejection leaves the user unverified');
SELECT ok((SELECT decided_at IS NOT NULL FROM public.user_verifications WHERE id = 'cccccccc-0000-0000-0000-00000000000b'),
  'the decision time is recorded for rejections too');

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);
SELECT is((SELECT is_id_verified FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'), true,
  'everyone sees the badge on the profile and ads');
RESET ROLE;

-- ── Document retention ────────────────────────────────────────────
SET LOCAL ROLE service_role;
SELECT is_empty($$ SELECT * FROM public.list_due_kyc_documents(10) $$, 'nothing is due right after the decisions');
RESET ROLE;

UPDATE public.user_verifications SET decided_at = now() - interval '6 days 23 hours' WHERE id = 'cccccccc-0000-0000-0000-00000000000a';
UPDATE public.user_verifications SET decided_at = now() - interval '29 days' WHERE id = 'cccccccc-0000-0000-0000-00000000000b';
SET LOCAL ROLE service_role;
SELECT is_empty($$ SELECT * FROM public.list_due_kyc_documents(10) $$,
  'not due before 7 days (approved) / 30 days (rejected)');
RESET ROLE;

UPDATE public.user_verifications SET decided_at = now() - interval '7 days 1 minute' WHERE id = 'cccccccc-0000-0000-0000-00000000000a';
SET LOCAL ROLE service_role;
SELECT results_eq($$ SELECT verification_id, paths FROM public.list_due_kyc_documents(10) $$,
  $$ VALUES ('cccccccc-0000-0000-0000-00000000000a'::uuid,
             ARRAY['11111111-1111-1111-1111-111111111111/kyc/1/front.jpg', '11111111-1111-1111-1111-111111111111/kyc/1/back.jpg']) $$,
  'approved documents are due after 7 days, with their storage paths');
RESET ROLE;

UPDATE public.user_verifications SET decided_at = now() - interval '30 days 1 minute' WHERE id = 'cccccccc-0000-0000-0000-00000000000b';
SET LOCAL ROLE service_role;
SELECT is((SELECT count(*)::int FROM public.list_due_kyc_documents(10)), 2, 'rejected documents are due after 30 days');
SELECT lives_ok($$ SELECT public.mark_kyc_documents_deleted('cccccccc-0000-0000-0000-00000000000a') $$, 'deletion is recorded');
RESET ROLE;

SELECT results_eq(
  $$ SELECT status::text, document_url, document_back_url, selfie_url FROM public.user_verifications
     WHERE id = 'cccccccc-0000-0000-0000-00000000000a' $$,
  $$ VALUES ('approved', NULL::text, NULL::text, NULL::text) $$,
  'the decision is kept, the document paths are cleared');
SELECT ok((SELECT documents_deleted_at IS NOT NULL FROM public.user_verifications WHERE id = 'cccccccc-0000-0000-0000-00000000000a'),
  'and when they were deleted');
SET LOCAL ROLE service_role;
SELECT is((SELECT count(*)::int FROM public.list_due_kyc_documents(10)), 1, 'deleted documents are not listed again');
RESET ROLE;
SELECT is((SELECT is_id_verified FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'), true,
  'the badge stays after the documents are deleted');

-- ── Clients ───────────────────────────────────────────────────────
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$ SELECT * FROM public.list_due_kyc_documents(10) $$, '42501', NULL, 'clients cannot list due documents');
SELECT throws_ok($$ SELECT public.mark_kyc_documents_deleted('cccccccc-0000-0000-0000-00000000000b') $$, '42501', NULL,
  'clients cannot mark documents deleted');
SELECT throws_ok($$ UPDATE public.users SET is_id_verified = true WHERE id = auth.uid() $$, '42501', NULL,
  'users still cannot verify themselves');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM cron.job WHERE jobname = 'purge-kyc-documents'), 1,
  'a daily job runs the purge');

SELECT * FROM finish();
ROLLBACK;
