import { createAdminClient } from '@/lib/supabase';
import { 
  Activity, 
  MapPin, 
  Calendar, 
  Phone, 
  Shield, 
  AlertTriangle 
} from 'lucide-react';
import { notFound } from 'next/navigation';
import UserStatusActions from '@/components/UserStatusActions';

export default async function UserActivityPage({
  params,
}: {
  params: { id: string };
}) {
  const supabase = createAdminClient();

  // Fetch user profile and logs
  const [userResponse, logsResponse] = await Promise.all([
    supabase.from('users').select('*').eq('id', params.id).single(),
    supabase.from('user_activity_log')
      .select('*')
      .eq('user_id', params.id)
      .order('created_at', { ascending: false })
      .limit(50)
  ]);

  const user = userResponse.data;
  const logs = logsResponse.data;

  if (!user) notFound();

  const getActionColor = (type: string) => {
    switch (type) {
      case 'payment_completed': return 'text-green-600 bg-green-50';
      case 'payment_attempted': return 'text-blue-600 bg-blue-50';
      case 'ad_published': return 'text-purple-600 bg-purple-50';
      case 'otp_requested': return 'text-orange-600 bg-orange-50';
      case 'account_deletion_requested': return 'text-red-600 bg-red-50';
      default: return 'text-gray-600 bg-gray-50';
    }
  };

  return (
    <div className="space-y-8">
      {/* User Header Card */}
      <div className="bg-white p-8 rounded-2xl border border-gray-100 shadow-sm flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
        <div className="flex items-center gap-6">
          <div className="w-20 h-20 bg-blue-600 rounded-full flex items-center justify-center text-white text-3xl font-bold">
            {user.full_name?.charAt(0) || 'U'}
          </div>
          <div className="space-y-1">
            <h1 className="text-2xl font-bold font-cairo text-gray-900">{user.full_name}</h1>
            <div className="flex items-center gap-4 text-sm text-gray-500 font-cairo">
              <span className="flex items-center gap-1"><Phone size={14} /> {user.phone}</span>
              <span className="flex items-center gap-1"><Shield size={14} /> ثقة: {user.trust_score}</span>
            </div>
          </div>
        </div>
        
        <div className="flex flex-wrap gap-3">
          <span className={`px-4 py-2 rounded-lg text-sm font-bold font-cairo ${
            user.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
          }`}>
            الحالة: {user.status}
          </span>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Activity Timeline */}
        <div className="lg:col-span-2 space-y-4">
          <h2 className="text-lg font-bold font-cairo text-gray-800 flex items-center gap-2">
            <Activity size={20} className="text-blue-600" />
            سجل النشاط الأخير
          </h2>
          
          <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
            {logs && logs.length > 0 ? (
              <div className="divide-y divide-gray-50">
                {logs.map((log: any) => (
                  <div key={log.id} className="p-4 hover:bg-gray-50/50 transition-colors flex justify-between items-center">
                    <div className="flex items-start gap-4">
                      <div className={`mt-1 p-2 rounded-full ${getActionColor(log.action_type)}`}>
                        <Activity size={16} />
                      </div>
                      <div>
                        <p className="text-sm font-bold font-cairo text-gray-900">
                          {log.action_type.replace(/_/g, ' ')}
                        </p>
                        <p className="text-xs text-gray-500 font-mono">{log.ip_address}</p>
                        {log.metadata && Object.keys(log.metadata).length > 0 && (
                          <pre className="text-[10px] mt-2 bg-gray-50 p-2 rounded border text-gray-600 overflow-x-auto max-w-xs md:max-w-md">
                            {JSON.stringify(log.metadata, null, 2)}
                          </pre>
                        )}
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-xs text-gray-400 font-cairo">
                        {new Date(log.created_at).toLocaleString('ar-EG')}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="p-12 text-center text-gray-400 font-cairo">
                لا يوجد سجل نشاط متاح لهذا المستخدم حالياً
              </div>
            )}
          </div>
        </div>

        {/* User Sidebar Details */}
        <div className="space-y-6">
          <div className="bg-white p-6 rounded-xl border border-gray-100 shadow-sm space-y-4">
            <h3 className="font-bold font-cairo text-gray-800 border-b pb-2">معلومات الحساب</h3>
            <div className="space-y-3">
              <div className="flex justify-between text-sm font-cairo">
                <span className="text-gray-500">تاريخ التسجيل</span>
                <span className="text-gray-900 font-mono">{new Date(user.created_at).toLocaleDateString()}</span>
              </div>
              <div className="flex justify-between text-sm font-cairo">
                <span className="text-gray-500">آخر تحديث</span>
                <span className="text-gray-900 font-mono">{new Date(user.updated_at).toLocaleDateString()}</span>
              </div>
            </div>
          </div>

          <div className="bg-orange-50 p-6 rounded-xl border border-orange-100 space-y-3">
             <div className="flex items-center gap-2 text-orange-800 font-bold font-cairo">
               <AlertTriangle size={18} />
               <span>منطقة الخطر</span>
             </div>
             <p className="text-xs text-orange-700 font-cairo">الإجراءات هنا لا يمكن التراجع عنها وتؤثر فوراً على وصول المستخدم للتطبيق.</p>
             <UserStatusActions userId={user.id} currentStatus={user.status} />
          </div>
        </div>
      </div>
    </div>
  );
}
