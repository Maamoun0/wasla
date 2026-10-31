-- 🟡2 In-app notifications center.
--  * notifications joins the supabase_realtime publication: the app's
--    .stream() only receives live inserts/updates for published tables
--    (RLS still limits each user to their own rows).
--  * mark_notifications_read: marks the caller's own notifications (given ids,
--    or all) as read with the server's time.
--  * unread_notifications_count: the badge count, independent of how many
--    rows the list loads.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (SELECT 1 FROM pg_publication_tables
                     WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_notifications_read(p_ids uuid[] DEFAULT NULL)
RETURNS integer
LANGUAGE sql SECURITY INVOKER SET search_path = public, pg_temp
AS $$
  -- Runs as the caller: RLS and column grants limit it to their own rows.
  WITH updated AS (
    UPDATE public.notifications
    SET is_read = true, read_at = now()
    WHERE user_id = auth.uid() AND NOT is_read
      AND (p_ids IS NULL OR id = ANY (p_ids))
    RETURNING 1
  )
  SELECT count(*)::integer FROM updated;
$$;

CREATE OR REPLACE FUNCTION public.unread_notifications_count()
RETURNS integer
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_temp
AS $$
  SELECT count(*)::integer FROM public.notifications WHERE user_id = auth.uid() AND NOT is_read;
$$;

REVOKE ALL ON FUNCTION public.mark_notifications_read(uuid[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unread_notifications_count() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_notifications_read(uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unread_notifications_count() TO authenticated;
