import { beforeEach, describe, expect, it, vi } from 'vitest';
import { adminClient, resetState, serverClient, signInAs, state } from './fakes';

vi.mock('server-only', () => ({}));
vi.mock('next/cache', () => ({ revalidatePath: vi.fn() }));
vi.mock('next/navigation', () => ({
  redirect: (url: string) => {
    throw new Error(`REDIRECT:${url}`);
  },
}));
vi.mock('@/lib/supabase/server', () => ({
  createAdminClient: () => adminClient,
  createServerClient: () => serverClient,
}));

import { getStaff, requireStaff, UNAUTHORIZED } from '@/lib/auth';
import { getKycDocumentUrl, moderateKYCAction } from '@/app/dashboard/kyc/actions';
import { moderateAdAction } from '@/app/dashboard/ads/actions';
import { handleReportAction } from '@/app/dashboard/reports/actions';
import { updateUserStatusAction } from '@/app/dashboard/users/actions';
import { updateConfigAction } from '@/app/dashboard/settings/actions';

const MOD = 'mod-1';
const ADMIN = 'admin-1';
const USER = 'user-1';

beforeEach(() => {
  resetState();
  adminClient.rpc.mockClear();
  state.tables.user_verifications = [
    { id: 'ver-1', user_id: USER, document_url: `${USER}/kyc/1/front.jpg`, document_back_url: `${USER}/kyc/1/back.jpg`, selfie_url: null },
  ];
});

describe('getStaff / requireStaff', () => {
  it('rejects a request with no session', async () => {
    expect(await getStaff()).toBeNull();
    await expect(requireStaff()).rejects.toThrow('REDIRECT:/login?denied=1');
  });

  it('rejects a regular user', async () => {
    signInAs(USER, { user_type: 'regular', status: 'active' });
    expect(await getStaff()).toBeNull();
  });

  it('ignores a self-assigned admin role in user_metadata', async () => {
    signInAs(USER, { user_type: 'regular', status: 'active' }, { role: 'admin' });
    expect(await getStaff()).toBeNull();
  });

  it('rejects suspended or deleted staff', async () => {
    signInAs(MOD, { user_type: 'moderator', status: 'suspended' });
    expect(await getStaff()).toBeNull();
    signInAs(MOD, { user_type: 'moderator', status: 'active', deleted_at: '2026-01-01' });
    expect(await getStaff()).toBeNull();
  });

  it('accepts an active moderator, but not for admin-only areas', async () => {
    signInAs(MOD, { user_type: 'moderator', status: 'pending_verification' });
    expect(await getStaff()).toEqual({ id: MOD, role: 'moderator' });
    expect(await getStaff(['admin'])).toBeNull();
  });
});

describe('getKycDocumentUrl', () => {
  it('refuses anonymous callers without touching storage', async () => {
    expect(await getKycDocumentUrl('ver-1', 'front')).toEqual(UNAUTHORIZED);
    expect(state.signedUrls).toHaveLength(0);
  });

  it('refuses regular users', async () => {
    signInAs(USER, { user_type: 'regular', status: 'active' });
    expect(await getKycDocumentUrl('ver-1', 'front')).toEqual(UNAUTHORIZED);
    expect(state.signedUrls).toHaveLength(0);
  });

  it('signs only the path stored on the verification, for 5 minutes, and audits it', async () => {
    signInAs(MOD, { user_type: 'moderator', status: 'active' });
    const res = await getKycDocumentUrl('ver-1', 'back');
    expect(res.success).toBe(true);
    expect(state.signedUrls).toEqual([{ bucket: 'id-documents', path: `${USER}/kyc/1/back.jpg`, ttl: 300 }]);
    expect(state.inserts).toContainEqual({
      table: 'audit_logs',
      row: expect.objectContaining({ actor_id: MOD, action: 'kyc_document_viewed', target_id: 'ver-1' }),
    });
  });

  it('returns an error for an unknown verification or a missing side', async () => {
    signInAs(MOD, { user_type: 'moderator', status: 'active' });
    expect((await getKycDocumentUrl('nope', 'front')).success).toBe(false);
    expect((await getKycDocumentUrl('ver-1', 'selfie')).success).toBe(false);
    expect((await getKycDocumentUrl('ver-1', '../../other' as never)).success).toBe(false);
    expect(state.signedUrls).toHaveLength(0);
  });
});

describe('moderation actions', () => {
  it('refuse non-staff and never reach the RPC', async () => {
    signInAs(USER, { user_type: 'regular', status: 'active' });
    expect(await moderateAdAction('ad-1', 'approved')).toEqual(UNAUTHORIZED);
    expect(await moderateKYCAction('ver-1', 'approved')).toEqual(UNAUTHORIZED);
    expect(await handleReportAction('rep-1', 'resolved')).toEqual(UNAUTHORIZED);
    expect(adminClient.rpc).not.toHaveBeenCalled();
  });

  it('use the session staff id as the moderator', async () => {
    signInAs(MOD, { user_type: 'moderator', status: 'active' });
    await moderateAdAction('ad-1', 'approved');
    await moderateKYCAction('ver-1', 'rejected', 'صورة غير واضحة');
    await handleReportAction('rep-1', 'dismissed');
    expect(state.rpcCalls.map((c) => c.args.p_moderator_id)).toEqual([MOD, MOD, MOD]);
  });

  it('reject unknown actions and rejections without a reason', async () => {
    signInAs(MOD, { user_type: 'moderator', status: 'active' });
    expect((await moderateAdAction('ad-1', 'flagged' as never)).success).toBe(false);
    expect((await moderateAdAction('ad-1', 'rejected', '  ')).success).toBe(false);
    expect(adminClient.rpc).not.toHaveBeenCalled();
  });
});

describe('updateUserStatusAction', () => {
  beforeEach(() => {
    state.tables.users = [
      { id: USER, user_type: 'regular', status: 'active', deleted_at: null },
      { id: ADMIN, user_type: 'admin', status: 'active', deleted_at: null },
    ];
  });

  it('refuses non-staff', async () => {
    signInAs('other', { user_type: 'regular', status: 'active' });
    expect(await updateUserStatusAction(USER, 'suspended')).toEqual(UNAUTHORIZED);
    expect(state.updates).toHaveLength(0);
  });

  it('lets a moderator suspend a regular user, audited with the moderator id', async () => {
    signInAs(MOD, { user_type: 'moderator', status: 'active' });
    expect(await updateUserStatusAction(USER, 'suspended')).toEqual({ success: true });
    expect(state.updates[0]).toMatchObject({ table: 'users', values: { status: 'suspended' }, filters: { id: USER } });
    expect(state.inserts).toContainEqual({ table: 'audit_logs', row: expect.objectContaining({ actor_id: MOD }) });
    expect(state.signOuts).toEqual([USER]);
  });

  it('does not let a moderator act on an admin, or anyone act on themselves', async () => {
    signInAs(MOD, { user_type: 'moderator', status: 'active' });
    expect(await updateUserStatusAction(ADMIN, 'suspended')).toEqual(UNAUTHORIZED);
    expect((await updateUserStatusAction(MOD, 'suspended')).success).toBe(false);
    expect(state.updates).toHaveLength(0);
  });

  it('rejects unknown statuses', async () => {
    signInAs(ADMIN, { user_type: 'admin', status: 'active' });
    expect((await updateUserStatusAction(USER, 'superuser' as never)).success).toBe(false);
  });
});

describe('updateConfigAction', () => {
  it('is admin-only', async () => {
    signInAs(MOD, { user_type: 'moderator', status: 'active' });
    expect(await updateConfigAction('maintenance_mode', true)).toEqual(UNAUTHORIZED);
    expect(state.inserts).toHaveLength(0);

    signInAs(ADMIN, { user_type: 'admin', status: 'active' });
    expect(await updateConfigAction('maintenance_mode', true)).toEqual({ success: true });
  });
});
