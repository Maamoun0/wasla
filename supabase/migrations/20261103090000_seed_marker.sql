-- Test data for staging (scripts/data/staging_seed.sql) is marked is_seed, so
-- one call removes all of it: select public.delete_seed_data();
-- Real rows keep is_seed = false and are never touched.

ALTER TABLE public.users        ADD COLUMN IF NOT EXISTS is_seed boolean NOT NULL DEFAULT false;
ALTER TABLE public.ads          ADD COLUMN IF NOT EXISTS is_seed boolean NOT NULL DEFAULT false;
ALTER TABLE public.reviews      ADD COLUMN IF NOT EXISTS is_seed boolean NOT NULL DEFAULT false;
ALTER TABLE public.reports      ADD COLUMN IF NOT EXISTS is_seed boolean NOT NULL DEFAULT false;
ALTER TABLE public.contact_logs ADD COLUMN IF NOT EXISTS is_seed boolean NOT NULL DEFAULT false;

-- Clients cannot write the marker (column grants elsewhere list writable
-- columns explicitly; this keeps it off any future broad grant).
REVOKE UPDATE (is_seed) ON public.users, public.ads, public.reviews, public.reports FROM anon, authenticated;

-- Seed users' auth rows go first: everything they own cascades from there.
-- Seed rows attached to real users (none are created that way) go after.
CREATE OR REPLACE FUNCTION public.delete_seed_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_users int;
  v_ads int;
BEGIN
  SELECT count(*) INTO v_ads FROM public.ads WHERE is_seed;
  DELETE FROM auth.users WHERE id IN (SELECT id FROM public.users WHERE is_seed);
  GET DIAGNOSTICS v_users = ROW_COUNT;
  DELETE FROM public.reports      WHERE is_seed;
  DELETE FROM public.reviews      WHERE is_seed;
  DELETE FROM public.contact_logs WHERE is_seed;
  DELETE FROM public.ads          WHERE is_seed;
  RETURN jsonb_build_object('users', v_users, 'ads', v_ads);
END;
$$;

REVOKE ALL ON FUNCTION public.delete_seed_data() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_seed_data() TO service_role;
