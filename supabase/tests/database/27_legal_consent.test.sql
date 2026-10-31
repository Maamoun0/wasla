-- N21: acceptance is recorded per document version, only for the current
-- versions, and only through accept_legal_documents.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(10);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated');

SELECT is((SELECT value ->> 'version' FROM public.app_configs WHERE key = 'legal_terms'), '0',
  'terms start at the placeholder version 0 (no reviewed text yet)');

SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT is(public.legal_status() ->> 'accepted', 'false', 'a new user has not accepted yet');
SELECT is(public.accept_legal_documents(0, 0) ->> 'success', 'true', 'accepting the shown versions is recorded');
SELECT is(public.legal_status() ->> 'accepted', 'true', 'and the status says so');
SELECT results_eq($$ SELECT policy_version::text FROM public.legal_acceptances WHERE user_id = auth.uid() ORDER BY 1 $$,
  $$ VALUES ('privacy:0'), ('terms:0') $$, 'one row per document and version');
SELECT throws_ok($$ INSERT INTO public.legal_acceptances (user_id, policy_version) VALUES (auth.uid(), 'terms:99') $$,
  '42501', NULL, 'acceptance cannot be written directly');
RESET ROLE;

-- Publishing reviewed terms = a new version: the user must accept again.
UPDATE public.app_configs SET value = jsonb_build_object('version', 1, 'url', NULL, 'body', 'نص مراجَع') WHERE key = 'legal_terms';
SET LOCAL ROLE authenticated;
SELECT is(public.legal_status() ->> 'accepted', 'false', 'a new terms version needs a new acceptance');
SELECT is(public.accept_legal_documents(0, 0) ->> 'error', 'stale_version', 'accepting an outdated version is refused');
SELECT is(public.accept_legal_documents(1, 0) ->> 'success', 'true', 'accepting the current one works');
RESET ROLE;

SET LOCAL ROLE anon;
SELECT throws_ok($$ SELECT 1 FROM public.legal_acceptances $$, '42501', NULL, 'guests cannot read acceptances');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
