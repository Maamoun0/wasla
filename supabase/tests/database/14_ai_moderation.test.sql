-- AI-01: the AI verdict is stored on the ad for moderators, never publishes
-- an ad, is logged with its reason, and AI calls are limited per user/day.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(14);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated');
UPDATE public.app_configs SET value = '2' WHERE key = 'ai_moderation_daily_limit';

SELECT has_column('public', 'ads', 'ai_risk_level', 'ads.ai_risk_level exists (admin queue reads it)');
SELECT has_column('public', 'ads', 'ai_review_notes', 'ads.ai_review_notes exists');

SET LOCAL ROLE service_role;
CREATE TEMP TABLE created ON COMMIT DROP AS
SELECT public.create_ad_transaction('11111111-1111-1111-1111-111111111111', 'draft-low',
  (SELECT id FROM public.categories WHERE slug = 'plumbing'), 'سباك', 'وصف الإعلان هنا', 'offering', 100, 'fixed',
  (SELECT min(id) FROM public.cities), NULL, NULL, NULL, 'low', 'سليم', 2::smallint, '[]'::jsonb, '[]'::jsonb) AS id;
SELECT public.create_ad_transaction('11111111-1111-1111-1111-111111111111', 'draft-unrev',
  (SELECT id FROM public.categories WHERE slug = 'plumbing'), 'سباك 2', 'وصف الإعلان هنا', 'offering', 100, 'fixed',
  (SELECT min(id) FROM public.cities), NULL, NULL, NULL, 'unreviewed', 'فشلت المراجعة الآلية', 0::smallint, '[]'::jsonb, '[]'::jsonb);
RESET ROLE;

SELECT is((SELECT status::text FROM public.ads WHERE id = (SELECT id FROM created)), 'pending',
  'a low-risk verdict does not publish the ad');
SELECT results_eq($$ SELECT ai_risk_level, ai_review_notes, ai_layer_used::int FROM public.ads WHERE id = (SELECT id FROM created) $$,
  $$ VALUES ('low'::text, 'سليم'::text, 2) $$, 'verdict, reason and layer are stored on the ad');
SELECT is((SELECT ai_risk_level FROM public.ads WHERE temp_draft_id = 'draft-unrev'), 'unreviewed',
  'a failed review is stored as unreviewed');
SELECT throws_ok($$ UPDATE public.ads SET ai_risk_level = 'whatever' WHERE temp_draft_id = 'draft-unrev' $$,
  '23514', NULL, 'only known risk levels are accepted');
SELECT results_eq(
  $$ SELECT ai_risk_level FROM public.ads WHERE temp_draft_id IN ('draft-low', 'draft-unrev') ORDER BY ai_risk_rank DESC $$,
  $$ VALUES ('unreviewed'::text), ('low'::text) $$,
  'unreviewed ads rank above low-risk ones in the moderation queue');

-- Clients cannot touch the verdict on their own ad.
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok($$ UPDATE public.ads SET ai_risk_level = 'low' WHERE temp_draft_id = 'draft-unrev' $$,
  '42501', NULL, 'owner cannot downgrade the AI verdict');
SELECT throws_ok($$ SELECT * FROM public.ai_moderation_log $$, '42501', NULL, 'clients cannot read the moderation log');
SELECT throws_ok($$ SELECT public.ai_moderation_allowed(auth.uid()) $$, '42501', NULL, 'clients cannot query the AI quota');
RESET ROLE;

-- Daily limit (2 for this test): only reviews that called the API count.
SET LOCAL ROLE service_role;
SELECT ok(public.ai_moderation_allowed('11111111-1111-1111-1111-111111111111'), 'allowed before any AI call');
INSERT INTO public.ai_moderation_log (user_id, temp_draft_id, layer, risk_level, notes, model) VALUES
  ('11111111-1111-1111-1111-111111111111', 'd1', 2, 'low', 'سليم', 'fast'),
  ('11111111-1111-1111-1111-111111111111', 'd2', 1, 'high', 'كلمات محظورة', NULL);
SELECT ok(public.ai_moderation_allowed('11111111-1111-1111-1111-111111111111'), 'local (layer 1) checks do not use the quota');
INSERT INTO public.ai_moderation_log (user_id, temp_draft_id, layer, risk_level, notes, model) VALUES
  ('11111111-1111-1111-1111-111111111111', 'd3', 3, 'medium', 'شك', 'deep');
SELECT ok(NOT public.ai_moderation_allowed('11111111-1111-1111-1111-111111111111'), 'blocked after 2 AI reviews in 24h');
SELECT is((SELECT count(*)::int FROM public.ai_moderation_log WHERE user_id = '11111111-1111-1111-1111-111111111111'), 3,
  'every decision is logged with its reason');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
