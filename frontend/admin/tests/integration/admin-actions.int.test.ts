// Runs the real settings and user-status server actions against a local
// Supabase stack (real database columns, real Auth bans). Only the staff
// check is stubbed. Skipped unless WASLA_SUPABASE_URL (localhost),
// WASLA_SUPABASE_ANON_KEY and WASLA_SUPABASE_SERVICE_ROLE_KEY are set.
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

const env = vi.hoisted(() => {
  const url = process.env.WASLA_SUPABASE_URL ?? '';
  const enabled = /^http:\/\/(localhost|127\.0\.0\.1)/.test(url)
    && !!process.env.WASLA_SUPABASE_ANON_KEY && !!process.env.WASLA_SUPABASE_SERVICE_ROLE_KEY;
  if (enabled) {
    process.env.NEXT_PUBLIC_SUPABASE_URL = url;
    process.env.SUPABASE_SERVICE_ROLE_KEY = process.env.WASLA_SUPABASE_SERVICE_ROLE_KEY;
  }
  return { enabled, staffId: { current: '' } };
});

vi.mock('server-only', () => ({}));
vi.mock('next/cache', () => ({ revalidatePath: vi.fn() }));
vi.mock('next/headers', () => ({ cookies: () => ({ get: () => undefined, getAll: () => [] }) }));
vi.mock('@/lib/auth', () => ({
  getStaff: async () => ({ id: env.staffId.current, role: 'admin' }),
  UNAUTHORIZED: { success: false, error: 'غير مصرح لك بالقيام بهذا الإجراء' },
}));

import { updateConfigAction } from '@/app/dashboard/settings/actions';
import { updateUserStatusAction } from '@/app/dashboard/users/actions';

const opts = { auth: { persistSession: false, autoRefreshToken: false } };
const password = 'Test-password-123!';

describe.skipIf(!env.enabled)('admin actions against local Supabase', () => {
  let admin: SupabaseClient;
  let staffId: string;
  let target: { id: string; email: string };

  const createUser = async (label: string) => {
    const email = `${label}-${crypto.randomUUID()}@test.local`;
    const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
    if (error) throw error;
    return { id: data.user.id, email };
  };
  const canSignIn = async (email: string) => {
    const { error } = await createClient(process.env.WASLA_SUPABASE_URL!, process.env.WASLA_SUPABASE_ANON_KEY!, opts)
      .auth.signInWithPassword({ email, password });
    return error ? error.message : 'ok';
  };

  beforeAll(async () => {
    admin = createClient(process.env.WASLA_SUPABASE_URL!, process.env.WASLA_SUPABASE_SERVICE_ROLE_KEY!, opts);
    staffId = (await createUser('staff')).id;
    await admin.from('users').update({ user_type: 'admin' }).eq('id', staffId);
    env.staffId.current = staffId;
    target = await createUser('target');
  });

  afterAll(async () => {
    await admin.from('app_configs').update({ value: false }).eq('key', 'maintenance_mode');
    if (target) await admin.auth.admin.deleteUser(target.id);
    if (staffId) await admin.auth.admin.deleteUser(staffId);
  });

  it('saves a setting in app_configs and audits old and new values', async () => {
    expect(await updateConfigAction('maintenance_mode', true)).toEqual({ success: true });
    const { data } = await admin.from('app_configs').select('value, updated_by').eq('key', 'maintenance_mode').single();
    expect(data).toEqual({ value: true, updated_by: staffId });

    const { data: audit } = await admin.from('audit_logs').select('changes')
      .eq('actor_id', staffId).eq('action', 'update_system_config').single();
    expect(audit?.changes).toMatchObject({ key: 'maintenance_mode', old_value: false, new_value: true });
  });

  it('banning stores status "banned" and blocks sign-in; reactivating restores it', async () => {
    expect(await canSignIn(target.email)).toBe('ok');

    expect(await updateUserStatusAction(target.id, 'banned', 'احتيال')).toEqual({ success: true });
    const { data: banned } = await admin.from('users').select('status').eq('id', target.id).single();
    expect(banned?.status).toBe('banned');
    expect(await canSignIn(target.email)).toMatch(/banned/i);

    expect(await updateUserStatusAction(target.id, 'active')).toEqual({ success: true });
    expect(await canSignIn(target.email)).toBe('ok');
  });

  it('suspension also blocks sign-in', async () => {
    expect(await updateUserStatusAction(target.id, 'suspended')).toEqual({ success: true });
    expect(await canSignIn(target.email)).toMatch(/banned/i);
    await updateUserStatusAction(target.id, 'active');
  });
});
