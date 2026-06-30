import { createAdminClient } from '@/lib/supabase';
import { 
  User, 
  Search, 
  Ban, 
  ShieldCheck, 
  ShieldAlert,
  Activity
} from 'lucide-react';
import Link from 'next/link';

export default async function UsersPage({
  searchParams,
}: {
  searchParams: { q?: string };
}) {
  const supabase = createAdminClient();
  const query = searchParams.q || '';

  let usersQuery = supabase
    .from('users')
    .select(`
      id,
      full_name,
      phone,
      email,
      status,
      trust_score,
      created_at,
      ads (count),
      reports:reports!reports_target_id_fkey (count)
    `)
    .eq('reports.target_type', 'user');

  if (query) {
    usersQuery = usersQuery.or(`full_name.ilike.%${query}%,phone.ilike.%${query}%`);
  }

  const { data: users } = await usersQuery.limit(20);

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold font-cairo text-gray-800">إدارة المستخدمين</h1>
          <p className="text-gray-500 font-cairo text-sm mt-1">البحث عن المستخدمين وإدارة صلاحياتهم وحالاتهم</p>
        </div>
      </div>

      {/* Search Bar */}
      <div className="bg-white p-4 rounded-xl border border-gray-100 shadow-sm">
        <form className="relative">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
          <input
            type="text"
            name="q"
            defaultValue={query}
            placeholder="البحث بالاسم أو رقم الهاتف..."
            className="w-full pr-10 pl-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none font-cairo text-sm"
          />
        </form>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        <table className="w-full text-right" dir="rtl">
          <thead className="bg-gray-50 border-b border-gray-100">
            <tr>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">المستخدم</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">الحالة</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">الثقة (Trust)</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">النشاط</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">تاريخ التسجيل</th>
              <th className="px-6 py-4 text-sm font-bold font-cairo text-gray-600">الإجراءات</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {users?.map((user: any) => (
              <tr key={user.id} className="hover:bg-gray-50/50 transition-colors">
                <td className="px-6 py-4">
                  <div className="font-cairo text-sm font-bold text-gray-900">{user.full_name || 'بدون اسم'}</div>
                  <div className="font-cairo text-xs text-gray-500">{user.phone}</div>
                </td>
                <td className="px-6 py-4">
                  <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-bold font-cairo ${
                    user.status === 'active' ? 'bg-green-50 text-green-700' : 
                    user.status === 'suspended' ? 'bg-orange-50 text-orange-700' :
                    'bg-red-50 text-red-700'
                  }`}>
                    {user.status === 'active' ? 'نشط' : 
                     user.status === 'suspended' ? 'معلق' :
                     user.status === 'banned' ? 'محظور' : user.status}
                  </span>
                </td>
                <td className="px-6 py-4">
                  <div className="flex items-center gap-1">
                    <ShieldCheck size={14} className={user.trust_score >= 80 ? 'text-green-500' : 'text-gray-300'} />
                    <span className="text-sm font-bold font-mono">{user.trust_score}</span>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <div className="text-xs font-cairo text-gray-600">الإعلانات: {user.ads?.[0]?.count ?? 0}</div>
                  <div className="text-xs font-cairo text-red-500">البلاغات: {user.reports?.[0]?.count ?? 0}</div>
                </td>
                <td className="px-6 py-4 text-xs font-cairo text-gray-500">
                  {new Date(user.created_at).toLocaleDateString('ar-EG')}
                </td>
                <td className="px-6 py-4">
                  <div className="flex items-center gap-2">
                    <Link 
                      href={`/dashboard/users/${user.id}`}
                      className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                      title="سجل النشاط"
                    >
                      <Activity size={18} />
                    </Link>
                    <button className="p-2 text-orange-600 hover:bg-orange-50 rounded-lg transition-colors" title="تعليق">
                      <ShieldAlert size={18} />
                    </button>
                    <button className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors" title="حظر">
                      <Ban size={18} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
