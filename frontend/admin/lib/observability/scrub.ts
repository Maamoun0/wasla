// Crash reporting filter (🟡17): phone numbers, emails and tokens never reach
// Sentry. Used as `beforeSend` / `beforeBreadcrumb` on the server and in the
// browser, with `sendDefaultPii: false`.
import type { Breadcrumb, ErrorEvent } from '@sentry/nextjs';

const PATTERNS: [RegExp, string][] = [
  [/eyJ[\w-]+\.[\w-]+\.[\w-]+/g, '[token]'],
  [/(Bearer\s+)[\w.~+/-]+=*/gi, '$1[token]'],
  [/((?:access_token|refresh_token|token|apikey|api_key|password|secret|otp)["']?\s*[:=]\s*["']?)[^\s"'&,}]+/gi, '$1[filtered]'],
  [/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, '[email]'],
  // Phone numbers and national IDs: a run of 9+ digits, spaces or dashes allowed.
  [/\+?\d[\d\s-]{7,}\d/g, '[number]'],
];

export function scrubText(text: string): string {
  return PATTERNS.reduce((out, [re, replacement]) => out.replace(re, replacement), text);
}

function scrubValue<T>(value: T): T {
  if (typeof value === 'string') return scrubText(value) as T;
  if (Array.isArray(value)) return value.map(scrubValue) as T;
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, scrubValue(v)])) as T;
  }
  return value;
}

export function scrubBreadcrumb(crumb: Breadcrumb): Breadcrumb {
  return scrubValue(crumb);
}

/** Every string scrubbed, the user reduced to an id, and request headers,
 *  cookies, bodies and query strings dropped. */
export function scrubEvent(event: ErrorEvent): ErrorEvent {
  const out = scrubValue(event);
  if (out.user) out.user = out.user.id ? { id: out.user.id } : {};
  if (out.request) {
    out.request = { url: out.request.url?.split('?')[0], method: out.request.method };
  }
  return out;
}

export function sentryOptions(dsn: string | undefined) {
  return {
    dsn,
    enabled: Boolean(dsn),
    environment: process.env.NEXT_PUBLIC_SENTRY_ENVIRONMENT ?? 'production',
    sendDefaultPii: false,
    tracesSampleRate: 0,
    beforeSend: scrubEvent,
    beforeBreadcrumb: scrubBreadcrumb,
  };
}
