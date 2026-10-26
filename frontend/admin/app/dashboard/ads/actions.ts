'use server';

import { createAdminClient } from '@/lib/supabase/server';
import { getStaff, UNAUTHORIZED } from '@/lib/auth';
import { revalidatePath } from 'next/cache';

const ACTIONS = ['approved', 'rejected'] as const;

export async function moderateAdAction(
  adId: string,
  action: 'approved' | 'rejected',
  reason?: string
) {
  const staff = await getStaff();
  if (!staff) return UNAUTHORIZED;
  if (!ACTIONS.includes(action)) return { success: false, error: 'إجراء غير صالح' };
  if (action === 'rejected' && !reason?.trim()) return { success: false, error: 'يجب تحديد سبب الرفض' };

  // The moderator is always the signed-in staff member, never a client-supplied id.
  const { data, error } = await createAdminClient().rpc('moderate_ad', {
    p_ad_id: adId,
    p_moderator_id: staff.id,
    p_action: action,
    p_reason: reason?.trim() || null,
  });

  if (error) {
    console.error('moderateAdAction failed:', error.code);
    return { success: false, error: 'حدث خطأ أثناء معالجة الطلب' };
  }

  revalidatePath('/dashboard/ads');
  return data;
}
