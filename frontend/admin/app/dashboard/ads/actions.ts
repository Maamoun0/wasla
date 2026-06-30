'use server';

import { createAdminClient } from '@/lib/supabase';
import { revalidatePath } from 'next/cache';

export async function moderateAdAction(
  adId: string, 
  action: 'approved' | 'rejected', 
  reason?: string
) {
  const supabase = createAdminClient();

  // Get current moderator session
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    return { success: false, error: 'غير مصرح لك بالقيام بهذا الإجراء' };
  }

  const { data, error } = await supabase.rpc('moderate_ad', {
    p_ad_id: adId,
    p_moderator_id: user.id,
    p_action: action,
    p_reason: reason || null,
  });

  if (error) {
    console.error('Moderation Error:', error);
    return { success: false, error: 'حدث خطأ أثناء معالجة الطلب' };
  }

  revalidatePath('/dashboard/ads');
  return data;
}
