-- 🟡2: users list, count and mark their own notifications read; live
-- updates reach the app through the realtime publication.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(9);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.local', '+201000000002', '{}', 'authenticated', 'authenticated');

INSERT INTO public.notifications (id, user_id, type, title, body) VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'ad_approved', 't1', 'b1'),
  ('bbbbbbbb-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'ad_rejected', 't2', 'b2'),
  ('bbbbbbbb-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'saved_search_match', 't3', 'b3'),
  ('bbbbbbbb-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', 'ad_approved', 't4', 'b4');

SELECT ok(EXISTS (SELECT 1 FROM pg_publication_tables
                  WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications'),
  'notifications is published for realtime (the app''s live list and badge)');

SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true),
       set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT is(public.unread_notifications_count(), 3, 'the badge counts the caller''s unread notifications only');
SELECT is(public.mark_notifications_read(ARRAY['bbbbbbbb-0000-0000-0000-000000000001'::uuid]), 1, 'opening one marks it read');
SELECT is(public.unread_notifications_count(), 2, 'and the badge drops');
SELECT is(public.mark_notifications_read(ARRAY['bbbbbbbb-0000-0000-0000-000000000004'::uuid]), 0,
  'another user''s notification cannot be marked');
SELECT is(public.mark_notifications_read(), 2, '"mark all read" marks the rest');
SELECT is(public.unread_notifications_count(), 0, 'nothing unread left');
SELECT ok((SELECT bool_and(read_at IS NOT NULL) FROM public.notifications), 'read time is recorded');
RESET ROLE;

SELECT is((SELECT is_read FROM public.notifications WHERE id = 'bbbbbbbb-0000-0000-0000-000000000004'), false,
  'the other user''s notification is still unread');

SELECT * FROM finish();
ROLLBACK;
