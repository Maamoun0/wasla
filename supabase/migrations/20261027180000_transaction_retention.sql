-- ================================================================
-- Retention decision: payment records outlive the account, anonymised
-- (docs/wasla_security_privacy_plan.md §6). transactions.user_id was
-- NOT NULL ON DELETE CASCADE, so purging an account erased its payments.
--   * user_id becomes nullable, ON DELETE SET NULL.
--   * Before a profile row is deleted, its transactions lose the ad
--     reference and their metadata is reduced to an allowlist:
--     failure_reason, amount_mismatch and the gateway fields id, order_id,
--     amount_cents, currency, success, pending, source_type, created_at.
--     Everything else (legacy billing name/email/phone, payment keys,
--     the raw Paymob payload with billing_data and card digits,
--     client-sent metadata) is dropped.
-- Kept: amount, currency, type, package, status, payment method/gateway,
-- created/completed dates, Paymob order id and transaction id.
-- ================================================================

ALTER TABLE public.transactions ALTER COLUMN user_id DROP NOT NULL;

DO $$
DECLARE
  c record;
BEGIN
  FOR c IN
    SELECT conname FROM pg_constraint
    WHERE contype = 'f' AND conrelid = 'public.transactions'::regclass
      AND confrelid = 'public.users'::regclass
  LOOP
    EXECUTE format('ALTER TABLE public.transactions DROP CONSTRAINT %I', c.conname);
  END LOOP;
END;
$$;

ALTER TABLE public.transactions
  ADD CONSTRAINT transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.scrub_transaction_metadata(p_metadata jsonb)
RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path = public, pg_temp
AS $$
  WITH m AS (SELECT coalesce(p_metadata, '{}'::jsonb) AS j),
  -- Records from the legacy webhook only have the raw Paymob payload.
  g AS (
    SELECT CASE
             WHEN jsonb_typeof(m.j -> 'gateway') = 'object' THEN m.j -> 'gateway'
             WHEN jsonb_typeof(m.j -> 'paymob_callback_payload') = 'object' THEN jsonb_build_object(
               'id', m.j #> '{paymob_callback_payload,id}',
               'order_id', coalesce(m.j #> '{paymob_callback_payload,order,id}', m.j #> '{paymob_callback_payload,order}'),
               'amount_cents', m.j #> '{paymob_callback_payload,amount_cents}',
               'currency', m.j #> '{paymob_callback_payload,currency}',
               'success', m.j #> '{paymob_callback_payload,success}',
               'pending', m.j #> '{paymob_callback_payload,pending}',
               'source_type', m.j #> '{paymob_callback_payload,source_data,type}',
               'created_at', m.j #> '{paymob_callback_payload,created_at}')
           END AS j
    FROM m
  )
  SELECT jsonb_strip_nulls(jsonb_build_object(
    'failure_reason', m.j -> 'failure_reason',
    'amount_mismatch', m.j -> 'amount_mismatch',
    'gateway', (SELECT jsonb_object_agg(e.key, e.value)
                FROM jsonb_each(coalesce(g.j, '{}'::jsonb)) e
                WHERE e.key IN ('id', 'order_id', 'amount_cents', 'currency', 'success', 'pending', 'source_type', 'created_at')
                  AND e.value <> 'null'::jsonb)))
  FROM m, g;
$$;

CREATE OR REPLACE FUNCTION public.anonymize_user_transactions()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.transactions
  SET reference_id = NULL,
      metadata = public.scrub_transaction_metadata(metadata)
  WHERE user_id = OLD.id;
  RETURN OLD;
END;
$$;

REVOKE ALL ON FUNCTION public.anonymize_user_transactions() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_anonymize_user_transactions ON public.users;
CREATE TRIGGER trg_anonymize_user_transactions
  BEFORE DELETE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.anonymize_user_transactions();
