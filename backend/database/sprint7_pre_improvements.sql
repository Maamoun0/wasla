-- 🔧 Wasla - Sprint 7 Pre-Improvements Migration
-- 1. Transactions table update (adding updated_at)
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 2. Ads table update (adding ai_layer_used)
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS ai_layer_used SMALLINT;

-- 3. Indices for Performance & Admin Panel
-- Ads
CREATE INDEX IF NOT EXISTS idx_ads_status_created
  ON ads (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ads_ai_risk_status
  ON ads (ai_risk_level, status)
  WHERE status = 'pending';

-- Transactions
CREATE INDEX IF NOT EXISTS idx_transactions_status_created
  ON transactions (status, created_at DESC);

-- Users
CREATE INDEX IF NOT EXISTS idx_users_deleted_at
  ON users (deleted_at)
  WHERE deleted_at IS NULL;

-- 3. Cleanup Stale Transactions Cron Job
-- Ensure pg_cron is available (Supabase standard)
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'cleanup-stale-transactions',
  '0 * * * *',  -- Every hour
  $$
    UPDATE transactions
    SET
      status = 'expired',
      updated_at = now()
    WHERE
      status = 'pending'
      AND created_at < now() - interval '2 hours';
  $$
);
