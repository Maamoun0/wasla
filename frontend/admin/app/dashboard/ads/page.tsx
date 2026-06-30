import { createAdminClient } from '@/lib/supabase';
import { AlertTriangle } from 'lucide-react';
import AdReviewActions from '@/components/AdReviewActions';

export default async function AdsReviewPage() {
  const supabase = createAdminClient();

  // Fetch pending ads sorted by risk level (high first)
  const { data: ads } = await supabase
    .from('ads')
    .select(`
      id,
      title,
      created_at,
      status,
      ai_risk_level,
      ai_review_notes,
      price,
      currency,
      users (full_name)
    `)
    .eq('status', 'pending')
    .order('ai_risk_level', { ascending: false });

  const getRiskColor = (level: string) => {
    switch (level) {
      case 'high': return 'bg-red-100 text-red-700 border-red-200';
      case 'medium': return 'bg-orange-100 text-orange-700 border-orange-200';
      default: return 'bg-blue-100 text-blue-700 border-blue-200';
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold font-cairo text-gray-800">مراجعة الإعلانات</h1>
          <p className="text-gray-500 font-cairo text-sm mt-1">طابور مراجعة الإعلانات المعلّقة حسب مستوى الخطورة</p>
        </div>
        <div className="bg-white px-4 py-2 rounded-lg border border-gray-200 text-sm font-cairo">
          إجمالي المعلّق: <span className="font-bold text-blue-600">{ads?.length ?? 0}</span>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        <table className="w-full text-right" dir="rtl">
          <thead className="bg-gray-50 border-b border-gray-100">
            <tr>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">الإعلان</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">المعلن</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">الخطورة (AI)</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">التاريخ</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">الإجراءات</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {ads?.map((ad: any) => (
              <tr key={ad.id} className="hover:bg-gray-50/50 transition-colors">
                <td className="px-6 py-4">
                  <div className="font-cairo text-sm font-bold text-gray-900">{ad.title}</div>
                  <div className="font-cairo text-xs text-gray-500">
                    {Number(ad.price).toLocaleString()} {ad.currency}
                  </div>
                </td>
                <td className="px-6 py-4 text-sm font-cairo text-gray-600">
                  {ad.users?.full_name ?? 'مستخدم غير معروف'}
                </td>
                <td className="px-6 py-4">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold border ${getRiskColor(ad.ai_risk_level)}`}>
                    {ad.ai_risk_level === 'high' && <AlertTriangle size={12} className="ml-1" />}
                    {ad.ai_risk_level === 'high' ? 'عالية' : ad.ai_risk_level === 'medium' ? 'متوسطة' : 'منخفضة'}
                  </span>
                  {ad.ai_review_notes && (
                    <p className="text-[10px] text-gray-400 font-cairo mt-1 max-w-[200px] truncate" title={ad.ai_review_notes}>
                      {ad.ai_review_notes}
                    </p>
                  )}
                </td>
                <td className="px-6 py-4 text-xs font-cairo text-gray-500">
                  {new Date(ad.created_at).toLocaleDateString('ar-EG')}
                </td>
                <td className="px-6 py-4">
                   <AdReviewActions adId={ad.id} adTitle={ad.title} />
                </td>
              </tr>
            ))}
            {(!ads || ads.length === 0) && (
              <tr>
                <td colSpan={5} className="px-6 py-12 text-center text-gray-400 font-cairo">
                  لا توجد إعلانات معلّقة حالياً
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
