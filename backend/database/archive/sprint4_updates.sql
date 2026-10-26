-- ========================================================================================
-- WASLA CLASSIFIEDS PLATFORM - SPRINT 4 SCHEMAS & TRIGGERS
-- ========================================================================================

-- 1. Alter public.users trust_score column to scale 0-100
-- Drop the existing check constraint
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_trust_score_check;

-- Change the column type to DECIMAL(5,2) to allow values up to 100
ALTER TABLE public.users ALTER COLUMN trust_score TYPE DECIMAL(5,2);

-- Add the new check constraint restricting the values to 0 to 100
ALTER TABLE public.users ADD CONSTRAINT users_trust_score_check CHECK (trust_score BETWEEN 0.00 AND 100.00);

-- 2. Alter public.user_verifications to add national_id column
ALTER TABLE public.user_verifications ADD COLUMN IF NOT EXISTS national_id VARCHAR(14);

-- 3. Create public.audit_log table to track identity document access
CREATE TABLE IF NOT EXISTS public.audit_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action        VARCHAR(100) NOT NULL, -- e.g. 'generate_signed_url'
  user_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  details       TEXT,
  performed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable Row Level Security (RLS) on audit_log
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Admins/Moderators can view audit logs" ON public.audit_log;
DROP POLICY IF EXISTS "System can insert audit logs" ON public.audit_log;

-- Admin/moderators can view audit logs
CREATE POLICY "Admins/Moderators can view audit logs"
  ON public.audit_log FOR SELECT
  TO authenticated
  USING ((SELECT user_type FROM public.users WHERE id = auth.uid()) IN ('admin', 'moderator'));

-- System/functions can insert logs
CREATE POLICY "System can insert audit logs"
  ON public.audit_log FOR INSERT
  TO authenticated, service_role
  WITH CHECK (true);

-- 4. Secure id-documents storage bucket
-- Drop client policies to prevent direct upload/select/delete from Flutter
DROP POLICY IF EXISTS "Allow authenticated users to upload KYC documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow owner and admin/moderators to view KYC documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own KYC documents" ON storage.objects;

-- 5. Redefine public.update_trust_score trigger function
CREATE OR REPLACE FUNCTION public.update_trust_score()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  target_user UUID;
  v_is_verified BOOLEAN;
  v_avg_rating NUMERIC;
  v_review_count INT;
  v_created_at TIMESTAMPTZ;
  v_months_old INT;
  v_score NUMERIC;
BEGIN
  -- If triggered by reviews table:
  IF TG_TABLE_NAME = 'reviews' THEN
    target_user := COALESCE(NEW.reviewed_user_id, OLD.reviewed_user_id);
  -- If triggered by users table:
  ELSIF TG_TABLE_NAME = 'users' THEN
    target_user := NEW.id;
    -- If is_id_verified did not change, skip update to avoid recursion
    IF NEW.is_id_verified IS NOT DISTINCT FROM OLD.is_id_verified AND NEW.trust_score IS NOT DISTINCT FROM OLD.trust_score THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Get user attributes
  SELECT is_id_verified, created_at
  INTO v_is_verified, v_created_at
  FROM public.users
  WHERE id = target_user;
  
  -- Get review stats (average rating and count)
  SELECT COALESCE(AVG(rating)::NUMERIC, 0.00), COUNT(*)::INT
  INTO v_avg_rating, v_review_count
  FROM public.reviews
  WHERE reviewed_user_id = target_user AND status = 'active';
  
  -- Get account age in months (approximated as 30 days)
  v_months_old := LEAST(floor(EXTRACT(epoch FROM (now() - v_created_at)) / 2592000)::INT, 10);

  -- Calculate score:
  -- 1. Verification: 30 if verified, 0 otherwise
  -- 2. Review average: (v_avg_rating / 5.0) * 40.0
  -- 3. Review count: 1 per review, max 20
  -- 4. Account age: 1 per month, max 10
  v_score := 0.00;
  
  IF v_is_verified THEN
    v_score := v_score + 30.00;
  END IF;
  
  v_score := v_score + (v_avg_rating / 5.00) * 40.00;
  v_score := v_score + LEAST(v_review_count, 20);
  v_score := v_score + v_months_old;
  
  -- Update users table or modify NEW in BEFORE trigger
  IF TG_TABLE_NAME = 'users' THEN
    NEW.trust_score := ROUND(v_score::NUMERIC, 2);
    RETURN NEW;
  ELSE
    UPDATE public.users
    SET trust_score = ROUND(v_score::NUMERIC, 2)
    WHERE id = target_user;
    RETURN NULL;
  END IF;
END;
$$;

-- 6. Bind the update_trust_score trigger to the public.users table for updates on is_id_verified
DROP TRIGGER IF EXISTS trg_trust_score_users ON public.users;
CREATE TRIGGER trg_trust_score_users
  BEFORE UPDATE OF is_id_verified ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.update_trust_score();

-- 7. Update public.review_responses RLS policy for replies security
DROP POLICY IF EXISTS "rev_resp_insert" ON public.review_responses;
CREATE POLICY "rev_resp_insert"
  ON public.review_responses FOR INSERT
  WITH CHECK (
    user_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.reviews
      WHERE id = review_id AND reviewed_user_id = auth.uid()
    )
  );
