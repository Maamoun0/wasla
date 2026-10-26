-- Account deletion (security plan §6): the request immediately hides the
-- account, its ads and blocks sign-in; 30 days later the account is purged.
-- Purge deletes the auth user (here directly, as the Auth API does), which
-- must succeed for any user, including staff with audit history.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(26);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.local', '+201000000002', '{}', 'authenticated', 'authenticated');

INSERT INTO public.ads (id, user_id, category_id, title, description, city_id, status) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   (SELECT id FROM public.categories WHERE slug = 'plumbing'), 'إعلان أ', 'desc', (SELECT min(id) FROM public.cities), 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222',
   (SELECT id FROM public.categories WHERE slug = 'plumbing'), 'إعلان ب', 'desc', (SELECT min(id) FROM public.cities), 'active');
INSERT INTO public.push_tokens (user_id, token, platform) VALUES ('11111111-1111-1111-1111-111111111111', 'tok-a', 'android');
INSERT INTO public.saved_searches (user_id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'بحث');
-- A has also acted as staff: audit and moderation history reference A.
INSERT INTO public.audit_logs (actor_id, action, target_type) VALUES ('11111111-1111-1111-1111-111111111111', 'test_deletion_marker', 'ad');
INSERT INTO public.ad_moderation_log (ad_id, moderator_id, action, previous_status, new_status)
VALUES ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'approved', 'pending', 'active');
INSERT INTO public.transactions (user_id, type, amount, payment_method, payment_gateway, status)
VALUES ('11111111-1111-1111-1111-111111111111', 'ad_boost', 60, 'card', 'paymob', 'completed');
INSERT INTO public.contact_logs (ad_id, user_id, contact_type)
VALUES ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'phone');

-- ── Request (as A) ────────────────────────────────────────────────
SET LOCAL ROLE anon;
SELECT throws_ok($$ SELECT public.request_account_deletion('x') $$, '42501', NULL, 'anon cannot request a deletion');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
CREATE TEMP TABLE req ON COMMIT DROP AS SELECT * FROM public.request_account_deletion('لم أعد أحتاج الحساب');
GRANT SELECT ON req TO PUBLIC;  -- test bookkeeping, read later as service_role
SELECT is((SELECT status FROM req), 'pending', 'request is pending');
SELECT ok((SELECT scheduled_for BETWEEN now() + interval '30 days' - interval '1 minute' AND now() + interval '30 days' + interval '1 minute' FROM req),
  'purge is scheduled 30 days out');
SELECT is((SELECT id FROM public.request_account_deletion(NULL)), (SELECT id FROM req), 'asking again returns the same request');
SELECT is((SELECT count(*)::int FROM public.account_deletion_requests), 1, 'A can read own request');
SELECT throws_ok($$ INSERT INTO public.account_deletion_requests (user_id) VALUES (auth.uid()) $$, '42501', NULL,
  'requests cannot be written directly');
SELECT throws_ok($$ UPDATE public.account_deletion_requests SET scheduled_for = now() $$, '42501', NULL,
  'the schedule cannot be changed by the user');
RESET ROLE;

-- ── Immediate effects ─────────────────────────────────────────────
SELECT is((SELECT status::text FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'), 'deleted', 'profile marked deleted');
SELECT ok((SELECT deleted_at IS NOT NULL FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'), 'profile soft-deleted');
SELECT is((SELECT status::text FROM public.ads WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001'), 'deleted', 'ads taken down');
SELECT is((SELECT count(*)::int FROM public.push_tokens WHERE user_id = '11111111-1111-1111-1111-111111111111'), 0, 'push tokens removed');
SELECT is((SELECT bool_or(is_active) FROM public.saved_searches WHERE user_id = '11111111-1111-1111-1111-111111111111'), false,
  'saved searches stopped');
SELECT ok((SELECT banned_until > now() + interval '50 years' FROM auth.users WHERE id = '11111111-1111-1111-1111-111111111111'),
  'sign-in is blocked');

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true), set_config('request.jwt.claim.sub', '', true);
SELECT is_empty($$ SELECT id FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111' $$, 'profile hidden from others');
SELECT is_empty($$ SELECT id FROM public.ads WHERE user_id = '11111111-1111-1111-1111-111111111111' $$, 'ads hidden from others');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true),
       set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT is_empty($$ SELECT id FROM public.account_deletion_requests $$, 'B cannot see A''s request');
SELECT throws_ok($$ SELECT * FROM public.list_due_account_deletions(10) $$, '42501', NULL, 'clients cannot list due deletions');
RESET ROLE;

-- ── Purge (as the purge-deleted-accounts function) ────────────────
SET LOCAL ROLE service_role;
SELECT is_empty($$ SELECT * FROM public.list_due_account_deletions(10) $$, 'nothing is due before 30 days');
RESET ROLE;
UPDATE public.account_deletion_requests SET scheduled_for = now() - interval '1 minute';
SET LOCAL ROLE service_role;
SELECT is((SELECT user_id FROM public.list_due_account_deletions(10)), '11111111-1111-1111-1111-111111111111'::uuid,
  'due account is listed');
RESET ROLE;

SELECT lives_ok($$ DELETE FROM auth.users WHERE id = '11111111-1111-1111-1111-111111111111' $$,
  'the auth user (and everything owned) can be deleted, staff history included');

SET LOCAL ROLE service_role;
SELECT lives_ok($$ SELECT public.complete_account_deletion((SELECT id FROM req)) $$, 'request is closed');
RESET ROLE;

SELECT is((SELECT count(*)::int FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'), 0, 'profile purged');
SELECT is((SELECT count(*)::int FROM public.ads WHERE user_id = '11111111-1111-1111-1111-111111111111'), 0, 'ads purged');
SELECT is((SELECT count(*)::int FROM public.audit_logs WHERE action = 'test_deletion_marker' AND actor_id IS NULL), 1,
  'audit history is kept, anonymised');
SELECT is((SELECT count(*)::int FROM public.ad_moderation_log WHERE ad_id = 'aaaaaaaa-0000-0000-0000-000000000002' AND moderator_id IS NULL), 1,
  'moderation history is kept, anonymised');
SELECT is((SELECT status FROM public.account_deletion_requests WHERE id = (SELECT id FROM req)), 'completed',
  'request recorded as completed');

SELECT * FROM finish();
ROLLBACK;
