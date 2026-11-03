BEGIN;
SELECT plan(4);

-- docs/ALGORITHMS.md §2: one 5-star review gave more trust than six reviews
-- averaging 4. Seller A: one 5-star. Seller B: six reviews of 4 stars.
-- Neither is ID-verified; both accounts are new.
INSERT INTO auth.users (id, phone)
SELECT ('00000000-0000-0000-0000-0000000003' || lpad(i::text, 2, '0'))::uuid, '2010999003' || lpad(i::text, 2, '0')
FROM generate_series(1, 9) i;

INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, status) VALUES
  ('00000000-0000-0000-0000-00000000a301', '00000000-0000-0000-0000-000000000301', 29, 'إعلان أ', 'وصف إعلان البائع أ', 100, 1, 'active'),
  ('00000000-0000-0000-0000-00000000a302', '00000000-0000-0000-0000-000000000302', 29, 'إعلان ب', 'وصف إعلان البائع ب', 100, 1, 'active');
-- Buyers 03..09 contacted the ads (reviews need a contact).
INSERT INTO public.contact_logs (ad_id, user_id, contact_type)
SELECT ad, ('00000000-0000-0000-0000-0000000003' || lpad(i::text, 2, '0'))::uuid, 'phone'
FROM generate_series(3, 9) i, (VALUES ('00000000-0000-0000-0000-00000000a301'::uuid), ('00000000-0000-0000-0000-00000000a302'::uuid)) v(ad);
-- Real buyers: months-old accounts, contacts days before the reviews (so the
-- ring checks of test 37 leave them alone).
UPDATE public.contact_logs SET created_at = now() - interval '3 days'
WHERE ad_id IN ('00000000-0000-0000-0000-00000000a301', '00000000-0000-0000-0000-00000000a302');
UPDATE public.users SET created_at = now() - interval '200 days'
WHERE id IN (SELECT ('00000000-0000-0000-0000-0000000003' || lpad(i::text, 2, '0'))::uuid FROM generate_series(3, 9) i);

INSERT INTO public.reviews (reviewer_id, reviewed_user_id, ad_id, rating) VALUES
  ('00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000a301', 5);
INSERT INTO public.reviews (reviewer_id, reviewed_user_id, ad_id, rating)
SELECT ('00000000-0000-0000-0000-0000000003' || lpad(i::text, 2, '0'))::uuid,
       '00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-00000000a302', 4
FROM generate_series(4, 9) i;

SELECT ok((SELECT trust_score FROM public.users WHERE id = '00000000-0000-0000-0000-000000000302')
        > (SELECT trust_score FROM public.users WHERE id = '00000000-0000-0000-0000-000000000301'),
  'six reviews averaging 4 give more trust than a single 5-star review');

-- With prior 3.5 and weight 5: R = (5*3.5 + 5)/6 = 3.75 -> 40*0.75 + 1 = 31.
SELECT is((SELECT trust_score FROM public.users WHERE id = '00000000-0000-0000-0000-000000000301'), 31.00::numeric(5,2),
  'one 5-star review: Bayesian average (5*3.5 + 5) / 6');

-- The prior lives in app_configs; a recompute picks up a change.
UPDATE public.app_configs SET value = '0' WHERE key = 'trust_prior_weight';
SELECT public.recompute_trust_score('00000000-0000-0000-0000-000000000301');
SELECT is((SELECT trust_score FROM public.users WHERE id = '00000000-0000-0000-0000-000000000301'), 41.00::numeric(5,2),
  'weight 0 is the plain average again (40 + 1)');

SET LOCAL ROLE authenticated;
SELECT throws_ok($$ SELECT public.recompute_trust_score('00000000-0000-0000-0000-000000000301') $$, '42501', NULL,
  'clients cannot recompute scores');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
