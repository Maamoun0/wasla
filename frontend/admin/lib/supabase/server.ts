import 'server-only';
import { createClient } from '@supabase/supabase-js';
import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers';

// Session-bound client: acts as the signed-in staff member (respects RLS).
export const createServerClient = () => createServerComponentClient({ cookies });

// Service-role client: bypasses RLS. Server-only — 'server-only' makes any
// client-side import a build error, so the key can never reach the browser.
export const createAdminClient = () =>
  createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
