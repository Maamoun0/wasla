-- N17: the moderator's rejection reason is stored on the request and its
-- owner (only) can read it in the app.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(6);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.local', '+201000000002', '{}', 'authenticated', 'authenticated'),
  ('44444444-4444-4444-4444-444444444444', 'mod@test.local', '+201000000004', '{}', 'authenticated', 'authenticated');
UPDATE public.users SET user_type = 'moderator' WHERE id = '44444444-4444-4444-4444-444444444444';

INSERT INTO public.user_verifications (id, user_id, type, status, expires_at) VALUES
  ('eeeeeeee-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'national_id', 'pending', now() + interval '30 days'),
  ('eeeeeeee-0000-0000-0000-00000000000b', '22222222-2222-2222-2222-222222222222', 'national_id', 'pending', now() + interval '30 days');

SET LOCAL ROLE service_role;
SELECT public.moderate_kyc('eeeeeeee-0000-0000-0000-00000000000a', '44444444-4444-4444-4444-444444444444',
                           'rejected', '  صورة الخلفية غير واضحة  ');
SELECT public.moderate_kyc('eeeeeeee-0000-0000-0000-00000000000b', '44444444-4444-4444-4444-444444444444',
                           'approved', 'ignored on approval');
RESET ROLE;

SELECT is((SELECT rejection_reason FROM public.user_verifications WHERE id = 'eeeeeeee-0000-0000-0000-00000000000a'),
  'صورة الخلفية غير واضحة', 'a rejection stores the trimmed reason');
SELECT is((SELECT rejection_reason FROM public.user_verifications WHERE id = 'eeeeeeee-0000-0000-0000-00000000000b'),
  NULL, 'an approval stores no reason');

UPDATE public.user_verifications SET status = 'pending', rejection_reason = NULL WHERE id = 'eeeeeeee-0000-0000-0000-00000000000a';
SET LOCAL ROLE service_role;
SELECT public.moderate_kyc('eeeeeeee-0000-0000-0000-00000000000a', '44444444-4444-4444-4444-444444444444',
                           'rejected', repeat('x', 800));
RESET ROLE;
SELECT is((SELECT char_length(rejection_reason) FROM public.user_verifications WHERE id = 'eeeeeeee-0000-0000-0000-00000000000a'),
  500, 'an over-long reason is cut to 500 characters instead of failing the decision');

SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT is((SELECT char_length(rejection_reason) FROM public.user_verifications WHERE user_id = auth.uid()), 500,
  'the owner reads the reason');
SELECT is((SELECT count(*)::int FROM public.user_verifications WHERE user_id <> auth.uid()), 0,
  'other users'' requests stay invisible');
SELECT throws_ok($$ UPDATE public.user_verifications SET rejection_reason = 'x' WHERE user_id = auth.uid() $$,
  '42501', NULL, 'users cannot write the reason');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
