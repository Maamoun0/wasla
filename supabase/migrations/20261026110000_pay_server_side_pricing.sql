-- ================================================================
-- PAY (ب): server-side pricing and atomic, idempotent fulfilment.
--   * payment_packages is the only source of prices. Clients send a
--     package_id; create-payment charges the package price.
--   * fulfill_payment() is called by payment-webhook after HMAC
--     verification. It locks the transaction row, ignores repeats,
--     rejects amount/currency mismatches, and activates the boost /
--     subscription / credits in the same transaction.
--   * protect_ad_sensitive_fields now exempts server roles, so the
--     webhook and moderation RPCs can set is_featured / status.
-- ================================================================

-- ── 1. Price table ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.payment_packages (
  id            TEXT                         PRIMARY KEY,
  kind          public.transaction_type_enum NOT NULL,
  name_ar       VARCHAR(100)                 NOT NULL,
  price_egp     DECIMAL(10,2)                NOT NULL CHECK (price_egp > 0),
  duration_days INTEGER                      NOT NULL DEFAULT 0 CHECK (duration_days >= 0),
  boost_type    public.boost_type_enum,
  plan_id       SMALLINT                     REFERENCES public.subscription_plans(id) ON DELETE RESTRICT,
  credit_amount DECIMAL(10,2)                CHECK (credit_amount > 0),
  is_active     BOOLEAN                      NOT NULL DEFAULT TRUE,
  sort_order    SMALLINT                     NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ                  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ                  NOT NULL DEFAULT NOW(),
  CONSTRAINT payment_packages_kind_shape CHECK (
       (kind = 'ad_boost'        AND boost_type IS NOT NULL AND plan_id IS NULL AND credit_amount IS NULL)
    OR (kind = 'subscription'    AND plan_id IS NOT NULL AND boost_type IS NULL AND credit_amount IS NULL AND duration_days > 0)
    OR (kind = 'credit_purchase' AND credit_amount IS NOT NULL AND boost_type IS NULL AND plan_id IS NULL)
  )
);
COMMENT ON TABLE public.payment_packages IS 'مصدر الأسعار الوحيد للمدفوعات — يُدار من لوحة الإدارة فقط';

ALTER TABLE public.payment_packages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.payment_packages FROM anon, authenticated;
GRANT SELECT ON public.payment_packages TO anon, authenticated;
GRANT ALL ON public.payment_packages TO service_role;
DROP POLICY IF EXISTS payment_packages_public_read ON public.payment_packages;
CREATE POLICY payment_packages_public_read ON public.payment_packages
  FOR SELECT TO anon, authenticated USING (is_active);

-- Seed from the prices the app shows today: boost prices in app_configs,
-- subscription prices in subscription_plans.price_monthly.
INSERT INTO public.payment_packages (id, kind, name_ar, price_egp, duration_days, boost_type, sort_order)
SELECT p.id, 'ad_boost', p.name_ar, (c.value #>> '{}')::numeric, p.days, p.boost::public.boost_type_enum, p.sort_order
FROM (VALUES
  ('boost_featured_3d',  'إعلان مميز (3 أيام)',   3,  'featured', 1),
  ('boost_featured_7d',  'إعلان مميز (7 أيام)',   7,  'featured', 2),
  ('boost_featured_14d', 'إعلان مميز (14 يوم)',   14, 'featured', 3),
  ('boost_featured_30d', 'إعلان مميز (30 يوم)',   30, 'featured', 4),
  ('boost_urgent_7d',    'إعلان عاجل (7 أيام)',   7,  'urgent',   5),
  ('boost_bump',         'تحديث الترتيب (Bump)', 0,  'bump',     6)
) AS p(id, name_ar, days, boost, sort_order)
JOIN public.app_configs c ON c.key = p.id
WHERE (c.value #>> '{}') ~ '^[0-9]+(\.[0-9]+)?$' AND (c.value #>> '{}')::numeric > 0
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.payment_packages (id, kind, name_ar, price_egp, duration_days, plan_id, sort_order)
SELECT 'sub_' || sp.name || '_monthly', 'subscription', sp.name_ar || ' — شهري', sp.price_monthly, 30, sp.id, 100 + sp.sort_order
FROM public.subscription_plans sp
WHERE sp.price_monthly > 0
ON CONFLICT (id) DO NOTHING;

-- ── 2. Transactions reference the package they were priced from ──
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS package_id TEXT
  REFERENCES public.payment_packages(id) ON DELETE RESTRICT;
CREATE UNIQUE INDEX IF NOT EXISTS uq_transactions_gateway_tx
  ON public.transactions (payment_gateway, gateway_transaction_id)
  WHERE gateway_transaction_id IS NOT NULL;

-- ── 3. Ad protection trigger: enforce for client roles only ──────
-- It previously keyed on is_moderator(), which is false for
-- service_role and inside SECURITY DEFINER RPCs (auth.uid() is NULL),
-- so it also blocked the payment webhook and admin moderation.
-- As SECURITY INVOKER, current_user is the client role for PostgREST
-- calls and the function owner inside SECURITY DEFINER RPCs.
CREATE OR REPLACE FUNCTION public.protect_ad_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN NEW;
  END IF;

  IF OLD.user_id IS DISTINCT FROM NEW.user_id THEN
    RAISE EXCEPTION 'Ownership cannot be changed directly.' USING ERRCODE = '42501';
  END IF;
  IF OLD.is_featured IS DISTINCT FROM NEW.is_featured
     OR OLD.is_urgent IS DISTINCT FROM NEW.is_urgent
     OR OLD.refreshed_at IS DISTINCT FROM NEW.refreshed_at THEN
    RAISE EXCEPTION 'Promotion fields can only be changed by the payment flow.' USING ERRCODE = '42501';
  END IF;
  IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status NOT IN ('paused', 'deleted', 'sold') THEN
    RAISE EXCEPTION 'Status change restricted. Use official moderation flow.' USING ERRCODE = '42501';
  END IF;
  IF OLD.rejection_reason IS DISTINCT FROM NEW.rejection_reason THEN
    RAISE EXCEPTION 'Rejection reason can only be modified by moderators.' USING ERRCODE = '42501';
  END IF;
  IF to_jsonb(OLD) ? 'ai_layer_used' AND (to_jsonb(OLD) -> 'ai_layer_used') IS DISTINCT FROM (to_jsonb(NEW) -> 'ai_layer_used') THEN
    RAISE EXCEPTION 'AI review fields are system-managed.' USING ERRCODE = '42501';
  END IF;
  IF OLD.search_attributes IS DISTINCT FROM NEW.search_attributes THEN
    RAISE EXCEPTION 'AI review fields are system-managed.' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

-- ── 4. Atomic fulfilment ─────────────────────────────────────────
-- Result: completed | failed | amount_mismatch | already_processed | not_found
CREATE OR REPLACE FUNCTION public.fulfill_payment(
  p_transaction_id uuid,
  p_success        boolean,
  p_amount_cents   bigint,
  p_currency       text,
  p_gateway_data   jsonb
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_tx      public.transactions%ROWTYPE;
  v_pkg     public.payment_packages%ROWTYPE;
  v_now     timestamptz := now();
  v_balance numeric;
BEGIN
  SELECT * INTO v_tx FROM public.transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN 'not_found';
  END IF;
  IF v_tx.status <> 'pending' THEN
    RETURN 'already_processed';
  END IF;

  IF NOT p_success THEN
    UPDATE public.transactions
    SET status = 'failed', completed_at = v_now,
        metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('gateway', p_gateway_data)
    WHERE id = v_tx.id;
    RETURN 'failed';
  END IF;

  IF p_amount_cents IS DISTINCT FROM round(v_tx.amount * 100)::bigint
     OR upper(coalesce(p_currency, '')) <> upper(v_tx.currency) THEN
    UPDATE public.transactions
    SET status = 'failed', completed_at = v_now,
        metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
          'gateway', p_gateway_data,
          'amount_mismatch', jsonb_build_object(
            'expected_cents', round(v_tx.amount * 100)::bigint, 'paid_cents', p_amount_cents,
            'expected_currency', v_tx.currency, 'paid_currency', p_currency))
    WHERE id = v_tx.id;
    RETURN 'amount_mismatch';
  END IF;

  SELECT * INTO v_pkg FROM public.payment_packages WHERE id = v_tx.package_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'transaction % has no payment package', v_tx.id;
  END IF;

  IF v_pkg.kind = 'ad_boost' THEN
    INSERT INTO public.ad_boosts (ad_id, user_id, boost_type, started_at, expires_at)
    VALUES (v_tx.reference_id, v_tx.user_id, v_pkg.boost_type, v_now,
            v_now + make_interval(days => v_pkg.duration_days));

    UPDATE public.ads
    SET is_featured  = is_featured OR v_pkg.boost_type = 'featured',
        is_urgent    = is_urgent   OR v_pkg.boost_type = 'urgent',
        refreshed_at = CASE WHEN v_pkg.boost_type = 'bump' THEN v_now ELSE refreshed_at END
    WHERE id = v_tx.reference_id;

  ELSIF v_pkg.kind = 'subscription' THEN
    UPDATE public.user_subscriptions SET status = 'cancelled'
    WHERE user_id = v_tx.user_id AND status = 'active';

    INSERT INTO public.user_subscriptions (user_id, plan_id, status, started_at, expires_at, auto_renew)
    VALUES (v_tx.user_id, v_pkg.plan_id, 'active', v_now,
            v_now + make_interval(days => v_pkg.duration_days), FALSE);

  ELSIF v_pkg.kind = 'credit_purchase' THEN
    INSERT INTO public.user_credits (user_id, balance, updated_at)
    VALUES (v_tx.user_id, v_pkg.credit_amount, v_now)
    ON CONFLICT (user_id) DO UPDATE
      SET balance = public.user_credits.balance + EXCLUDED.balance, updated_at = v_now
    RETURNING balance INTO v_balance;

    INSERT INTO public.credit_transactions (user_id, amount, type, description, balance_after)
    VALUES (v_tx.user_id, v_pkg.credit_amount, 'purchase', 'شراء رصيد: ' || v_pkg.name_ar, v_balance);
  END IF;

  UPDATE public.transactions
  SET status = 'completed', completed_at = v_now,
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('gateway', p_gateway_data)
  WHERE id = v_tx.id;

  RETURN 'completed';
END;
$$;

REVOKE ALL ON FUNCTION public.fulfill_payment(uuid, boolean, bigint, text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fulfill_payment(uuid, boolean, bigint, text, jsonb) TO service_role;
