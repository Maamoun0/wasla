-- ⚙️ Wasla - Sprint 10.1: Security Hardening & RLS Refinement
-- Focus: Production readiness for transactions, id-documents, and push_tokens

-- 1. Tighten transactions policy
-- Ensure only the service role or a specialized webhook function can finalize status
-- Users should ONLY see their own transactions.
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "transactions_own" ON public.transactions;
CREATE POLICY "transactions_select_own" ON public.transactions
FOR SELECT USING (user_id = auth.uid());

-- Prevent any manual insert/update from the client for critical financial data
-- Note: Inserts should happen via Edge Functions using Service Role.

-- 2. Device Tokens Security
-- Users should only manage their own tokens.
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "push_own" ON public.push_tokens;
CREATE POLICY "push_tokens_all_own" ON public.push_tokens
USING (user_id = auth.uid());

-- 3. Audit/Log Security
-- user_activity_log and audit_logs should be admin-only.
ALTER TABLE public.user_activity_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_activity_log_own" ON public.user_activity_log;
CREATE POLICY "user_activity_log_admin_only" ON public.user_activity_log
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() 
    AND role_id = (SELECT id FROM public.roles WHERE name = 'admin')
  )
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "audit_admin_only" ON public.audit_logs;
CREATE POLICY "audit_admin_access" ON public.audit_logs
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() 
    AND role_id = (SELECT id FROM public.roles WHERE name = 'admin')
  )
);

-- 4. Storage Security (Conceptual - to be applied in Supabase UI)
-- Ensure 'id-documents' bucket has NO public access.
-- Policy: (storage.foldername(name))[1] == auth.uid()::text

-- 5. KYC (user_verifications) Security
ALTER TABLE public.user_verifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "verifications_own" ON public.user_verifications;
CREATE POLICY "verifications_select_own" ON public.user_verifications
FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "verifications_insert_own" ON public.user_verifications
FOR INSERT WITH CHECK (user_id = auth.uid());

-- Moderators see all pending
CREATE POLICY "verifications_mod_access" ON public.user_verifications
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() 
    AND role_id IN (SELECT id FROM public.roles WHERE name IN ('admin', 'moderator'))
  )
);

-- 6. Legal Acceptances Table (Required for Piece 2.2)
CREATE TABLE IF NOT EXISTS public.legal_acceptances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    policy_version VARCHAR(20) NOT NULL, -- e.g. 'v1.0'
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_address TEXT,
    UNIQUE(user_id, policy_version)
);

ALTER TABLE public.legal_acceptances ENABLE ROW LEVEL SECURITY;
CREATE POLICY "legal_acceptances_insert_own" ON public.legal_acceptances
FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "legal_acceptances_select_own" ON public.legal_acceptances
FOR SELECT USING (user_id = auth.uid());

-- 7. Tighten ad_boosts policy
-- Prevent direct client writes (inserts/updates) to ad_boosts table
ALTER TABLE public.ad_boosts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "boosts_own" ON public.ad_boosts;
-- Note: Inserts are performed by the payment-webhook Edge Function using Service Role.
