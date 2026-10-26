-- N12: a reviewer may edit only the text and rating of their own review.
-- Status and every other column are for staff (service role); a review a
-- moderator hid stays hidden whatever the reviewer does.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(12);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'buyer@test.local',  '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'seller@test.local', '+201000000002', '{}', 'authenticated', 'authenticated'),
  ('33333333-3333-3333-3333-333333333333', 'other@test.local',  '+201000000003', '{}', 'authenticated', 'authenticated');

INSERT INTO public.ads (id, user_id, category_id, title, description, city_id, status) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
   (SELECT id FROM public.categories WHERE slug = 'plumbing'), 'سباك', 'desc', (SELECT min(id) FROM public.cities), 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222',
   (SELECT id FROM public.categories WHERE slug = 'plumbing'), 'سباك 2', 'desc', (SELECT min(id) FROM public.cities), 'active');
INSERT INTO public.contact_logs (ad_id, user_id, contact_type) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'phone'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'phone');

INSERT INTO public.reviews (id, reviewer_id, reviewed_user_id, ad_id, rating, comment, status) VALUES
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
   'aaaaaaaa-0000-0000-0000-000000000001', 1, 'سيئ جداً', 'active'),
  ('dddddddd-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
   'aaaaaaaa-0000-0000-0000-000000000002', 1, 'شتائم', 'active');
-- A moderator hides the second review.
UPDATE public.reviews SET status = 'hidden' WHERE id = 'dddddddd-0000-0000-0000-000000000002';

SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

-- An UPDATE without a filter does not read any column, so only the UPDATE
-- policy (reviewer_id = auth.uid()) applies — the hidden row is reachable.
SELECT throws_ok($$ UPDATE public.reviews SET status = 'active' $$, '42501', NULL,
  'reviewer cannot restore own reviews, even with an unfiltered update');
SELECT throws_ok($$ UPDATE public.reviews SET reviewed_user_id = '33333333-3333-3333-3333-333333333333'
                    WHERE id = 'dddddddd-0000-0000-0000-000000000001' $$,
  '42501', NULL, 'reviewer cannot move a review onto another person');
SELECT throws_ok($$ UPDATE public.reviews SET status = 'deleted' WHERE id = 'dddddddd-0000-0000-0000-000000000001' $$,
  '42501', NULL, 'reviewer cannot change the status column');
SELECT throws_ok($$ UPDATE public.reviews SET created_at = now() - interval '1 year' WHERE id = 'dddddddd-0000-0000-0000-000000000001' $$,
  '42501', NULL, 'reviewer cannot backdate a review');
SELECT throws_ok($$ UPDATE public.reviews SET ad_id = NULL WHERE id = 'dddddddd-0000-0000-0000-000000000001' $$,
  '42501', NULL, 'reviewer cannot detach a review from its ad');
SELECT lives_ok($$ UPDATE public.reviews SET rating = 4, comment = 'اتحلت المشكلة' WHERE id = 'dddddddd-0000-0000-0000-000000000001' $$,
  'reviewer can edit rating and text of an active review');
SELECT lives_ok($$ UPDATE public.reviews SET rating = 5, comment = 'تعديل' $$,
  'an unfiltered edit of rating/text runs (checked below)');
RESET ROLE;

SELECT is((SELECT status::text FROM public.reviews WHERE id = 'dddddddd-0000-0000-0000-000000000002'), 'hidden',
  'the hidden review stays hidden');
SELECT is((SELECT comment FROM public.reviews WHERE id = 'dddddddd-0000-0000-0000-000000000002'), 'شتائم',
  'the hidden review cannot be edited by the reviewer');
SELECT is((SELECT reviewed_user_id FROM public.reviews WHERE id = 'dddddddd-0000-0000-0000-000000000001'),
  '22222222-2222-2222-2222-222222222222'::uuid, 'the active review still targets the original seller');
SELECT is((SELECT rating FROM public.reviews WHERE id = 'dddddddd-0000-0000-0000-000000000001'), 5::smallint,
  'rating edits on the active review applied');

SET LOCAL ROLE service_role;
SELECT lives_ok($$ UPDATE public.reviews SET status = 'active' WHERE id = 'dddddddd-0000-0000-0000-000000000002' $$,
  'staff (service role) can restore a hidden review');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
