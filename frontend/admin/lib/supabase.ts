import { createClient } from '@supabase/supabase-js';
import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

// Standard client for use in Client Components (respects RLS)
export const createClientClient = () => createClient(supabaseUrl, supabaseAnonKey);

// Server component client (respects user session/RLS)
export const createServerClient = () => createServerComponentClient({ cookies });

// Admin client (Bypasses RLS - STRICTLY FOR SERVER-SIDE USE ONLY)
export const createAdminClient = () => createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});
