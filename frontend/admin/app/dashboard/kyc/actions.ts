'use server';

import { createAdminClient } from '@/lib/supabase/server';
import { getStaff, UNAUTHORIZED } from '@/lib/auth';
import { revalidatePath } from 'next/cache';

// Bucket written by the submit-kyc-request Edge Function.
const KYC_BUCKET = 'id-documents';
const SIGNED_URL_TTL_SECONDS = 300;

const SIDE_COLUMN = {
  front: 'document_url',
  back: 'document_back_url',
  selfie: 'selfie_url',
} as const;
export type KycDocumentSide = keyof typeof SIDE_COLUMN;

export async function moderateKYCAction(
  verificationId: string,
  action: 'approved' | 'rejected',
  reason?: string
) {
  const staff = await getStaff();
  if (!staff) return UNAUTHORIZED;
  if (action !== 'approved' && action !== 'rejected') return { success: false, error: 'إجراء غير صالح' };

  const { data, error } = await createAdminClient().rpc('moderate_kyc', {
    p_verification_id: verificationId,
    p_moderator_id: staff.id,
    p_action: action,
    p_reason: reason?.trim() || null,
  });

  if (error) {
    console.error('moderateKYCAction failed:', error.code);
    return { success: false, error: 'حدث خطأ أثناء معالجة التوثيق' };
  }

  revalidatePath('/dashboard/kyc');
  return data;
}

/**
 * Short-lived signed URL for one identity document.
 * The caller names a verification and a side; the storage path is read from
 * the verification row, so no arbitrary object in the bucket can be requested.
 * Every issued URL is written to audit_logs.
 */
export async function getKycDocumentUrl(
  verificationId: string,
  side: KycDocumentSide
): Promise<{ success: true; url: string } | { success: false; error: string }> {
  const staff = await getStaff();
  if (!staff) return UNAUTHORIZED;

  const column = SIDE_COLUMN[side];
  if (!column) return { success: false, error: 'مستند غير صالح' };

  const supabase = createAdminClient();
  const { data: verification } = await supabase
    .from('user_verifications')
    .select(`id, user_id, ${column}`)
    .eq('id', verificationId)
    .maybeSingle();

  const path = (verification as Record<string, string | null> | null)?.[column];
  if (!verification || !path) return { success: false, error: 'المستند غير موجود' };

  const { data, error } = await supabase.storage.from(KYC_BUCKET).createSignedUrl(path, SIGNED_URL_TTL_SECONDS);
  if (error || !data) {
    console.error('getKycDocumentUrl: signed URL failed');
    return { success: false, error: 'فشل جلب الرابط الآمن للصورة' };
  }

  await supabase.from('audit_logs').insert({
    actor_id: staff.id,
    action: 'kyc_document_viewed',
    target_type: 'user_verification',
    target_id: verification.id,
    changes: { side, subject_user_id: verification.user_id, ttl_seconds: SIGNED_URL_TTL_SECONDS },
  });

  return { success: true, url: data.signedUrl };
}
