-- ========================================================================================
-- WASLA CLASSIFIEDS PLATFORM - SPRINT 2 SCHEMA UPGRADES & STORAGE POLICIES
-- ========================================================================================

-- 1. Add temp_draft_id to ads table to enforce idempotency
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS temp_draft_id VARCHAR(50) UNIQUE;

-- 2. Drop existing policies on storage.objects for 'ads' bucket if they exist
DROP POLICY IF EXISTS "Allow public select on ads bucket" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to upload ads images" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own ads images" ON storage.objects;

-- 3. Create public SELECT policy for the 'ads' bucket
CREATE POLICY "Allow public select on ads bucket"
ON storage.objects FOR SELECT
USING (bucket_id = 'ads');

-- 4. Create INSERT policy for the 'ads' bucket (Only authenticated users can upload under their own user folder)
CREATE POLICY "Allow authenticated users to upload ads images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'ads' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 5. Create DELETE policy for the 'ads' bucket (Only owner can delete their own uploaded images)
CREATE POLICY "Allow users to delete their own ads images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'ads' AND
  (storage.foldername(name))[1] = auth.uid()::text
);
