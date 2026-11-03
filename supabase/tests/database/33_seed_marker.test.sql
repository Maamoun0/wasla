BEGIN;
SELECT plan(6);

-- A real user with an ad, and a seed user with an ad and a report on the real ad.
INSERT INTO auth.users (id, phone) VALUES
  ('00000000-0000-0000-0000-0000000000a1', '201099990001'),
  ('00000000-0000-0000-0000-0000000000a2', '201099990002');
UPDATE public.users SET is_seed = true WHERE id = '00000000-0000-0000-0000-0000000000a2';

INSERT INTO public.ads (id, user_id, category_id, title, description, city_id, is_seed) VALUES
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 1, 'إعلان حقيقي', 'وصف إعلان حقيقي للاختبار', 1, false),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2', 1, 'إعلان تجريبي', 'وصف إعلان تجريبي للاختبار', 1, true);
INSERT INTO public.reports (reporter_id, target_type, target_id, reason, is_seed) VALUES
  ('00000000-0000-0000-0000-0000000000a2', 'ad', '00000000-0000-0000-0000-0000000000b1', 'spam', true);

SELECT is(public.delete_seed_data(), '{"users": 1, "ads": 1}'::jsonb, 'reports what it removed');
SELECT is((SELECT count(*) FROM public.users WHERE is_seed), 0::bigint, 'no seed users left');
SELECT is((SELECT count(*) FROM public.ads WHERE is_seed), 0::bigint, 'no seed ads left');
SELECT is((SELECT count(*) FROM public.reports WHERE target_id = '00000000-0000-0000-0000-0000000000b1'), 0::bigint,
  'the seed report on a real ad is gone');
SELECT ok(EXISTS (SELECT 1 FROM public.ads WHERE id = '00000000-0000-0000-0000-0000000000b1'), 'the real ad stays');

SET LOCAL ROLE authenticated;
SELECT throws_ok('SELECT public.delete_seed_data()', '42501', NULL, 'clients cannot call it');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
