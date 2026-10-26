-- Test-harness only. Adds what a hosted Supabase project has but the bare
-- supabase/postgres image does not (GoTrue / storage-api migrations).
-- Never run against a live project.
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS phone text UNIQUE;
ALTER TABLE storage.buckets ADD COLUMN IF NOT EXISTS public boolean DEFAULT false;
ALTER TABLE storage.buckets ADD COLUMN IF NOT EXISTS file_size_limit bigint;
ALTER TABLE storage.buckets ADD COLUMN IF NOT EXISTS allowed_mime_types text[];
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS banned_until timestamptz;
CREATE TABLE IF NOT EXISTS auth.sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);
GRANT ALL ON auth.sessions TO postgres;
