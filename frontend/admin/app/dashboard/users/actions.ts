'use server';

import { createAdminClient } from '@/lib/supabase';
import { revalidatePath } from 'next/cache';

/**
 * Suspends or Bans a user account
 */
export async function updateUserStatusAction(
  userId: string, 
  status: 'active' | 'suspended' | 'banned',
  reason?: string
) {
  const supabase = createAdminClient();

  const { data: { user: adminUser } } = await supabase.auth.getUser();
  if (!adminUser) return { success: false, error: 'غير مصرح لك' };

  // 1. Update user status in public.users
  const { error: updateError } = await supabase
    .from('users')
    .update({ 
      status, 
      updated_at: new Date().toISOString() 
    })
    .eq('id', userId);

  if (updateError) {
    console.error('Status Update Error:', updateError);
    return { success: false, error: 'حدث خطأ أثناء تحديث حالة المستخدم' };
  }

  // 2. Log action in Audit Log
  await supabase.from('audit_logs').insert({
    actor_id: adminUser.id,
    action: `user_${status}`,
    target_type: 'user',
    target_id: userId,
    changes: { new_status: status, reason: reason || 'تحديث من لوحة الإدارة' }
  });

  // 3. Force Sign Out (Invalidate Sessions) if suspending or banning
  // Note: auth.admin requires Service Role, which our createAdminClient uses.
  if (status === 'suspended' || status === 'banned') {
    const { error: signOutError } = await supabase.auth.admin.signOut(userId);
    if (signOutError) {
      console.warn('Sign out error (non-fatal):', signOutError);
    }
  }

  revalidatePath('/dashboard/users');
  revalidatePath(`/dashboard/users/${userId}`);
  return { success: true };
}
