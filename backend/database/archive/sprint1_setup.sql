-- ================================================================
-- Wasla — Sprint 1 Setup & Security Rules
-- Target    : Supabase Storage & public.user_verifications Table
-- Version   : 1.0.0
-- ================================================================

-- 1. Create the private 'id-documents' bucket for KYC identity papers
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'id-documents', 
  'id-documents', 
  false,               -- Private bucket, no public access
  1048576,             -- 1MB file size limit (1024 * 1024 bytes)
  ARRAY['image/jpeg', 'image/jpg', 'image/png']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Drop existing Storage Policies for id-documents if they exist
DROP POLICY IF EXISTS "Allow authenticated users to upload KYC documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow owner and admin/moderators to view KYC documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own KYC documents" ON storage.objects;

-- 3. Create Storage Policies for 'id-documents' bucket
-- Policy A: Insert/Upload
CREATE POLICY "Allow authenticated users to upload KYC documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'id-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy B: Select/View
CREATE POLICY "Allow owner and admin/moderators to view KYC documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'id-documents' AND
  (
    (storage.foldername(name))[1] = auth.uid()::text OR
    (SELECT user_type FROM public.users WHERE id = auth.uid()) IN ('admin', 'moderator')
  )
);

-- Policy C: Delete
CREATE POLICY "Allow users to delete their own KYC documents"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'id-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);


-- 4. Lock down RLS for public.user_verifications table
-- First, drop the default permissive policy from wasla-schema.sql
DROP POLICY IF EXISTS "verifications_own" ON public.user_verifications;

-- Drop new policies if they exist to allow clean replay
DROP POLICY IF EXISTS "verifications_select" ON public.user_verifications;
DROP POLICY IF EXISTS "verifications_insert" ON public.user_verifications;
DROP POLICY IF EXISTS "verifications_update" ON public.user_verifications;

-- Policy 1: Users can view their own requests, admins/moderators can view all
CREATE POLICY "verifications_select"
ON public.user_verifications FOR SELECT
TO authenticated
USING (
  user_id = auth.uid() OR
  (SELECT user_type FROM public.users WHERE id = auth.uid()) IN ('admin', 'moderator')
);

-- Policy 2: Users can submit new verification requests with pending status
CREATE POLICY "verifications_insert"
ON public.user_verifications FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid() AND
  status = 'pending'::verification_status_enum
);

-- Policy 3: Only admins/moderators can update status (e.g. approve or reject)
CREATE POLICY "verifications_update"
ON public.user_verifications FOR UPDATE
TO authenticated
USING (
  (SELECT user_type FROM public.users WHERE id = auth.uid()) IN ('admin', 'moderator')
);
