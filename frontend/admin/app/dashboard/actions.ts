'use server';

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { createServerActionClient } from '@supabase/auth-helpers-nextjs';

// Ends the staff session: revokes the refresh token and clears the auth cookies.
export async function signOutAction() {
  const supabase = createServerActionClient({ cookies });
  await supabase.auth.signOut();
  redirect('/login');
}
