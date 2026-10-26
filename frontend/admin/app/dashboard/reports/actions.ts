'use server';

import { createAdminClient } from '@/lib/supabase/server';
import { getStaff, UNAUTHORIZED } from '@/lib/auth';
import { revalidatePath } from 'next/cache';

export async function handleReportAction(
  reportId: string,
  status: 'resolved' | 'dismissed',
  actionTaken?: string
) {
  const staff = await getStaff();
  if (!staff) return UNAUTHORIZED;
  if (status !== 'resolved' && status !== 'dismissed') return { success: false, error: 'إجراء غير صالح' };

  const { data, error } = await createAdminClient().rpc('handle_report', {
    p_report_id: reportId,
    p_moderator_id: staff.id,
    p_status: status,
    p_action_taken: actionTaken?.trim() || null,
  });

  if (error) {
    console.error('handleReportAction failed:', error.code);
    return { success: false, error: 'حدث خطأ أثناء معالجة البلاغ' };
  }

  revalidatePath('/dashboard/reports');
  return data;
}
