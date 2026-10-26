import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs';
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

// First line of defence only: every dashboard page, layout and server action
// re-checks staff access on the server (lib/auth.ts).
export async function middleware(req: NextRequest) {
  const res = NextResponse.next();
  const supabase = createMiddlewareClient({ req, res });

  // getUser() validates the token with Supabase Auth; getSession() only reads the cookie.
  const { data: { user } } = await supabase.auth.getUser();

  let isStaff = false;
  if (user) {
    const { data: profile } = await supabase.rpc('get_my_profile').maybeSingle<{ user_type: string; status: string }>();
    isStaff = !!profile
      && (profile.user_type === 'admin' || profile.user_type === 'moderator')
      && profile.status !== 'suspended' && profile.status !== 'deleted';
  }

  if (req.nextUrl.pathname.startsWith('/dashboard') && !isStaff) {
    return NextResponse.redirect(new URL(user ? '/login?denied=1' : '/login', req.url));
  }

  if (req.nextUrl.pathname.startsWith('/login') && isStaff) {
    return NextResponse.redirect(new URL('/dashboard', req.url));
  }

  return res;
}

export const config = {
  matcher: ['/dashboard/:path*', '/login'],
};
