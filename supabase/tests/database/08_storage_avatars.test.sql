-- Profile photos (bucket "avatars"): same rules as ad images — public read;
-- writes only inside the caller's own "{auth.uid()}/" folder; images only,
-- 2 MB. Delete ownership is checked through the Storage API in
-- supabase/tests/storage/buckets.local.ts and by policy definition here.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(14);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.local', '+201000000002', '{}', 'authenticated', 'authenticated');

INSERT INTO storage.objects (bucket_id, name, owner) VALUES
  ('avatars', '11111111-1111-1111-1111-111111111111/avatar.jpg', '11111111-1111-1111-1111-111111111111');

-- ── Bucket limits ─────────────────────────────────────────────────
SELECT ok(EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'avatars'), 'avatars bucket exists');
SELECT is((SELECT public FROM storage.buckets WHERE id = 'avatars'), true, 'avatars bucket is publicly readable');
SELECT is((SELECT file_size_limit FROM storage.buckets WHERE id = 'avatars'), 2097152::bigint, 'avatars are limited to 2 MB');
SELECT is((SELECT allowed_mime_types FROM storage.buckets WHERE id = 'avatars'),
  ARRAY['image/jpeg', 'image/png', 'image/webp'], 'avatars must be JPEG, PNG or WebP');

-- ── Policy definitions ────────────────────────────────────────────
SELECT is(
  (SELECT count(*)::int FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND (coalesce(qual, '') || coalesce(with_check, '')) LIKE '%''avatars''%'
      AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
      AND (coalesce(qual, '') || coalesce(with_check, '')) NOT LIKE '%foldername%'),
  0, 'every write policy on avatars is scoped to the owner folder');
SELECT ok(
  (SELECT bool_and(qual LIKE '%foldername%' AND qual LIKE '%auth.uid()%' AND roles = '{authenticated}')
     FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND cmd = 'DELETE'
       AND qual LIKE '%''avatars''%'),
  'delete on avatars is limited to the folder owner (authenticated only)');

-- ── Other user (B) ────────────────────────────────────────────────
SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true),
       set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT throws_ok($$ INSERT INTO storage.objects (bucket_id, name, owner)
                    VALUES ('avatars', '11111111-1111-1111-1111-111111111111/evil.jpg', auth.uid()) $$,
  '42501', NULL, 'B cannot upload into A''s folder');
SELECT throws_ok($$ INSERT INTO storage.objects (bucket_id, name, owner)
                    VALUES ('avatars', 'loose-file.jpg', auth.uid()) $$,
  '42501', NULL, 'B cannot upload outside any user folder');
SELECT lives_ok($$ INSERT INTO storage.objects (bucket_id, name, owner)
                   VALUES ('avatars', '22222222-2222-2222-2222-222222222222/avatar.jpg', auth.uid()) $$,
  'B can upload own avatar');
SELECT lives_ok($$ UPDATE storage.objects SET name = '22222222-2222-2222-2222-222222222222/stolen.jpg'
                   WHERE bucket_id = 'avatars' AND name = '11111111-1111-1111-1111-111111111111/avatar.jpg' $$,
  'B update of A''s avatar runs (RLS must filter it; checked below)');
SELECT lives_ok($$ UPDATE storage.objects SET metadata = '{"x":1}'
                   WHERE bucket_id = 'avatars' AND name = '22222222-2222-2222-2222-222222222222/avatar.jpg' $$,
  'B can update own avatar');
RESET ROLE;

SELECT is((SELECT count(*)::int FROM storage.objects
            WHERE bucket_id = 'avatars' AND name = '11111111-1111-1111-1111-111111111111/avatar.jpg'),
  1, 'A''s avatar was not moved or overwritten by B');

-- ── Anonymous ─────────────────────────────────────────────────────
SELECT set_config('request.jwt.claim.sub', '', true),
       set_config('request.jwt.claims', '{"role":"anon"}', true);
SET LOCAL ROLE anon;
SELECT throws_ok($$ INSERT INTO storage.objects (bucket_id, name)
                    VALUES ('avatars', '11111111-1111-1111-1111-111111111111/anon.jpg') $$,
  '42501', NULL, 'anon cannot upload');
SELECT isnt_empty($$ SELECT name FROM storage.objects WHERE bucket_id = 'avatars' $$, 'anon can read avatars');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
