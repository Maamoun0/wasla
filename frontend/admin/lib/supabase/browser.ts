import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';

// Anon-key client for Client Components. Stores the session in cookies so
// middleware and server code can verify it.
export const createBrowserClient = () => createClientComponentClient();
