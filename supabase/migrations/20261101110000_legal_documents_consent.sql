-- N21: terms and privacy shown in the app from app_configs, with a version,
-- and the user's acceptance of that exact version recorded.
--  * app_configs 'legal_terms' / 'legal_privacy' = {version, url, body}.
--    Version 0 is a placeholder: the drafts in docs/legal/ need legal review
--    before any text is published (decision 2026-11-01), so the seed only
--    says that. Publishing = a new version number with the reviewed body
--    (or a url); users are then asked to accept it.
--  * accept_legal_documents records acceptance only for the current
--    versions; legal_acceptances is no longer writable directly (anyone
--    could insert any version, including for another user via anon).
--  * legal_status tells the app whether the signed-in user accepted the
--    current versions.

INSERT INTO public.app_configs (key, value, description) VALUES
  ('legal_terms', jsonb_build_object('version', 0, 'url', NULL,
     'body', 'شروط الاستخدام النهائية قيد المراجعة القانونية وهتتنشر هنا قريباً.'),
   'شروط الاستخدام: version و body أو url'),
  ('legal_privacy', jsonb_build_object('version', 0, 'url', NULL,
     'body', 'سياسة الخصوصية النهائية قيد المراجعة القانونية وهتتنشر هنا قريباً.'),
   'سياسة الخصوصية: version و body أو url')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.legal_version(p_kind text)
RETURNS integer
LANGUAGE sql STABLE SET search_path = public, pg_temp
AS $$
  SELECT coalesce((value ->> 'version')::integer, 0) FROM public.app_configs
  WHERE key = 'legal_' || p_kind AND p_kind IN ('terms', 'privacy') AND (value ->> 'version') ~ '^[0-9]+$';
$$;

CREATE OR REPLACE FUNCTION public.accept_legal_documents(p_terms_version integer, p_privacy_version integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not signed in' USING ERRCODE = '42501';
  END IF;
  -- The user must have seen the versions that are current now.
  IF p_terms_version IS DISTINCT FROM public.legal_version('terms')
     OR p_privacy_version IS DISTINCT FROM public.legal_version('privacy') THEN
    RETURN jsonb_build_object('success', false, 'error', 'stale_version',
      'terms', public.legal_version('terms'), 'privacy', public.legal_version('privacy'));
  END IF;
  INSERT INTO public.legal_acceptances (user_id, policy_version)
  VALUES (auth.uid(), 'terms:' || p_terms_version), (auth.uid(), 'privacy:' || p_privacy_version)
  ON CONFLICT (user_id, policy_version) DO NOTHING;
  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.legal_status()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'terms_version', public.legal_version('terms'),
    'privacy_version', public.legal_version('privacy'),
    'accepted', auth.uid() IS NOT NULL
      AND EXISTS (SELECT 1 FROM public.legal_acceptances
                  WHERE user_id = auth.uid() AND policy_version = 'terms:' || public.legal_version('terms'))
      AND EXISTS (SELECT 1 FROM public.legal_acceptances
                  WHERE user_id = auth.uid() AND policy_version = 'privacy:' || public.legal_version('privacy')));
$$;

DROP POLICY IF EXISTS legal_acceptances_insert_own ON public.legal_acceptances;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.legal_acceptances FROM anon, authenticated;
REVOKE ALL ON public.legal_acceptances FROM anon;

REVOKE ALL ON FUNCTION public.accept_legal_documents(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_legal_documents(integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.legal_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.legal_status() TO authenticated;
