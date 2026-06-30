'use server';

import { createAdminClient } from '@/lib/supabase';
import { revalidatePath } from 'next/cache';

export async function updateConfigAction(key: string, value: any) {
  const supabase = createAdminClient();

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { success: false, error: 'غير مصرح لك' };

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
      updated_by: user.id,
      updated_at: new Date().toISOString()
    }, { onConflict: 'config_key' });

  if (error) {
    console.error('Config Update Error:', error);
    return { success: false, error: 'حدث خطأ أثناء تحديث الإعدادات' };
  }

  // Log to general Audit Log
  await supabase.from('audit_logs').insert({
    actor_id: user.id,
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
