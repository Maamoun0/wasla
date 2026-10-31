-- 🟡10 (FR-6.2): banning hides the user's ads and ends their sessions at
-- once; their still-valid access token cannot post or reveal numbers.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(13);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'seller@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'buyer@test.local', '+201000000002', '{}', 'authenticated', 'authenticated'),
  ('44444444-4444-4444-4444-444444444444', 'mod@test.local', '+201000000004', '{}', 'authenticated', 'authenticated');
UPDATE public.users SET user_type = 'moderator' WHERE id = '44444444-4444-4444-4444-444444444444';

INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, status) VALUES
  ('abab0000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'),
   'إعلان المحظور', 'd', 1, (SELECT min(id) FROM public.cities), 'active');
INSERT INTO auth.sessions (id, user_id, created_at, updated_at) VALUES
  ('5e550000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', now(), now());
INSERT INTO auth.refresh_tokens (token, user_id, session_id, revoked, created_at, updated_at) VALUES
  ('refresh-test-token', '11111111-1111-1111-1111-111111111111', '5e550000-0000-0000-0000-000000000001', false, now(), now());

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);
SELECT is((SELECT count(*)::int FROM public.ads WHERE id = 'abab0000-0000-0000-0000-000000000001'), 1, 'before the ban the ad is public');
RESET ROLE;

-- The admin panel bans the seller.
UPDATE public.users SET status = 'banned' WHERE id = '11111111-1111-1111-1111-111111111111';

SELECT is((SELECT is_hidden FROM public.ads WHERE id = 'abab0000-0000-0000-0000-000000000001'), true, 'the ban hides the user''s ads');
SELECT is((SELECT count(*)::int FROM auth.sessions WHERE user_id = '11111111-1111-1111-1111-111111111111'), 0, 'their sessions end at once');
SELECT is((SELECT count(*)::int FROM auth.refresh_tokens WHERE user_id = '11111111-1111-1111-1111-111111111111'), 0,
  'and no new access token can be issued');

SET LOCAL ROLE anon;
SELECT is((SELECT count(*)::int FROM public.ads WHERE id = 'abab0000-0000-0000-0000-000000000001'), 0, 'guests no longer see the ad');
SELECT is((SELECT count(*)::int FROM public.search_ads() WHERE id = 'abab0000-0000-0000-0000-000000000001'), 0, 'nor find it in search');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true),
       set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT is(public.reveal_seller_phone('abab0000-0000-0000-0000-000000000001', 'phone') ->> 'status', 'not_available',
  'buyers cannot reveal a banned seller''s number');
RESET ROLE;

-- The banned seller still holds an access token for up to an hour.
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$ SELECT public.reveal_seller_phone('abab0000-0000-0000-0000-000000000001', 'phone') $$, '42501', 'account blocked',
  'a banned user''s remaining token cannot reveal numbers');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT is(public.posting_block('11111111-1111-1111-1111-111111111111', 1), 'account_blocked', 'nor post');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true),
       set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT is((SELECT count(*)::int FROM public.ads WHERE id = 'abab0000-0000-0000-0000-000000000001'), 1, 'moderators still see it');
RESET ROLE;

UPDATE public.users SET status = 'active' WHERE id = '11111111-1111-1111-1111-111111111111';
SELECT is((SELECT is_hidden FROM public.ads WHERE id = 'abab0000-0000-0000-0000-000000000001'), false, 'reactivation shows the ads again');
SET LOCAL ROLE service_role;
SELECT is(public.posting_block('11111111-1111-1111-1111-111111111111', 1), NULL, 'and the user can post again');
RESET ROLE;
SET LOCAL ROLE anon;
SELECT is((SELECT count(*)::int FROM public.search_ads() WHERE id = 'abab0000-0000-0000-0000-000000000001'), 1, 'the ad is searchable again');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
