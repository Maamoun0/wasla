'use client';

import { useEffect, useState } from 'react';
import { createBrowserClient } from '@/lib/supabase/browser';
import { useRouter } from 'next/navigation';

type Step = 'credentials' | 'enroll' | 'verify';

interface Enrollment {
  factorId: string;
  qrCode: string;
  secret: string;
}

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [step, setStep] = useState<Step>('credentials');
  const [otp, setOtp] = useState('');
  const [factorId, setFactorId] = useState<string | null>(null);
  const [enrollment, setEnrollment] = useState<Enrollment | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  const supabase = createBrowserClient();

  // Staff must hold an admin/moderator role (UX check only; the server enforces it),
  // then complete TOTP. Staff without a verified factor enroll one here.
  const startMfa = async () => {
    const { data: profile } = await supabase.rpc('get_my_profile').maybeSingle<{ user_type: string }>();
    if (profile?.user_type !== 'admin' && profile?.user_type !== 'moderator') {
      await supabase.auth.signOut();
      setStep('credentials');
      setError('عذراً، لا تملك صلاحيات الوصول للوحة التحكم');
      return;
    }

    const { data: factors, error: listError } = await supabase.auth.mfa.listFactors();
    if (listError) {
      setError('تعذّر التحقق من إعدادات المصادقة الثنائية');
      return;
    }

    const verified = factors.totp.find((f) => f.status === 'verified');
    if (verified) {
      setFactorId(verified.id);
      setStep('verify');
      return;
    }

    // Drop abandoned, never-verified enrollments before starting a new one.
    for (const f of factors.all.filter((f) => f.factor_type === 'totp' && f.status !== 'verified')) {
      await supabase.auth.mfa.unenroll({ factorId: f.id });
    }
    const { data: enrolled, error: enrollError } = await supabase.auth.mfa.enroll({
      factorType: 'totp',
      friendlyName: 'Wasla Admin',
    });
    if (enrollError || !enrolled) {
      setError('تعذّر بدء تفعيل المصادقة الثنائية');
      return;
    }
    setFactorId(enrolled.id);
    setEnrollment({ factorId: enrolled.id, qrCode: enrolled.totp.qr_code, secret: enrolled.totp.secret });
    setStep('enroll');
  };

  // Returning with a password session but without TOTP (?mfa=1): resume at the MFA step.
  useEffect(() => {
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) await startMfa();
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
    if (authError) {
      setError('بيانات الدخول غير صحيحة');
      setLoading(false);
      return;
    }

    await startMfa();
    setLoading(false);
  };

  const verifyTotp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!factorId) return;
    setLoading(true);
    setError(null);

    const { error: verifyError } = await supabase.auth.mfa.challengeAndVerify({ factorId, code: otp.trim() });
    if (verifyError) {
      setError('رمز التحقق غير صحيح أو منتهي');
      setOtp('');
      setLoading(false);
      return;
    }

    router.replace('/dashboard');
    router.refresh();
  };

  const backToCredentials = async () => {
    await supabase.auth.signOut();
    setOtp('');
    setEnrollment(null);
    setFactorId(null);
    setStep('credentials');
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
      <div className="max-w-md w-full space-y-8 bg-white p-10 rounded-2xl shadow-xl border border-gray-100">
        <div className="text-center">
          <h2 className="text-3xl font-extrabold text-gray-900 font-cairo">وصلة</h2>
          <p className="mt-2 text-sm text-gray-600 font-cairo">لوحة الإدارة والمراجعة</p>
        </div>

        {error && (
          <div className="bg-red-50 border-r-4 border-red-500 p-4 text-red-700 text-sm font-cairo">
            {error}
          </div>
        )}

        {step === 'credentials' ? (
          <form className="mt-8 space-y-6" onSubmit={handleLogin}>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 font-cairo">البريد الإلكتروني</label>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="mt-1 block w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 font-cairo">كلمة المرور</label>
                <input
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="mt-1 block w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 px-4 border border-transparent rounded-lg shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none font-cairo"
            >
              {loading ? 'جاري التحقق...' : 'دخول'}
            </button>
          </form>
        ) : (
          <form className="mt-8 space-y-6" onSubmit={verifyTotp}>
            {step === 'enroll' && enrollment && (
              <div className="text-center space-y-3">
                <p className="text-sm font-cairo text-gray-700">
                  المصادقة الثنائية إلزامية لحسابات الإدارة. امسح الرمز بتطبيق مصادقة (Google Authenticator أو Microsoft Authenticator) ثم أدخل الرمز المكون من 6 أرقام.
                </p>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={enrollment.qrCode} alt="TOTP QR code" className="mx-auto h-48 w-48" />
                <p className="text-xs text-gray-500 font-cairo">
                  أو أدخل المفتاح يدوياً: <span className="font-mono select-all" dir="ltr">{enrollment.secret}</span>
                </p>
              </div>
            )}
            <div className="text-center space-y-2">
              <label className="block text-sm font-medium text-gray-700 font-cairo">رمز التحقق (2FA)</label>
              <p className="text-xs text-gray-500 font-cairo">أدخل الرمز المكون من 6 أرقام من تطبيق المصادقة</p>
              <input
                type="text"
                inputMode="numeric"
                autoComplete="one-time-code"
                required
                pattern="[0-9]{6}"
                maxLength={6}
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                className="mt-2 block w-full text-center tracking-[1em] text-2xl px-4 py-3 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"
                placeholder="000000"
              />
            </div>
            <button
              type="submit"
              disabled={loading || otp.length !== 6}
              className="w-full py-3 px-4 border border-transparent rounded-lg shadow-sm text-white bg-green-600 hover:bg-green-700 focus:outline-none font-cairo"
            >
              {loading ? 'جاري التحقق من الرمز...' : 'تأكيد الرمز والدخول'}
            </button>
            <button
              type="button"
              onClick={backToCredentials}
              className="w-full text-sm text-gray-500 font-cairo"
            >
              العودة لتسجيل الدخول
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
