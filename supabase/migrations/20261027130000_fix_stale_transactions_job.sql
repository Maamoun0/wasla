-- ================================================================
-- cleanup-stale-transactions set status = 'expired', which is not a
-- value of transaction_status_enum, so the job failed every hour and
-- abandoned payments stayed 'pending' forever.
-- Unpaid transactions older than 2 hours (the Paymob payment key lives
-- 1 hour) are closed as 'failed' with failure_reason = 'expired_unpaid'.
-- ================================================================

CREATE OR REPLACE FUNCTION public.expire_stale_transactions()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.transactions
  SET status = 'failed',
      completed_at = now(),
      updated_at = now(),
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('failure_reason', 'expired_unpaid')
  WHERE status = 'pending' AND created_at < now() - interval '2 hours';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_stale_transactions() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_stale_transactions() TO service_role;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'cleanup-stale-transactions';
SELECT cron.schedule('cleanup-stale-transactions', '0 * * * *', 'SELECT public.expire_stale_transactions();');
