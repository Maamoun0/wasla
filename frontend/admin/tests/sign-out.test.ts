import { describe, expect, it, vi } from 'vitest';

const signOut = vi.fn(async () => ({ error: null }));
vi.mock('next/headers', () => ({ cookies: () => ({}) }));
vi.mock('next/navigation', () => ({
  redirect: (url: string) => {
    throw new Error(`REDIRECT:${url}`);
  },
}));
vi.mock('@supabase/auth-helpers-nextjs', () => ({
  createServerActionClient: () => ({ auth: { signOut } }),
}));

import { signOutAction } from '@/app/dashboard/actions';

describe('signOutAction', () => {
  it('signs the staff member out, then sends them to the login page', async () => {
    await expect(signOutAction()).rejects.toThrow('REDIRECT:/login');
    expect(signOut).toHaveBeenCalledTimes(1);
  });
});
