-- ================================================================
-- N7: ad images. The legacy policies let any signed-in user upload,
-- overwrite or delete any object in the "ads" bucket (they only checked
-- auth.role() = 'authenticated'), and the bucket had no type/size limits.
-- Now: public read; insert / update / delete only inside the caller's own
-- "{auth.uid()}/" folder; JPEG/PNG/WebP up to 5 MB (security plan §2).
-- The app already stores images as {userId}/{draftId}/{imageId}.jpg.
-- ================================================================

UPDATE storage.buckets
SET public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
WHERE id = 'ads';

-- Drop every existing policy that targets the ads bucket, whatever its name.
DO $$
DECLARE
  p record;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND (coalesce(qual, '') || coalesce(with_check, '')) LIKE '%''ads''%'
  LOOP
    EXECUTE format('DROP POLICY %I ON storage.objects', p.policyname);
  END LOOP;
END;
$$;

CREATE POLICY ads_public_read ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'ads');

CREATE POLICY ads_owner_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'ads' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY ads_owner_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'ads' AND (storage.foldername(name))[1] = auth.uid()::text)
  WITH CHECK (bucket_id = 'ads' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY ads_owner_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'ads' AND (storage.foldername(name))[1] = auth.uid()::text);
