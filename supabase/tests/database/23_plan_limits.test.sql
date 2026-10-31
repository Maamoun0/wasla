-- 🟡6 (FR-5.3): plan limits on live ads and photos, the plan comes from an
-- active subscription (else free), and clients cannot write ad photos (N23).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(15);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'free@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'basic@test.local', '+201000000002', '{}', 'authenticated', 'authenticated');

-- Calls create_ad_transaction like the create-ad function; n photos in the user's folder.
CREATE FUNCTION pg_temp.new_ad(p_user uuid, p_draft text, n integer) RETURNS uuid LANGUAGE sql AS $$
  SELECT public.create_ad_transaction(
    p_user, p_draft, (SELECT id FROM public.categories WHERE slug = 'cars'), 'إعلان', 'وصف الإعلان',
    'offering', 1000, 'fixed', (SELECT min(id) FROM public.cities), NULL, NULL, NULL,
    'low', 'ok', 2::smallint,
    (SELECT coalesce(jsonb_agg(jsonb_build_object('url', format('https://x/%s/%s.jpg', p_user, g), 'sort_order', g, 'is_primary', g = 0)), '[]')
     FROM generate_series(0, n - 1) g),
    '[]'::jsonb);
$$;

-- Free plan: 5 live ads, 4 photos (current plan rows).
SELECT is((public.user_plan('11111111-1111-1111-1111-111111111111')).name::text, 'free', 'no subscription means the free plan');

INSERT INTO public.ads (user_id, category_id, title, description, price, city_id, status)
SELECT '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.categories WHERE slug = 'cars'), 'قديم', 'desc', 1,
       (SELECT min(id) FROM public.cities), s::public.ad_status_enum
FROM unnest(ARRAY['active', 'active', 'pending', 'expired', 'expired', 'rejected', 'sold']) AS s;
SELECT is(public.live_ad_count('11111111-1111-1111-1111-111111111111'), 3, 'only pending and active ads count');

SET LOCAL ROLE service_role;
SELECT lives_ok($$ SELECT pg_temp.new_ad('11111111-1111-1111-1111-111111111111', 'd1', 4) $$, '4th live ad with 4 photos is accepted');
SELECT throws_ok($$ SELECT pg_temp.new_ad('11111111-1111-1111-1111-111111111111', 'd2', 5) $$,
  'P0001', 'image_limit_exceeded', '5 photos are over the free plan''s 4');
SELECT lives_ok($$ SELECT pg_temp.new_ad('11111111-1111-1111-1111-111111111111', 'd3', 1) $$, '5th live ad is accepted');
SELECT throws_ok($$ SELECT pg_temp.new_ad('11111111-1111-1111-1111-111111111111', 'd4', 1) $$,
  'P0001', 'ad_limit_reached', 'a 6th live ad is refused on the free plan');
SELECT is(public.plan_violation('11111111-1111-1111-1111-111111111111', 1), 'ad_limit_reached',
  'create-ad can check the limit before running the AI review');
RESET ROLE;
SELECT is((SELECT count(*)::int FROM public.ads WHERE temp_draft_id IN ('d2', 'd4')), 0, 'refused ads leave nothing behind');

-- Renewing an expired ad counts like a new one.
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT is(public.renew_ad((SELECT id FROM public.ads WHERE user_id = auth.uid() AND status = 'expired' LIMIT 1)) ->> 'error',
  'ad_limit_reached', 'an expired ad cannot be brought back over the limit');
SELECT is(public.my_plan_usage(), '{"plan": "free", "plan_name_ar": "مجاني", "max_ads": 5, "max_images_per_ad": 4, "live_ads": 5}'::jsonb,
  'the app reads its limits and usage');

-- N23: no direct photo writes.
SELECT throws_ok($$ INSERT INTO public.ad_media (ad_id, url, type, sort_order) SELECT id, 'https://x/y.jpg', 'image', 9
                   FROM public.ads WHERE user_id = auth.uid() AND status = 'active' LIMIT 1 $$,
  '42501', NULL, 'users cannot add photos to an ad directly (no swap after approval)');
SELECT throws_ok($$ DELETE FROM public.ad_media WHERE ad_id IN (SELECT id FROM public.ads WHERE user_id = auth.uid()) $$,
  '42501', NULL, 'nor delete them');
RESET ROLE;

-- Basic subscription: 20 ads, 8 photos; an expired subscription falls back to free.
INSERT INTO public.user_subscriptions (user_id, plan_id, status, expires_at)
VALUES ('22222222-2222-2222-2222-222222222222', (SELECT id FROM public.subscription_plans WHERE name = 'basic'), 'active', now() + interval '20 days');
SET LOCAL ROLE service_role;
SELECT lives_ok($$ SELECT pg_temp.new_ad('22222222-2222-2222-2222-222222222222', 'b1', 8) $$, 'a basic subscriber posts 8 photos');
RESET ROLE;
UPDATE public.user_subscriptions SET expires_at = now() - interval '1 day' WHERE user_id = '22222222-2222-2222-2222-222222222222';
SELECT is((public.user_plan('22222222-2222-2222-2222-222222222222')).name::text, 'free', 'an expired subscription falls back to free');

SET LOCAL ROLE anon;
SELECT throws_ok($$ SELECT public.user_plan('11111111-1111-1111-1111-111111111111') $$, '42501', NULL, 'guests cannot read other users'' plans');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
