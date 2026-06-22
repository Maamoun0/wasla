-- ================================================================
-- Wasla — Sprint 1 KYC Face Verification Mock Processor
-- Target    : public.user_verifications & public.users Tables
-- Purpose   : Automates KYC approvals/rejections in development sandbox
-- ================================================================

-- 1. Create a function to simulate real-time face comparison
CREATE OR REPLACE FUNCTION public.mock_face_verification_processor()
RETURNS TRIGGER AS $$
BEGIN
  -- Simulate a delay or check user attributes for mock results
  -- If user name contains 'FailTest' or 'حساب وهمي' or 'مرفوض', simulate rejection
  IF EXISTS (
    SELECT 1 FROM public.users
    WHERE id = NEW.user_id 
      AND (
        full_name LIKE '%FailTest%' 
        OR full_name LIKE '%حساب وهمي%' 
        OR full_name LIKE '%مرفوض%'
      )
  ) THEN
    -- Simulate rejection path
    UPDATE public.user_verifications
    SET status = 'rejected',
        rejection_reason = 'عذراً، لم تتطابق ملامح الوجه في صورتك الشخصية السيلفي مع صورة بطاقة الرقم القومي المرفوعة.'
    WHERE id = NEW.id;
    
    UPDATE public.users
    SET is_id_verified = false,
        status = 'active'
    WHERE id = NEW.user_id;

  ELSE
    -- Simulate successful match & approval path
    UPDATE public.user_verifications
    SET status = 'approved',
        verified_at = NOW()
    WHERE id = NEW.id;
    
    UPDATE public.users
    SET is_id_verified = true,
        status = 'active',
        trust_score = GREATEST(trust_score, 4.50) -- Boost trust score to 4.50 stars on successful KYC
    WHERE id = NEW.user_id;

  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Bind the trigger to fire immediately after a user submits verification
DROP TRIGGER IF EXISTS trg_mock_face_verification ON public.user_verifications;

CREATE TRIGGER trg_mock_face_verification
  AFTER INSERT ON public.user_verifications
  FOR EACH ROW
  EXECUTE FUNCTION public.mock_face_verification_processor();

COMMENT ON FUNCTION public.mock_face_verification_processor() IS 
  'محاكي آلي لمطابقة الهوية وصورة السيلفي للمرحلة التجريبية والـ Sandbox';
