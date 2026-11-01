// Server-side crash reporting (🟡17). Off unless SENTRY_DSN is set.
import * as Sentry from '@sentry/nextjs';
import { sentryOptions } from '@/lib/observability/scrub';

export async function register() {
  if (process.env.SENTRY_DSN) Sentry.init(sentryOptions(process.env.SENTRY_DSN));
}

export const onRequestError = Sentry.captureRequestError;
