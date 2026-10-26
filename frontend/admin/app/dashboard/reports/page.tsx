import { createAdminClient } from '@/lib/supabase/server';
import { requireStaff } from '@/lib/auth';
import { AlertCircle, CheckCircle2, XCircle, ExternalLink } from 'lucide-react';
import ReportActions from '@/components/ReportActions';

export default async function ReportsPage() {
  await requireStaff();
  const supabase = createAdminClient();

  // Fetch pending reports with reporter and target details
  const { data: reports } = await supabase
    .from('reports')
    .select(`
      id,
      reporter_id,
      target_type,
      target_id,
      reason,
      description,
      status,
      created_at,
      users!reports_reporter_id_fkey (full_name, phone)
    `)
    .eq('status', 'pending')
    .order('created_at', { ascending: false });

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold font-cairo text-gray-800 flex items-center gap-2">
            <AlertCircle className="text-red-600" />
            <span>بلاغات المستخدمين</span>
          </h1>
          <p className="text-gray-500 font-cairo text-sm mt-1">إدارة الشكاوى والبلاغات المقدمة ضد الإعلانات أو المستخدمين</p>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        <table className="w-full text-right" dir="rtl">
          <thead className="bg-gray-50 border-b border-gray-100">
            <tr>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">المُبلغ</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">نوع البلاغ</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">السبب والوصف</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">تاريخ البلاغ</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">الإجراءات</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {reports?.map((report: any) => (
              <tr key={report.id} className="hover:bg-gray-50/50 transition-colors">
                <td className="px-6 py-4">
                  <div className="font-cairo text-sm font-bold text-gray-900">{report.users?.full_name}</div>
                  <div className="font-cairo text-xs text-gray-500">{report.users?.phone}</div>
                </td>
                <td className="px-6 py-4">
                  <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-bold font-cairo ${
                    report.target_type === 'ad' ? 'bg-blue-50 text-blue-700' : 'bg-purple-50 text-purple-700'
                  }`}>
                    {report.target_type === 'ad' ? 'إعلان' : 'مستخدم'}
                  </span>
                  <div className="mt-1 text-[10px] text-gray-400 font-mono select-all">
                    ID: {report.target_id.substring(0, 8)}...
                  </div>
                </td>
                <td className="px-6 py-4 max-w-xs">
                  <div className="font-cairo text-sm font-bold text-gray-800">
                    {report.reason}
                  </div>
                  {report.description && (
                    <p className="font-cairo text-xs text-gray-500 mt-1 line-clamp-2" title={report.description}>
                      {report.description}
                    </p>
                  )}
                </td>
                <td className="px-6 py-4 text-xs font-cairo text-gray-500">
                  {new Date(report.created_at).toLocaleString('ar-EG')}
                </td>
                <td className="px-6 py-4">
                  <ReportActions reportId={report.id} />
                </td>
              </tr>
            ))}
            {(!reports || reports.length === 0) && (
              <tr>
                <td colSpan={5} className="px-6 py-12 text-center text-gray-400 font-cairo">
                  لا توجد بلاغات جديدة
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
