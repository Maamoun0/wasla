import { createAdminClient } from '@/lib/supabase/server';
import { requireStaff } from '@/lib/auth';
import { Settings, Save, ShieldAlert, BadgePercent, Zap } from 'lucide-react';
import ConfigForm from '@/components/ConfigForm';

export default async function SettingsPage() {
  await requireStaff(['admin']);
  const supabase = createAdminClient();

  // Fetch current configs
  const { data: configs } = await supabase
    .from('app_configs')
    .select('*');

  // Helper to get config value
  const getConfig = (key: string) => configs?.find(c => c.key === key)?.value;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold font-cairo text-gray-800 flex items-center gap-2">
          <Settings className="text-gray-600" />
          <span>إعدادات المنصة</span>
        </h1>
        <p className="text-gray-500 font-cairo text-sm mt-1">التحكم في المعايير المالية والتقنية لمنصة وصلة</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {/* Monetization Section */}
        <div className="bg-white p-6 rounded-xl border border-gray-100 shadow-sm space-y-6">
          <div className="flex items-center gap-2 border-b pb-4">
            <BadgePercent className="text-blue-600" />
            <h2 className="font-bold font-cairo text-gray-800">إعدادات الأرباح (Monetization)</h2>
          </div>
          
          {/* Boost and subscription prices live in payment_packages (charged by create-payment). */}
          <ConfigForm 
            configKey="enable_boost_feature" 
            label="تفعيل ميزة الترويج (Boost)" 
            initialValue={getConfig('enable_boost_feature') ?? true} 
            type="boolean"
          />
        </div>

        {/* Safety & AI Section */}
        <div className="bg-white p-6 rounded-xl border border-gray-100 shadow-sm space-y-6">
          <div className="flex items-center gap-2 border-b pb-4">
            <ShieldAlert className="text-orange-600" />
            <h2 className="font-bold font-cairo text-gray-800">الأمان والذكاء الاصطناعي</h2>
          </div>
          
          <ConfigForm 
            configKey="ai_moderation_enabled" 
            label="تفعيل المراجعة التلقائية (AI)" 
            initialValue={getConfig('ai_moderation_enabled') ?? true} 
            type="boolean"
          />

          <ConfigForm 
            configKey="enable_kyc_verification" 
            label="تفعيل نظام توثيق الهوية (KYC)" 
            initialValue={getConfig('enable_kyc_verification') ?? true} 
            type="boolean"
          />

          <ConfigForm 
            configKey="maintenance_mode" 
            label="وضع الصيانة (Maintenance Mode)" 
            initialValue={getConfig('maintenance_mode') ?? false} 
            type="boolean"
          />

          <ConfigForm 
            configKey="min_trust_score_to_post" 
            label="الحد الأدنى لمؤشر الثقة للنشر" 
            initialValue={getConfig('min_trust_score_to_post') ?? 0} 
            type="number"
          />
        </div>
      </div>

      <div className="p-4 bg-gray-50 border border-gray-200 rounded-lg flex items-start gap-3">
        <Zap className="text-yellow-600 mt-1" size={20} />
        <div className="text-xs font-cairo text-gray-600 leading-relaxed">
          تنبيه: التعديلات هنا تؤثر فوراً على جميع المستخدمين في التطبيق. يتم تسجيل كل عملية تغيير في سجل التدقيق لأغراض الرقابة المالية.
        </div>
      </div>
    </div>
  );
}
