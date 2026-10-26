'use server';

import { createAdminClient } from '@/lib/supabase/server';
import { getStaff, UNAUTHORIZED } from '@/lib/auth';
import { revalidatePath } from 'next/cache';

// System configuration is admin-only.
export async function updateConfigAction(key: string, value: unknown) {
  const staff = await getStaff(['admin']);
  if (!staff) return UNAUTHORIZED;
  if (typeof key !== 'string' || !key.trim()) return { success: false, error: 'مفتاح غير صالح' };

  const supabase = createAdminClient();

  // 1. Fetch old value for Audit Log
  const { data: oldConfig } = await supabase
    .from('app_configs')
    .select('config_value')
    .eq('config_key', key)
    .maybeSingle();

  const { error } = await supabase
    .from('app_configs')
    .upsert({
      config_key: key,
      config_value: value,
      updated_by: staff.id,
      updated_at: new Date().toISOString()
    }, { onConflict: 'config_key' });

  if (error) {
    console.error('updateConfigAction failed:', error.code);
    return { success: false, error: 'حدث خطأ أثناء تحديث الإعدادات' };
  }

  // Log to general Audit Log
  await supabase.from('audit_logs').insert({
    actor_id: staff.id,
    action: 'update_system_config',
    target_type: 'app_config',
    changes: {
      key,
      old_value: oldConfig?.config_value,
      new_value: value
    }
  });

  revalidatePath('/dashboard/settings');
  return { success: true };
}
