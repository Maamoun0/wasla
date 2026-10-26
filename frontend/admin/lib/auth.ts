import 'server-only';
import { redirect } from 'next/navigation';
import { createAdminClient, createServerClient } from '@/lib/supabase/server';

export type StaffRole = 'admin' | 'moderator';

export interface Staff {
  id: string;
  role: StaffRole;
}

type StaffCheck =
  | { kind: 'staff'; staff: Staff }
  | { kind: 'needs_mfa' }
  | { kind: 'denied' };

const BLOCKED_STATUSES = ['suspended', 'banned', 'deleted'];

/**
 * The session is verified with Supabase Auth (getUser, not getSession), the
 * role is read from public.users.user_type, which clients cannot modify —
 * never from user_metadata — and every staff session must have completed
 * TOTP (assurance level aal2).
 */
async function checkStaff(allowed: StaffRole[]): Promise<StaffCheck> {
  const supabase = createServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { kind: 'denied' };

  const { data: profile } = await createAdminClient()
    .from('users')
    .select('user_type, status, deleted_at')
    .eq('id', user.id)
    .maybeSingle();

  if (!profile || profile.deleted_at || BLOCKED_STATUSES.includes(profile.status)) return { kind: 'denied' };
  if (!allowed.includes(profile.user_type as StaffRole)) return { kind: 'denied' };

  const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (aal?.currentLevel !== 'aal2') return { kind: 'needs_mfa' };

  return { kind: 'staff', staff: { id: user.id, role: profile.user_type as StaffRole } };
}

/** Resolves the signed-in, MFA-verified staff member, or null. */
export async function getStaff(allowed: StaffRole[] = ['admin', 'moderator']): Promise<Staff | null> {
  const result = await checkStaff(allowed);
  return result.kind === 'staff' ? result.staff : null;
}

/** For pages and layouts: sends non-staff to /login and staff without TOTP to the MFA step. */
export async function requireStaff(allowed: StaffRole[] = ['admin', 'moderator']): Promise<Staff> {
  const result = await checkStaff(allowed);
  if (result.kind === 'needs_mfa') redirect('/login?mfa=1');
  if (result.kind !== 'staff') redirect('/login?denied=1');
  return result.staff;
}

export const UNAUTHORIZED = { success: false as const, error: 'غير مصرح لك بالقيام بهذا الإجراء' };
