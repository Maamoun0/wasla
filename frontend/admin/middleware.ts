import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs';
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/request';

export async function middleware(req: NextRequest) {
  const res = NextResponse.next();
  const supabase = createMiddlewareClient({ req, res });

  const {
    data: { session },
  } = await supabase.auth.getSession();

  // 1. If trying to access dashboard without session, redirect to login
  if (req.nextUrl.pathname.startsWith('/dashboard') && !session) {
    return NextResponse.redirect(new URL('/login', req.url));
  }

  // 2. If logged in but accessing login page, redirect to dashboard
  if (req.nextUrl.pathname.startsWith('/login') && session) {
    return NextResponse.redirect(new URL('/dashboard', req.url));
  }

  // 3. Role check (simple check for metadata, more robust in server components)
  if (session && req.nextUrl.pathname.startsWith('/dashboard')) {
    const userRole = session.user.user_metadata?.role;
    if (userRole !== 'admin' && userRole !== 'moderator') {
       // Ideally sign out or show access denied
       // For now, let's allow and let server components handle granular access
    }
  }

  return res;
}

export const config = {
  matcher: ['/dashboard/:path*', '/login'],
};
