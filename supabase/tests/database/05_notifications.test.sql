-- Notifications go through notifications_outbox. Ad status changes never call
-- the network inside the transaction, and a failure to enqueue never blocks
-- the change itself. dispatch-notifications claims and completes batches.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(29);

-- ── Fixtures ──────────────────────────────────────────────────────
INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'owner@test.local',   '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'watcher@test.local', '+201000000002', '{}', 'authenticated', 'authenticated'),
  ('33333333-3333-3333-3333-333333333333', 'other@test.local',   '+201000000003', '{}', 'authenticated', 'authenticated'),
  ('44444444-4444-4444-4444-444444444444', 'mod@test.local',     '+201000000004', '{}', 'authenticated', 'authenticated');
UPDATE public.users SET user_type = 'moderator' WHERE id = '44444444-4444-4444-4444-444444444444';

INSERT INTO public.push_tokens (user_id, token, platform) VALUES
  ('11111111-1111-1111-1111-111111111111', 'tok-owner-1', 'android'),
  ('11111111-1111-1111-1111-111111111111', 'tok-owner-2', 'ios'),
  ('22222222-2222-2222-2222-222222222222', 'tok-watcher', 'android');

-- Watcher follows Vehicles (parent category) anywhere, max price 500k.
INSERT INTO public.saved_searches (user_id, name, category_id, city_id, keywords, filters) VALUES
  ('22222222-2222-2222-2222-222222222222', 'سيارات', (SELECT id FROM public.categories WHERE slug = 'vehicles'), NULL, NULL, '{"max_price": 500000}'),
  ('33333333-3333-3333-3333-333333333333', 'عقارات', (SELECT id FROM public.categories WHERE slug = 'real-estate'), NULL, NULL, '{}'),
  ('33333333-3333-3333-3333-333333333333', 'تويوتا فقط', (SELECT id FROM public.categories WHERE slug = 'cars'), NULL, 'تويوتا', '{}'),
  ('11111111-1111-1111-1111-111111111111', 'نفسي', (SELECT id FROM public.categories WHERE slug = 'cars'), NULL, NULL, '{}');

INSERT INTO public.ads (id, user_id, category_id, title, description, price, city_id, status) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   (SELECT id FROM public.categories WHERE slug = 'cars'), 'هيونداي فيرنا 2018', 'desc', 300000, (SELECT min(id) FROM public.cities), 'pending'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   (SELECT id FROM public.categories WHERE slug = 'cars'), 'سيارة للبيع', 'desc', 900000, (SELECT min(id) FROM public.cities), 'pending'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   (SELECT id FROM public.categories WHERE slug = 'cars'), 'سيارة', 'desc', 100000, (SELECT min(id) FROM public.cities), 'pending');

-- ── No network calls inside ad transactions ───────────────────────
SELECT is(
  (SELECT count(*)::int FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
    WHERE t.tgrelid = 'public.ads'::regclass AND NOT t.tgisinternal AND p.prosrc ILIKE '%net.http_post%'),
  0, 'no trigger on ads calls net.http_post');

-- ── Approval / rejection via the moderation RPC (as the admin panel does) ──
SET LOCAL ROLE service_role;
SELECT lives_ok($$ SELECT public.moderate_ad('aaaaaaaa-0000-0000-0000-000000000001',
                   '44444444-4444-4444-4444-444444444444', 'approved', NULL) $$,
  'approving an ad succeeds');
RESET ROLE;
SELECT is((SELECT status::text FROM public.ads WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001'), 'active', 'ad is active');
SELECT is((SELECT count(*)::int FROM public.notifications
            WHERE user_id = '11111111-1111-1111-1111-111111111111' AND type = 'ad_approved'), 1,
  'owner gets an in-app ad_approved notification');
SELECT is((SELECT data ->> 'type' FROM public.notifications_outbox
            WHERE user_id = '11111111-1111-1111-1111-111111111111' AND data ->> 'ad_id' = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'ad_status_change', 'owner push is queued with the routing payload the app expects');

SELECT is((SELECT count(*)::int FROM public.notifications_outbox
            WHERE user_id = '22222222-2222-2222-2222-222222222222' AND data ->> 'type' = 'watchlist_match'), 1,
  'watcher of the parent category is notified once');
SELECT is((SELECT count(*)::int FROM public.notifications_outbox WHERE user_id = '33333333-3333-3333-3333-333333333333'), 0,
  'searches for another category or other keywords are not notified');
SELECT is((SELECT count(*)::int FROM public.notifications_outbox
            WHERE user_id = '11111111-1111-1111-1111-111111111111' AND data ->> 'type' = 'watchlist_match'), 0,
  'owners are not notified about their own ads');

SET LOCAL ROLE service_role;
SELECT public.moderate_ad('aaaaaaaa-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', 'approved', NULL);
RESET ROLE;
SELECT is((SELECT count(*)::int FROM public.notifications_outbox
            WHERE user_id = '22222222-2222-2222-2222-222222222222' AND data ->> 'ad_id' = 'aaaaaaaa-0000-0000-0000-000000000002'), 0,
  'max_price filter is respected');

-- Re-activation does not notify watchers twice.
UPDATE public.ads SET status = 'paused' WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001';
UPDATE public.ads SET status = 'active' WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001';
SELECT is((SELECT count(*)::int FROM public.notifications_outbox
            WHERE user_id = '22222222-2222-2222-2222-222222222222' AND data ->> 'ad_id' = 'aaaaaaaa-0000-0000-0000-000000000001'), 1,
  'a watcher is notified about an ad only once');

-- Rejection with reason; preference off means in-app only.
UPDATE public.users SET notification_preferences = '{"ad_status_updates": false}'
WHERE id = '11111111-1111-1111-1111-111111111111';
SET LOCAL ROLE service_role;
SELECT public.moderate_ad('aaaaaaaa-0000-0000-0000-000000000003', '44444444-4444-4444-4444-444444444444', 'rejected', 'صور غير واضحة');
RESET ROLE;
SELECT ok((SELECT body FROM public.notifications WHERE type = 'ad_rejected' AND data ->> 'ad_id' = 'aaaaaaaa-0000-0000-0000-000000000003')
          LIKE '%صور غير واضحة%', 'rejection notification carries the reason');
SELECT is((SELECT count(*)::int FROM public.notifications_outbox WHERE data ->> 'ad_id' = 'aaaaaaaa-0000-0000-0000-000000000003'), 0,
  'push is not queued when the owner turned status updates off');

-- ── Enqueue failures never block the change ───────────────────────
INSERT INTO public.ads (id, user_id, category_id, title, description, city_id, status) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111',
   (SELECT id FROM public.categories WHERE slug = 'cars'), 'x', 'desc', (SELECT min(id) FROM public.cities), 'pending');
ALTER TABLE public.notifications_outbox RENAME TO notifications_outbox_broken;
SET LOCAL ROLE service_role;
SELECT lives_ok($$ SELECT public.moderate_ad('aaaaaaaa-0000-0000-0000-000000000004',
                   '44444444-4444-4444-4444-444444444444', 'approved', NULL) $$,
  'approval succeeds even when notifications cannot be queued');
RESET ROLE;
ALTER TABLE public.notifications_outbox_broken RENAME TO notifications_outbox;
SELECT is((SELECT status::text FROM public.ads WHERE id = 'aaaaaaaa-0000-0000-0000-000000000004'), 'active',
  'the ad was approved despite the notification failure');

-- ── Dispatcher RPCs ───────────────────────────────────────────────
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
SELECT throws_ok($$ SELECT * FROM public.notifications_outbox $$, '42501', NULL, 'clients cannot read the outbox');
SELECT throws_ok($$ SELECT * FROM public.claim_notifications(10) $$, '42501', NULL, 'clients cannot claim notifications');
SELECT lives_ok($$ SELECT id FROM public.notifications WHERE user_id = auth.uid() $$, 'users can read their in-app notifications');
RESET ROLE;

SET LOCAL ROLE service_role;
CREATE TEMP TABLE claimed ON COMMIT DROP AS SELECT * FROM public.claim_notifications(10);
SELECT is((SELECT count(*)::int FROM claimed), 3, 'claim returns the queued pushes (two owner approvals + one watcher match)');
SELECT is((SELECT tokens FROM claimed WHERE user_id = '11111111-1111-1111-1111-111111111111' AND data ->> 'ad_id' = 'aaaaaaaa-0000-0000-0000-000000000001'),
  ARRAY['tok-owner-1', 'tok-owner-2'], 'claimed rows carry the user''s active tokens');
SELECT is((SELECT count(*)::int FROM public.claim_notifications(10)), 0, 'claimed rows are not handed out twice');

SELECT public.complete_notification((SELECT id FROM claimed WHERE user_id = '11111111-1111-1111-1111-111111111111' AND data ->> 'ad_id' = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'sent', NULL, ARRAY['tok-owner-2']);
SELECT is((SELECT status FROM public.notifications_outbox WHERE user_id = '11111111-1111-1111-1111-111111111111' AND data ->> 'ad_id' = 'aaaaaaaa-0000-0000-0000-000000000001'), 'sent',
  'sent notification is final');
SELECT is((SELECT is_active FROM public.push_tokens WHERE token = 'tok-owner-2'), false, 'unregistered token is deactivated');
SELECT is((SELECT is_active FROM public.push_tokens WHERE token = 'tok-owner-1'), true, 'working token stays active');

SELECT public.complete_notification((SELECT id FROM claimed WHERE user_id = '22222222-2222-2222-2222-222222222222'),
  'failed', 'FCM 503', '{}');
SELECT is((SELECT status FROM public.notifications_outbox WHERE user_id = '22222222-2222-2222-2222-222222222222'), 'pending',
  'transient failure goes back to the queue');
SELECT ok((SELECT available_at > now() FROM public.notifications_outbox WHERE user_id = '22222222-2222-2222-2222-222222222222'),
  'retry is delayed (backoff)');
SELECT is((SELECT last_error FROM public.notifications_outbox WHERE user_id = '22222222-2222-2222-2222-222222222222'), 'FCM 503',
  'the error is recorded');

UPDATE public.notifications_outbox SET attempts = 5, status = 'processing'
WHERE user_id = '22222222-2222-2222-2222-222222222222';
SELECT public.complete_notification((SELECT id FROM claimed WHERE user_id = '22222222-2222-2222-2222-222222222222'),
  'failed', 'FCM 503', '{}');
SELECT is((SELECT status FROM public.notifications_outbox WHERE user_id = '22222222-2222-2222-2222-222222222222'), 'failed',
  'gives up after 5 attempts');

INSERT INTO public.notifications_outbox (user_id, title, body, status, locked_at, attempts)
VALUES ('33333333-3333-3333-3333-333333333333', 't', 'b', 'processing', now() - interval '1 hour', 1);
CREATE TEMP TABLE reclaimed ON COMMIT DROP AS SELECT * FROM public.claim_notifications(10);
SELECT is((SELECT count(*)::int FROM reclaimed WHERE user_id = '33333333-3333-3333-3333-333333333333'), 1,
  'a batch abandoned by a crashed dispatcher is reclaimed');
SELECT is((SELECT tokens FROM reclaimed WHERE user_id = '33333333-3333-3333-3333-333333333333'), ARRAY[]::text[],
  'users without tokens are claimed with an empty token list');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
