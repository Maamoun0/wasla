import { ReactNode } from 'react';
import Link from 'next/link';
import { 
  LayoutDashboard, 
  ClipboardList, 
  UserCheck, 
  AlertCircle, 
  Users, 
  Settings, 
  LogOut 
} from 'lucide-react';
import { requireStaff } from '@/lib/auth';

// Every dashboard request is per-user and access-checked; never prerender.
export const dynamic = 'force-dynamic';

export default async function DashboardLayout({ children }: { children: ReactNode }) {
  await requireStaff();

  const menuItems = [
    { name: 'الرئيسية', icon: LayoutDashboard, href: '/dashboard' },
    { name: 'مراجعة الإعلانات', icon: ClipboardList, href: '/dashboard/ads' },
    { name: 'توثيق الهوية', icon: UserCheck, href: '/dashboard/kyc' },
    { name: 'البلاغات', icon: AlertCircle, href: '/dashboard/reports' },
    { name: 'المستخدمين', icon: Users, href: '/dashboard/users' },
    { name: 'الإعدادات', icon: Settings, href: '/dashboard/settings' },
  ];

  return (
    <div className="flex min-h-screen bg-gray-50" dir="rtl">
      {/* Sidebar */}
      <aside className="w-64 bg-slate-900 text-white flex flex-col fixed inset-y-0 right-0">
        <div className="p-6 text-center border-b border-slate-800">
          <h1 className="text-2xl font-bold font-cairo text-blue-400">وصلة Admin</h1>
        </div>
        
        <nav className="flex-1 p-4 space-y-2 mt-4">
          {menuItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="flex items-center space-x-3 space-x-reverse p-3 rounded-lg hover:bg-slate-800 transition-colors font-cairo text-sm"
            >
              <item.icon size={20} />
              <span>{item.name}</span>
            </Link>
          ))}
        </nav>

        <div className="p-4 border-t border-slate-800">
          <button className="flex items-center space-x-3 space-x-reverse p-3 w-full rounded-lg hover:bg-red-900/20 text-red-400 transition-colors font-cairo text-sm">
            <LogOut size={20} />
            <span>تسجيل الخروج</span>
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 mr-64 p-8">
        {children}
      </main>
    </div>
  );
}
