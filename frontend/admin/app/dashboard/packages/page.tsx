import { createAdminClient } from '@/lib/supabase/server';
import { requireStaff } from '@/lib/auth';
import PackageRow from '@/components/PackageRow';
import { Tag } from 'lucide-react';

const KIND_LABELS: Record<string, string> = {
  ad_boost: 'ترويج الإعلانات',
  subscription: 'الاشتراكات',
  credit_purchase: 'شراء رصيد',
};

export default async function PackagesPage() {
  await requireStaff(['admin']);
  const supabase = createAdminClient();
  const { data: packages } = await supabase
    .from('payment_packages')
    .select('id, kind, name_ar, price_egp, duration_days, is_active, sort_order')
    .order('sort_order', { ascending: true });

  const groups = Object.entries(KIND_LABELS)
    .map(([kind, label]) => ({ kind, label, rows: (packages ?? []).filter((p) => p.kind === kind) }))
    .filter((g) => g.rows.length > 0);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold font-cairo text-gray-800 flex items-center space-x-2 space-x-reverse">
          <Tag className="text-blue-600" />
          <span>الباقات والأسعار</span>
        </h1>
        <p className="text-gray-500 font-cairo text-sm mt-1">
          السعر الجديد بيطبّق على أي عملية دفع تبدأ بعد الحفظ. العمليات اللي بدأت قبل كده بتتحاسب بسعرها الأصلي.
          المدة ونوع الباقة ثابتين.
        </p>
      </div>

      {groups.map((g) => (
        <div key={g.kind} className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
          <h2 className="px-6 py-3 bg-gray-50 border-b border-gray-100 font-cairo font-bold text-gray-700">{g.label}</h2>
          <table className="w-full text-right" dir="rtl">
            <thead className="border-b border-gray-100">
              <tr className="text-xs font-cairo text-gray-500">
                <th className="px-6 py-2">الاسم</th>
                <th className="px-6 py-2">المدة</th>
                <th className="px-6 py-2">السعر (ج.م)</th>
                <th className="px-6 py-2">الترتيب</th>
                <th className="px-6 py-2">مفعّلة</th>
                <th className="px-6 py-2"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {g.rows.map((p) => (
                <PackageRow
                  key={p.id}
                  pkg={{
                    id: p.id,
                    name_ar: p.name_ar,
                    price_egp: Number(p.price_egp),
                    duration_days: p.duration_days,
                    is_active: p.is_active,
                    sort_order: p.sort_order,
                  }}
                />
              ))}
            </tbody>
          </table>
        </div>
      ))}
    </div>
  );
}
