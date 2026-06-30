-- 1. Create the 'ads' bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('ads', 'ads', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Allow public access to read files from the 'ads' bucket
CREATE POLICY "Public Access" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'ads');

-- 3. Allow authenticated users to upload files to the 'ads' bucket
CREATE POLICY "Auth Users Upload" 
ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'ads' 
    AND auth.role() = 'authenticated'
);

-- 4. Allow authenticated users to update their own files
CREATE POLICY "Auth Users Update" 
ON storage.objects FOR UPDATE 
USING (
    bucket_id = 'ads' 
    AND auth.role() = 'authenticated'
)
WITH CHECK (
    bucket_id = 'ads' 
    AND auth.role() = 'authenticated'
);

-- 5. Allow authenticated users to delete their own files
CREATE POLICY "Auth Users Delete" 
ON storage.objects FOR DELETE 
USING (
    bucket_id = 'ads' 
    AND auth.role() = 'authenticated'
);
