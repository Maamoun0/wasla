-- 🟡3 (FR-1.3): profile setup saves the user's city; only on their own
-- profile, and only an existing city.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(4);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.local', '+201000000002', '{}', 'authenticated', 'authenticated');

CREATE TEMP TABLE c AS SELECT min(id) AS city FROM public.cities;
GRANT SELECT ON c TO authenticated;

SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT lives_ok($$ UPDATE public.users SET full_name = 'محمد', city_id = (SELECT city FROM c) WHERE id = auth.uid() $$,
  'the user saves name and city on their own profile');
SELECT throws_ok($$ UPDATE public.users SET city_id = 999999 WHERE id = auth.uid() $$, '23503', NULL,
  'a city that does not exist is refused');
UPDATE public.users SET city_id = (SELECT city FROM c) WHERE id = '22222222-2222-2222-2222-222222222222';
RESET ROLE;

SELECT is((SELECT city_id FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'), (SELECT city FROM c),
  'the city is stored');
SELECT is((SELECT city_id FROM public.users WHERE id = '22222222-2222-2222-2222-222222222222'), NULL,
  'another user''s city cannot be changed');

SELECT * FROM finish();
ROLLBACK;
