import { beforeEach, describe, expect, it, vi } from 'vitest';
import { adminClient, resetState, serverClient, signInAs, state } from './fakes';

vi.mock('server-only', () => ({}));
vi.mock('next/cache', () => ({ revalidatePath: vi.fn() }));
vi.mock('next/navigation', () => ({
  redirect: (url: string) => {
    throw new Error(`redirect:${url}`);
  },
}));
vi.mock('@/lib/supabase/server', () => ({
  createAdminClient: () => adminClient,
  createServerClient: () => serverClient,
}));

import { UNAUTHORIZED } from '@/lib/auth';
import { updatePackageAction, validatePackageChanges } from '@/app/dashboard/packages/actions';

const ADMIN = 'aaaaaaaa-0000-0000-0000-000000000001';
const MOD = 'aaaaaaaa-0000-0000-0000-000000000002';
const PKG = { id: 'boost_featured_7d', name_ar: 'إعلان مميز (7 أيام)', price_egp: 60, is_active: true, sort_order: 2 };

beforeEach(() => {
  resetState();
  state.tables.payment_packages = [{ ...PKG }];
});

describe('updatePackageAction', () => {
  it('is admin-only', async () => {
    signInAs(MOD, { user_type: 'moderator', status: 'active' });
    expect(await updatePackageAction(PKG.id, { price_egp: 75 })).toEqual(UNAUTHORIZED);
    expect(state.updates).toHaveLength(0);
  });

  it('saves a new price and audits the old and new values', async () => {
    signInAs(ADMIN, { user_type: 'admin', status: 'active' });
    expect(await updatePackageAction(PKG.id, { price_egp: 75.5 })).toEqual({ success: true });
    expect(state.updates[0]).toMatchObject({ table: 'payment_packages', values: { price_egp: 75.5 }, filters: { id: PKG.id } });
    expect(state.inserts[0]).toMatchObject({
      table: 'audit_logs',
      row: { actor_id: ADMIN, action: 'update_payment_package', changes: { id: PKG.id, before: PKG, after: { price_egp: 75.5 } } },
    });
  });

  it('refuses an unknown package without writing', async () => {
    signInAs(ADMIN, { user_type: 'admin', status: 'active' });
    expect((await updatePackageAction('nope', { price_egp: 10 })).success).toBe(false);
    expect(state.updates).toHaveLength(0);
  });

  it('cannot change the kind, duration, boost type or plan', async () => {
    signInAs(ADMIN, { user_type: 'admin', status: 'active' });
    for (const field of ['duration_days', 'kind', 'boost_type', 'plan_id', 'credit_amount', 'id']) {
      expect((await updatePackageAction(PKG.id, { [field]: 1 })).success, field).toBe(false);
    }
    expect(state.updates).toHaveLength(0);
  });
});

describe('validatePackageChanges', () => {
  it.each([
    [{ price_egp: 0 }], [{ price_egp: -5 }], [{ price_egp: 100001 }], [{ price_egp: 9.999 }],
    [{ price_egp: '60' }], [{ price_egp: Number.NaN }], [{ name_ar: ' ' }], [{ is_active: 'yes' }],
    [{ sort_order: 1.5 }], [{}], [null], [[1]],
  ])('refuses %j', async (changes) => {
    expect((await validatePackageChanges(changes)).ok).toBe(false);
  });

  it('accepts and trims valid values', async () => {
    expect(await validatePackageChanges({ price_egp: 99.95, name_ar: '  مميز  ', is_active: false, sort_order: 3 }))
      .toEqual({ ok: true, values: { price_egp: 99.95, name_ar: 'مميز', is_active: false, sort_order: 3 } });
  });
});
