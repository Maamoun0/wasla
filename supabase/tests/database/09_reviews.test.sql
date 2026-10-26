-- Reviews (FR-4.4): a buyer who contacted a seller can rate them 1-5 once per
-- ad; the seller may reply once; the seller's trust_score follows the single
-- formula used by the app (30 verified + 40 x avg/5 + min(count, 20)
-- + min(months, 10)).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(13);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'buyer@test.local',  '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'seller@test.local', '+201000000002', '{}', 'authenticated', 'authenticated'),
  ('33333333-3333-3333-3333-333333333333', 'other@test.local',  '+201000000003', '{}', 'authenticated', 'authenticated');

INSERT INTO public.ads (id, user_id, category_id, title, description, city_id, status) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
   (SELECT id FROM public.categories WHERE slug = 'plumbing'), 'سباك', 'desc', (SELECT min(id) FROM public.cities), 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333',
   (SELECT id FROM public.categories WHERE slug = 'plumbing'), 'سباك آخر', 'desc', (SELECT min(id) FROM public.cities), 'active');

SELECT is((SELECT count(*)::int FROM pg_trigger WHERE tgrelid = 'public.reviews'::regclass AND NOT tgisinternal
            AND tgfoid IN (SELECT oid FROM pg_proc WHERE proname IN ('update_trust_score', 'refresh_user_trust_score'))),
  1, 'exactly one trust-score trigger on reviews');

-- "other" has contacted the seller too, so only RLS can stop an impersonated review.
INSERT INTO public.contact_logs (ad_id, user_id, contact_type)
VALUES ('aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'phone');

-- Buyer contacts the seller (makes them eligible to review).
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.reveal_seller_phone('aaaaaaaa-0000-0000-0000-000000000001');

SELECT lives_ok($$ INSERT INTO public.reviews (reviewer_id, reviewed_user_id, ad_id, rating, comment)
                   VALUES (auth.uid(), '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-0000-0000-0000-000000000001', 5, 'ممتاز') $$,
  'buyer who contacted the seller can review');
SELECT throws_ok($$ INSERT INTO public.reviews (reviewer_id, reviewed_user_id, ad_id, rating)
                    VALUES (auth.uid(), '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-0000-0000-0000-000000000001', 1) $$,
  '23505', NULL, 'only one review per buyer, seller and ad');
SELECT throws_ok($$ INSERT INTO public.reviews (reviewer_id, reviewed_user_id, ad_id, rating)
                    VALUES (auth.uid(), '33333333-3333-3333-3333-333333333333', 'aaaaaaaa-0000-0000-0000-000000000003', 1) $$,
  'P0001', NULL, 'no review without a prior contact');
SELECT throws_ok($$ INSERT INTO public.reviews (reviewer_id, reviewed_user_id, rating)
                    VALUES (auth.uid(), auth.uid(), 5) $$,
  NULL, NULL, 'no self review');
SELECT throws_ok($$ INSERT INTO public.reviews (reviewer_id, reviewed_user_id, ad_id, rating)
                    VALUES ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-0000-0000-0000-000000000001', 5) $$,
  '42501', NULL, 'cannot review on behalf of someone else');
RESET ROLE;

SELECT is((SELECT trust_score FROM public.users WHERE id = '22222222-2222-2222-2222-222222222222'), 41.00::numeric,
  'seller trust_score = 40 x 5/5 + 1 review (unverified, new account)');

-- Seller replies once.
SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true),
       set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT lives_ok($$ INSERT INTO public.review_responses (review_id, user_id, response)
                   SELECT id, auth.uid(), 'شكراً لك' FROM public.reviews WHERE reviewed_user_id = auth.uid() $$,
  'seller can reply to a review about them');
SELECT throws_ok($$ INSERT INTO public.review_responses (review_id, user_id, response)
                    SELECT id, auth.uid(), 'رد ثانٍ' FROM public.reviews WHERE reviewed_user_id = auth.uid() $$,
  '23505', NULL, 'only one reply per review');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true),
       set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$ INSERT INTO public.review_responses (review_id, user_id, response)
                    SELECT id, auth.uid(), 'تدخل' FROM public.reviews WHERE reviewed_user_id = '22222222-2222-2222-2222-222222222222' $$,
  '42501', NULL, 'others cannot reply to a review about someone else');
SELECT isnt_empty($$ SELECT id FROM public.reviews WHERE reviewed_user_id = '22222222-2222-2222-2222-222222222222' $$,
  'reviews are public');
RESET ROLE;

-- Moderator hides the review: score is recalculated.
UPDATE public.reviews SET status = 'hidden' WHERE reviewed_user_id = '22222222-2222-2222-2222-222222222222';
SELECT is((SELECT trust_score FROM public.users WHERE id = '22222222-2222-2222-2222-222222222222'), 0.00::numeric,
  'hiding the only review resets the score');

-- Verification adds 30.
UPDATE public.users SET is_id_verified = true WHERE id = '22222222-2222-2222-2222-222222222222';
SELECT is((SELECT trust_score FROM public.users WHERE id = '22222222-2222-2222-2222-222222222222'), 30.00::numeric,
  'a verified seller gets 30 points');

SELECT * FROM finish();
ROLLBACK;
