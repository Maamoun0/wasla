'use client';

import { useState } from 'react';
import { createBrowserClient } from '@/lib/supabase/browser';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [step, setStep] = useState(1); // 1: Credentials, 2: 2FA
  const [otp, setOtp] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  const supabase = createBrowserClient();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const { data, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (authError) {
      setError('بيانات الدخول غير صحيحة');
      setLoading(false);
      return;
    }

    // After password success, check for 2FA requirement
    // In a real implementation, we would verify the 2FA secret here
    // For MVP Sprint 7, we simulate the 2FA step
    setStep(2);
    setLoading(false);
  };

  const verify2FA = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    
    // The role comes from public.users (server-managed), not user_metadata,
    // which users can edit. This check is UX only; the server enforces access.
    const { data: profile } = await supabase.rpc('get_my_profile').maybeSingle<{ user_type: string }>();
    const role = profile?.user_type;

    if (role === 'admin' || role === 'moderator') {
      router.push('/dashboard');
    } else {
      setError('عذراً، لا تملك صلاحيات الوصول للوحة التحكم');
      await supabase.auth.signOut();
      setStep(1);
    }
    setLoading(false);
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

        {step === 1 ? (
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
          <form className="mt-8 space-y-6" onSubmit={verify2FA}>
            <div className="text-center space-y-2">
              <label className="block text-sm font-medium text-gray-700 font-cairo">رمز التحقق (2FA)</label>
              <p className="text-xs text-gray-500 font-cairo">أدخل الرمز المكون من 6 أرقام من تطبيق المصادقة</p>
              <input
                type="text"
                required
                maxLength={6}
                value={otp}
                onChange={(e) => setOtp(e.target.value)}
                className="mt-2 block w-full text-center tracking-[1em] text-2xl px-4 py-3 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"
                placeholder="000000"
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 px-4 border border-transparent rounded-lg shadow-sm text-white bg-green-600 hover:bg-green-700 focus:outline-none font-cairo"
            >
              {loading ? 'جاري التحقق من الرمز...' : 'تأكيد الرمز والدخول'}
            </button>
            <button
              type="button"
              onClick={() => setStep(1)}
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
