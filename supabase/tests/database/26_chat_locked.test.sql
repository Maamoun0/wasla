-- N20: chat is deferred to 1.1; its tables are closed to every client role.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(6);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated');

SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$ SELECT 1 FROM public.conversations $$, '42501', NULL, 'users cannot read conversations');
SELECT throws_ok($$ SELECT 1 FROM public.messages $$, '42501', NULL, 'users cannot read messages');
SELECT throws_ok($$ INSERT INTO public.messages DEFAULT VALUES $$, '42501', NULL, 'users cannot send messages');
RESET ROLE;
SET LOCAL ROLE anon;
SELECT throws_ok($$ SELECT 1 FROM public.conversations $$, '42501', NULL, 'guests cannot read conversations');
SELECT throws_ok($$ SELECT 1 FROM public.messages $$, '42501', NULL, 'guests cannot read messages');
RESET ROLE;
SELECT has_table('public', 'messages', 'the tables stay for 1.1');

SELECT * FROM finish();
ROLLBACK;
