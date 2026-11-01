'use client';

// Browser-side crash reporting (🟡17). Off unless NEXT_PUBLIC_SENTRY_DSN is set.
import * as Sentry from '@sentry/nextjs';
import { sentryOptions } from '@/lib/observability/scrub';

const dsn = process.env.NEXT_PUBLIC_SENTRY_DSN;
if (dsn && typeof window !== 'undefined' && !Sentry.getClient()) Sentry.init(sentryOptions(dsn));

export default function ErrorReportingInit() {
  return null;
}
