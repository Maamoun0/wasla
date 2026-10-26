-- Test-harness only. Adds what a hosted Supabase project has but the bare
-- supabase/postgres image does not (GoTrue / storage-api migrations).
-- Never run against a live project.
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS phone text UNIQUE;
ALTER TABLE storage.buckets ADD COLUMN IF NOT EXISTS public boolean DEFAULT false;
ALTER TABLE storage.buckets ADD COLUMN IF NOT EXISTS file_size_limit bigint;
ALTER TABLE storage.buckets ADD COLUMN IF NOT EXISTS allowed_mime_types text[];
