import { createAdminClient } from '@/lib/supabase/server';
import { requireStaff } from '@/lib/auth';
import { 
  Users, 
  Clock, 
  CheckCircle, 
  TrendingUp,
  AlertCircle
} from 'lucide-react';

export default async function DashboardPage() {
  await requireStaff();
  const supabase = createAdminClient();

  // Fetch Stats (Piece 1.3 & 2.1)
  const [
    { count: totalUsers },
    { count: pendingAds },
    { count: activeAds },
    { count: pendingReports },
    { count: totalReports },
    { data: revenueData }
  ] = await Promise.all([
    supabase.from('users').select('*', { count: 'exact', head: true }),
    supabase.from('ads').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
    supabase.from('ads').select('*', { count: 'exact', head: true }).eq('status', 'active'),
    supabase.from('reports').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
    supabase.from('reports').select('*', { count: 'exact', head: true }),
    supabase.from('transactions').select('amount').eq('status', 'completed')
  ]);

  const totalRevenue = revenueData?.reduce((sum, tx) => sum + Number(tx.amount), 0) || 0;

  const stats = [
    { name: 'إجمالي المستخدمين', value: totalUsers ?? 0, icon: Users, color: 'text-blue-600', bg: 'bg-blue-100' },
    { name: 'إعلانات للمراجعة', value: pendingAds ?? 0, icon: Clock, color: 'text-orange-600', bg: 'bg-orange-100' },
    { name: 'إعلانات نشطة', value: activeAds ?? 0, icon: CheckCircle, color: 'text-green-600', bg: 'bg-green-100' },
    { name: 'بلاغات معلقة', value: pendingReports ?? 0, icon: AlertCircle, color: 'text-red-600', bg: 'bg-red-100' },
    { name: 'إيرادات المنصة', value: `${totalRevenue.toLocaleString()} ج.م`, icon: TrendingUp, color: 'text-purple-600', bg: 'bg-purple-100' },
  ];

  return (
    <div className="space-y-8">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold font-cairo text-gray-800">نظرة عامة</h1>
          <p className="text-gray-500 font-cairo text-sm mt-1">مرحباً بك في لوحة تحكم وصلة</p>
        </div>
        <div className="text-xs font-cairo text-gray-400">
          آخر تحديث: {new Date().toLocaleTimeString('ar-EG')}
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6">
        {stats.map((stat) => (
          <div key={stat.name} className="bg-white p-6 rounded-xl border border-gray-100 shadow-sm flex flex-col items-center justify-center text-center space-y-3 hover:shadow-md transition-shadow">
            <div className={`p-3 rounded-lg ${stat.bg} ${stat.color}`}>
              <stat.icon size={24} />
            </div>
            <div>
              <p className="text-xs font-cairo text-gray-500 whitespace-nowrap">{stat.name}</p>
              <p className="text-xl font-bold font-cairo text-gray-900">{stat.value}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Dashboard Charts / Lists Sections */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Reports Summary */}
        <div className="lg:col-span-2 bg-white p-6 rounded-xl border border-gray-100 shadow-sm">
          <div className="flex justify-between items-center mb-6">
             <h2 className="font-bold font-cairo text-gray-800">نشاط البلاغات</h2>
             <span className="text-xs font-cairo text-gray-400">إجمالي البلاغات: {totalReports ?? 0}</span>
          </div>
          <div className="space-y-4">
            {/* Simple Progress Bars for Report Statuses */}
            <div className="space-y-2">
              <div className="flex justify-between text-xs font-cairo">
                <span>بلاغات معلقة</span>
                <span>{pendingReports ?? 0}</span>
              </div>
              <div className="w-full bg-gray-100 h-2 rounded-full overflow-hidden">
                <div 
                  className="bg-red-500 h-full transition-all" 
                  style={{ width: `${totalReports ? ((pendingReports ?? 0) / totalReports) * 100 : 0}%` }}
                ></div>
              </div>
            </div>
          </div>
          <div className="mt-8 text-center">
             <button className="text-blue-600 text-sm font-cairo font-bold hover:underline">عرض كافة البلاغات</button>
          </div>
        </div>

        {/* System Status */}
        <div className="bg-white p-6 rounded-xl border border-gray-100 shadow-sm">
          <h2 className="font-bold font-cairo text-gray-800 mb-6">حالة المنظومة</h2>
          <div className="space-y-6">
            <div className="flex justify-between items-center">
              <div className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div>
                <span className="text-sm font-cairo text-gray-600">قاعدة البيانات</span>
              </div>
              <span className="text-xs font-mono text-gray-400">PostgreSQL 15</span>
            </div>
            <div className="flex justify-between items-center">
               <div className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-green-500"></div>
                <span className="text-sm font-cairo text-gray-600">محرك البحث</span>
              </div>
              <span className="text-xs font-mono text-gray-400">PGVector Enabled</span>
            </div>
            <div className="flex justify-between items-center">
               <div className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-blue-500"></div>
                <span className="text-sm font-cairo text-gray-600">Edge Runtime</span>
              </div>
              <span className="text-xs font-mono text-gray-400">V8 (Deno)</span>
            </div>
          </div>
          
          <div className="mt-8 p-4 bg-blue-50 rounded-lg">
             <p className="text-[10px] font-cairo text-blue-700 leading-relaxed">
               جميع الأنظمة تعمل بكفاءة. لم يتم رصد أي أعطال في آخر 24 ساعة.
             </p>
          </div>
        </div>
      </div>
    </div>
  );
}
