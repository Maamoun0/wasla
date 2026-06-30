'use server';

import { createAdminClient } from '@/lib/supabase';
import { revalidatePath } from 'next/cache';

export async function moderateKYCAction(
  verificationId: string, 
  action: 'approved' | 'rejected', 
  reason?: string
) {
  const supabase = createAdminClient();

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { success: false, error: 'غير مصرح لك' };

  const { data, error } = await supabase.rpc('moderate_kyc', {
    p_verification_id: verificationId,
    p_moderator_id: user.id,
    p_action: action,
    p_reason: reason || null,
  });

  if (error) {
    console.error('KYC Moderation Error:', error);
    return { success: false, error: 'حدث خطأ أثناء معالجة التوثيق' };
  }

  revalidatePath('/dashboard/kyc');
  return data;
}

export async function getSignedUrl(path: string) {
  const supabase = createAdminClient();
  
  // path example: 'kyc-documents/user-id/id-front.jpg'
  // Assuming 'kyc-documents' is the bucket name
  const { data, error } = await supabase
    .storage
    .from('kyc-documents')
    .createSignedUrl(path, 300); // 5 minutes validity

  if (error) {
    console.error('Storage Error:', error);
    return null;
  }

  return data.signedUrl;
}
