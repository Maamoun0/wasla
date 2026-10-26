import 'server-only';
import { redirect } from 'next/navigation';
import { createAdminClient, createServerClient } from '@/lib/supabase/server';

export type StaffRole = 'admin' | 'moderator';

export interface Staff {
  id: string;
  role: StaffRole;
}

const BLOCKED_STATUSES = ['suspended', 'deleted'];

/**
 * Resolves the signed-in staff member, or null.
 * The session is verified with Supabase Auth (getUser, not getSession), and the
 * role is read from public.users.user_type, which clients cannot modify —
 * never from user_metadata, which users can edit themselves.
 */
export async function getStaff(allowed: StaffRole[] = ['admin', 'moderator']): Promise<Staff | null> {
  const { data: { user } } = await createServerClient().auth.getUser();
  if (!user) return null;

  const { data: profile } = await createAdminClient()
    .from('users')
    .select('user_type, status, deleted_at')
    .eq('id', user.id)
    .maybeSingle();

  if (!profile || profile.deleted_at || BLOCKED_STATUSES.includes(profile.status)) return null;
  if (!allowed.includes(profile.user_type as StaffRole)) return null;
  return { id: user.id, role: profile.user_type as StaffRole };
}

/** For pages and layouts: redirects to /login when the caller is not staff. */
export async function requireStaff(allowed?: StaffRole[]): Promise<Staff> {
  const staff = await getStaff(allowed);
  if (!staff) redirect('/login?denied=1');
  return staff;
}

export const UNAUTHORIZED = { success: false as const, error: 'غير مصرح لك بالقيام بهذا الإجراء' };
