BEGIN;
SELECT plan(9);

-- docs/ALGORITHMS.md §2/§9: five sellers each praised by ten accounts two
-- days old, with no ads, whose only contact came hours before the review.
-- One ring seller ranked 1st in trust. Here: seller S gets four such
-- reviews; buyer H is a real, older buyer; A and B review each other.
INSERT INTO auth.users (id, phone)
SELECT ('00000000-0000-0000-0000-0000000004' || lpad(i::text, 2, '0'))::uuid, '2010999004' || lpad(i::text, 2, '0')
FROM generate_series(1, 9) i;
-- 01 = S (seller), 02..05 = ring accounts, 06 = H (real buyer), 07 = A, 08 = B.
UPDATE public.users SET created_at = now() - interval '200 days'
WHERE id IN ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000406',
             '00000000-0000-0000-0000-000000000407', '00000000-0000-0000-0000-000000000408');
UPDATE public.users SET created_at = now() - interval '1 day'
WHERE id IN (SELECT ('00000000-0000-0000-0000-0000000004' || lpad(i::text, 2, '0'))::uuid FROM generate_series(2, 5) i);

INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, status) VALUES
  ('00000000-0000-0000-0000-00000000a401', '00000000-0000-0000-0000-000000000401', 29, 'إعلان البائع', 'وصف إعلان البائع س', 100, 1, 'active'),
  ('00000000-0000-0000-0000-00000000a406', '00000000-0000-0000-0000-000000000406', 29, 'إعلان المشتري', 'المشتري الحقيقي عنده إعلان', 100, 1, 'active'),
  ('00000000-0000-0000-0000-00000000a407', '00000000-0000-0000-0000-000000000407', 29, 'إعلان أ', 'وصف إعلان أ للاختبار', 100, 1, 'active'),
  ('00000000-0000-0000-0000-00000000a408', '00000000-0000-0000-0000-000000000408', 29, 'إعلان ب', 'وصف إعلان ب للاختبار', 100, 1, 'active');

-- Ring: contact two hours ago, review now.
INSERT INTO public.contact_logs (ad_id, user_id, contact_type, created_at)
SELECT '00000000-0000-0000-0000-00000000a401', ('00000000-0000-0000-0000-0000000004' || lpad(i::text, 2, '0'))::uuid,
       'whatsapp', now() - interval '2 hours'
FROM generate_series(2, 5) i;
-- Real buyer: contacted three days ago.
INSERT INTO public.contact_logs (ad_id, user_id, contact_type, created_at) VALUES
  ('00000000-0000-0000-0000-00000000a401', '00000000-0000-0000-0000-000000000406', 'phone', now() - interval '3 days'),
  ('00000000-0000-0000-0000-00000000a408', '00000000-0000-0000-0000-000000000407', 'phone', now() - interval '3 days'),
  ('00000000-0000-0000-0000-00000000a407', '00000000-0000-0000-0000-000000000408', 'phone', now() - interval '3 days');

INSERT INTO public.reviews (reviewer_id, reviewed_user_id, ad_id, rating)
SELECT ('00000000-0000-0000-0000-0000000004' || lpad(i::text, 2, '0'))::uuid, '00000000-0000-0000-0000-000000000401',
       '00000000-0000-0000-0000-00000000a401', 5
FROM generate_series(2, 5) i;
INSERT INTO public.reviews (reviewer_id, reviewed_user_id, ad_id, rating) VALUES
  ('00000000-0000-0000-0000-000000000406', '00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000a401', 4),
  ('00000000-0000-0000-0000-000000000407', '00000000-0000-0000-0000-000000000408', '00000000-0000-0000-0000-00000000a408', 5),
  ('00000000-0000-0000-0000-000000000408', '00000000-0000-0000-0000-000000000407', '00000000-0000-0000-0000-00000000a407', 5);

SELECT is((SELECT count(*) FROM public.reviews WHERE reviewed_user_id = '00000000-0000-0000-0000-000000000401'
           AND reviewer_id <> '00000000-0000-0000-0000-000000000406' AND flagged_at IS NOT NULL), 4::bigint,
  'the four ring reviews are flagged');
SELECT ok((SELECT bool_and('cluster' = ANY (suspicion_reasons) AND 'new_account' = ANY (suspicion_reasons)
                           AND 'thin_contact' = ANY (suspicion_reasons) AND 'no_activity' = ANY (suspicion_reasons))
           FROM public.reviews WHERE reviewed_user_id = '00000000-0000-0000-0000-000000000401'
             AND reviewer_id <> '00000000-0000-0000-0000-000000000406'),
  'with the reasons: cluster, new account, contact only hours before, no other activity');
SELECT ok((SELECT max(weight) FROM public.reviews WHERE flagged_at IS NOT NULL) < 1, 'flagged reviews weigh less');
SELECT is((SELECT weight FROM public.reviews WHERE reviewer_id = '00000000-0000-0000-0000-000000000406'), 1.0::numeric,
  'the real buyer''s review keeps full weight and is not flagged');
SELECT is((SELECT count(*) FROM public.reviews WHERE 'mutual' = ANY (suspicion_reasons) AND flagged_at IS NOT NULL), 2::bigint,
  'two accounts reviewing each other are flagged');

-- Trust follows the weights: four 5-star ring reviews add little.
SELECT ok((SELECT trust_score FROM public.users WHERE id = '00000000-0000-0000-0000-000000000401') < 60,
  'the ring seller''s trust stays below 60 (unweighted it would be 81)');

-- The review queue: for the admin panel (service role, after its own staff
-- and MFA checks, like the other moderation functions); never for clients.
SET LOCAL ROLE service_role;
SELECT is((SELECT count(*) FROM public.suspicious_reviews()), 6::bigint, 'the panel sees the six flagged reviews in the queue');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT throws_ok($$ SELECT * FROM public.suspicious_reviews() $$, '42501', NULL, 'clients cannot');
RESET ROLE;

-- The threshold lives in app_configs.
UPDATE public.app_configs SET value = '99' WHERE key = 'review_suspicion_threshold';
SELECT public.rescore_seller_reviews('00000000-0000-0000-0000-000000000401');
SELECT is((SELECT count(*) FROM public.reviews WHERE reviewed_user_id = '00000000-0000-0000-0000-000000000401' AND flagged_at IS NOT NULL),
  0::bigint, 'review_suspicion_threshold is read from app_configs');

SELECT * FROM finish();
ROLLBACK;
