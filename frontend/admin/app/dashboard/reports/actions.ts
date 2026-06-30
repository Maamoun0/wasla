'use server';

import { createAdminClient } from '@/lib/supabase';
import { revalidatePath } from 'next/cache';

export async function handleReportAction(
  reportId: string, 
  status: 'resolved' | 'dismissed', 
  actionTaken?: string
) {
  const supabase = createAdminClient();

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { success: false, error: 'غير مصرح لك' };

  const { data, error } = await supabase.rpc('handle_report', {
    p_report_id: reportId,
    p_moderator_id: user.id,
    p_status: status,
    p_action_taken: actionTaken || null,
  });

  if (error) {
    console.error('Report Handling Error:', error);
    return { success: false, error: 'حدث خطأ أثناء معالجة البلاغ' };
  }

  revalidatePath('/dashboard/reports');
  return data;
}
