-- 🟡12: the ad performance screen gets real numbers.
--  * views_count was never incremented (nothing wrote ad_views), so every
--    ad showed 0 views. record_ad_view counts a view when the ad page opens:
--    not the owner's own views, a signed-in viewer once a day, guests
--    capped at 30 views per ad per minute. No IP address is stored.
--  * ad_performance returns, to the owner (or a moderator) only, the
--    totals and a 30-day daily series of views and contacts (calls and
--    WhatsApp, from contact_logs).
--  * View rows older than 90 days are deleted daily; the total stays in
--    ads.views_count. Clients cannot read ad_views or contact_logs.

REVOKE ALL ON public.ad_views FROM anon, authenticated;
CREATE INDEX IF NOT EXISTS idx_contact_logs_ad_created ON public.contact_logs (ad_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.record_ad_view(p_ad_id uuid, p_source text DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_owner uuid;
  v_viewer uuid := auth.uid();
BEGIN
  SELECT user_id INTO v_owner FROM public.ads
  WHERE id = p_ad_id AND status = 'active' AND deleted_at IS NULL AND NOT coalesce(is_hidden, false);
  IF NOT FOUND OR v_owner = v_viewer THEN
    RETURN false;
  END IF;

  IF v_viewer IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.ad_views
               WHERE ad_id = p_ad_id AND viewer_id = v_viewer AND created_at > date_trunc('day', now())) THEN
      RETURN false;
    END IF;
  ELSIF (SELECT count(*) FROM public.ad_views
         WHERE ad_id = p_ad_id AND viewer_id IS NULL AND created_at > now() - interval '1 minute') >= 30 THEN
    RETURN false;
  END IF;

  INSERT INTO public.ad_views (ad_id, viewer_id, source)
  VALUES (p_ad_id, v_viewer, left(p_source, 30));
  UPDATE public.ads SET views_count = views_count + 1 WHERE id = p_ad_id;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.ad_performance(p_ad_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_ad public.ads;
BEGIN
  SELECT * INTO v_ad FROM public.ads WHERE id = p_ad_id;
  IF NOT FOUND OR (v_ad.user_id IS DISTINCT FROM auth.uid() AND NOT public.is_moderator()) THEN
    RAISE EXCEPTION 'not allowed' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'title', v_ad.title,
    'status', v_ad.status,
    'published_at', v_ad.published_at,
    'expires_at', v_ad.expires_at,
    'views', v_ad.views_count,
    'favorites', v_ad.favorites_count,
    'calls', (SELECT count(*) FROM public.contact_logs WHERE ad_id = p_ad_id AND contact_type = 'phone'),
    'whatsapp', (SELECT count(*) FROM public.contact_logs WHERE ad_id = p_ad_id AND contact_type = 'whatsapp'),
    'daily', (
      SELECT jsonb_agg(jsonb_build_object(
               'day', d.day::date,
               'views', (SELECT count(*) FROM public.ad_views v
                         WHERE v.ad_id = p_ad_id AND v.created_at >= d.day AND v.created_at < d.day + interval '1 day'),
               'contacts', (SELECT count(*) FROM public.contact_logs c
                            WHERE c.ad_id = p_ad_id AND c.created_at >= d.day AND c.created_at < d.day + interval '1 day'))
             ORDER BY d.day)
      FROM generate_series(date_trunc('day', now()) - interval '29 days', date_trunc('day', now()), interval '1 day') AS d(day)));
END;
$$;

SELECT cron.schedule('cleanup-ad-views', '30 3 * * *',
  $$DELETE FROM public.ad_views WHERE created_at < now() - interval '90 days'$$);

REVOKE ALL ON FUNCTION public.record_ad_view(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_ad_view(uuid, text) TO anon, authenticated;
REVOKE ALL ON FUNCTION public.ad_performance(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ad_performance(uuid) TO authenticated;
