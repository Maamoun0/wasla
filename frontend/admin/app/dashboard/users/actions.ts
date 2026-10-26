'use server';

import { createAdminClient } from '@/lib/supabase/server';
import { getStaff, UNAUTHORIZED } from '@/lib/auth';
import { revalidatePath } from 'next/cache';

const STATUSES = ['active', 'suspended', 'banned'] as const;

/**
 * Suspends or Bans a user account.
 * Moderators may act on regular accounts only; staff accounts need an admin.
 */
export async function updateUserStatusAction(
  userId: string,
  status: 'active' | 'suspended' | 'banned',
  reason?: string
) {
  const staff = await getStaff();
  if (!staff) return UNAUTHORIZED;
  if (!STATUSES.includes(status)) return { success: false, error: 'حالة غير صالحة' };
  if (userId === staff.id) return { success: false, error: 'لا يمكنك تغيير حالة حسابك' };

  const supabase = createAdminClient();

  const { data: target } = await supabase.from('users').select('user_type').eq('id', userId).maybeSingle();
  if (!target) return { success: false, error: 'المستخدم غير موجود' };
  if (staff.role !== 'admin' && (target.user_type === 'admin' || target.user_type === 'moderator')) {
    return UNAUTHORIZED;
  }

  // 1. Update user status in public.users
  const { error: updateError } = await supabase
    .from('users')
    .update({
      status,
      updated_at: new Date().toISOString()
    })
    .eq('id', userId);

  if (updateError) {
    console.error('updateUserStatusAction failed:', updateError.code);
    return { success: false, error: 'حدث خطأ أثناء تحديث حالة المستخدم' };
  }

  // 2. Log action in Audit Log
  await supabase.from('audit_logs').insert({
    actor_id: staff.id,
    action: `user_${status}`,
    target_type: 'user',
    target_id: userId,
    changes: { new_status: status, reason: reason || 'تحديث من لوحة الإدارة' }
  });

  // 3. Block or restore sign-in in Supabase Auth. A ban stops new sign-ins and
  // token refreshes; an already-issued access token expires within the hour.
  const { error: banError } = await supabase.auth.admin.updateUserById(userId, {
    ban_duration: status === 'active' ? 'none' : '876000h',
  });
  if (banError) {
    console.error('updateUserStatusAction: auth ban failed:', banError.status);
    return { success: false, error: 'تم تحديث الحالة لكن تعذّر تطبيقها على تسجيل الدخول' };
  }

  revalidatePath('/dashboard/users');
  revalidatePath(`/dashboard/users/${userId}`);
  return { success: true };
}
