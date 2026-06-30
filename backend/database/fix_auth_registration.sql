-- ================================================================
--  وصلة (Wasla) — إصلاح مشكلة التسجيل (Auth Fix Migration)
--  تشغيل: Supabase Dashboard → SQL Editor → Run
--  التاريخ: 2026-06-25
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- §1 · إصلاح trigger handle_new_user
-- يُعالج الآن: OTP (هاتف) + Google OAuth (إيميل)
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _phone TEXT;
  _email TEXT;
  _full_name TEXT;
BEGIN
  _phone     := NEW.phone;
  _email     := NEW.email;
  _full_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    ''
  );

  INSERT INTO public.users (id, email, phone, full_name)
  VALUES (NEW.id, _email, _phone, _full_name)
  ON CONFLICT (id) DO UPDATE SET
    email      = EXCLUDED.email,
    phone      = COALESCE(EXCLUDED.phone, public.users.phone),
    full_name  = CASE 
                   WHEN public.users.full_name = '' THEN EXCLUDED.full_name 
                   ELSE public.users.full_name 
                 END,
    updated_at = NOW();

  INSERT INTO public.user_credits (user_id, balance)
  VALUES (NEW.id, 0.00)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ────────────────────────────────────────────────────────────────
-- §2 · إضافة policy إدراج المستخدمين (كان مفقوداً)
-- ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "users_insert_trigger" ON public.users;
CREATE POLICY "users_insert_trigger" ON public.users 
  FOR INSERT 
  WITH CHECK (true);


-- ────────────────────────────────────────────────────────────────
-- §3 · جدول otp_requests (مطلوب لـ Edge Function request-otp)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.otp_requests (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number VARCHAR(20) NOT NULL,
  ip_address   TEXT        NOT NULL DEFAULT 'unknown',
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otp_requests_phone_time 
  ON public.otp_requests(phone_number, requested_at DESC);

ALTER TABLE public.otp_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "otp_requests_service_only" ON public.otp_requests;
CREATE POLICY "otp_requests_service_only" ON public.otp_requests
  USING (false)
  WITH CHECK (false);


-- ────────────────────────────────────────────────────────────────
-- §4 · إضافة UNIQUE constraint على user_credits.user_id
-- ────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'user_credits_user_id_key'
  ) THEN
    ALTER TABLE public.user_credits ADD CONSTRAINT user_credits_user_id_key UNIQUE (user_id);
  END IF;
END;
$$;


-- ────────────────────────────────────────────────────────────────
-- §5 · التحقق من نجاح التطبيق
-- ────────────────────────────────────────────────────────────────
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';
