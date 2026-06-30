import { createAdminClient } from '@/lib/supabase';
import KYCImagePreview from '@/components/KYCImagePreview';
import KYCActions from '@/components/KYCActions';
import { UserCheck, Shield } from 'lucide-react';

export default async function KYCPage() {
  const supabase = createAdminClient();

  // Fetch pending verifications with user details
  const { data: verifications } = await supabase
    .from('user_verifications')
    .select(`
      id,
      user_id,
      document_url,
      document_back_url,
      selfie_url,
      status,
      created_at,
      users (full_name, phone)
    `)
    .eq('status', 'pending')
    .order('created_at', { ascending: true });

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold font-cairo text-gray-800 flex items-center space-x-2 space-x-reverse">
            <UserCheck className="text-blue-600" />
            <span>توثيق الهوية (KYC)</span>
          </h1>
          <p className="text-gray-500 font-cairo text-sm mt-1">مراجعة مستندات المستخدمين لرفع درجة الثقة</p>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        <table className="w-full text-right" dir="rtl">
          <thead className="bg-gray-50 border-b border-gray-100">
            <tr>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">المستخدم</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">المستندات</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">تاريخ الطلب</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">الإجراءات</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {verifications?.map((v: any) => (
              <tr key={v.id} className="hover:bg-gray-50/50 transition-colors">
                <td className="px-6 py-4">
                  <div className="font-cairo text-sm font-bold text-gray-900">{v.users?.full_name}</div>
                  <div className="font-cairo text-xs text-gray-500">{v.users?.phone}</div>
                </td>
                <td className="px-6 py-4">
                  <div className="flex flex-wrap gap-2">
                    {v.document_url && (
                      <KYCImagePreview path={v.document_url} label="أمامية البطاقة" />
                    )}
                    {v.document_back_url && (
                      <KYCImagePreview path={v.document_back_url} label="خلفية البطاقة" />
                    )}
                    {v.selfie_url && (
                      <KYCImagePreview path={v.selfie_url} label="صورة السيلفي" />
                    )}
                  </div>
                </td>
                <td className="px-6 py-4 text-xs font-cairo text-gray-500">
                  {new Date(v.created_at).toLocaleString('ar-EG')}
                </td>
                <td className="px-6 py-4">
                  <KYCActions verificationId={v.id} userName={v.users?.full_name} />
                </td>
              </tr>
            ))}
            {(!verifications || verifications.length === 0) && (
              <tr>
                <td colSpan={4} className="px-6 py-12 text-center text-gray-400 font-cairo">
                  لا توجد طلبات توثيق معلقة حالياً
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      
      <div className="p-4 bg-blue-50 border border-blue-100 rounded-lg flex items-start space-x-3 space-x-reverse">
        <Shield className="text-blue-600 mt-0.5" size={20} />
        <div>
          <h4 className="text-sm font-bold font-cairo text-blue-900">تعليمات أمنية للمشرفين</h4>
          <p className="text-xs font-cairo text-blue-700 mt-1 leading-relaxed">
            عند الضغط على عرض المستند، يتم إنشاء رابط موقت صالح لمدة 5 دقائق فقط. يمنع منعاً باتاً تصوير أو حفظ مستندات الهوية الشخصية للمستخدمين خارج النظام. أي مخالفة سيتم رصدها في سجل التحركات.
          </p>
        </div>
      </div>
    </div>
  );
}
