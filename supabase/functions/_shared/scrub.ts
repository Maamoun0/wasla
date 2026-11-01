// Crash reporting filter (🟡17): phone numbers, emails and tokens never reach
// Sentry. Same rules as the app and the admin panel.

const PATTERNS: [RegExp, string][] = [
  [/eyJ[\w-]+\.[\w-]+\.[\w-]+/g, "[token]"],
  [/(Bearer\s+)[\w.~+/-]+=*/gi, "$1[token]"],
  [/((?:access_token|refresh_token|token|apikey|api_key|password|secret|otp)["']?\s*[:=]\s*["']?)[^\s"'&,}]+/gi, "$1[filtered]"],
  [/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, "[email]"],
  // Phone numbers and national IDs: a run of 9+ digits, spaces or dashes allowed.
  [/\+?\d[\d\s-]{7,}\d/g, "[number]"],
];

export function scrubText(text: string): string {
  return PATTERNS.reduce((out, [re, replacement]) => out.replace(re, replacement), text);
}

export function scrubValue<T>(value: T): T {
  if (typeof value === "string") return scrubText(value) as T;
  if (Array.isArray(value)) return value.map(scrubValue) as T;
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, scrubValue(v)])) as T;
  }
  return value;
}

// deno-lint-ignore no-explicit-any
type Event = Record<string, any>;

/** Every string scrubbed, the user reduced to an id, and request headers,
 *  cookies, bodies and query strings dropped. */
export function scrubEvent<E extends Event>(event: E): E {
  const out: Event = scrubValue(event);
  if (out.user) out.user = out.user.id ? { id: out.user.id } : {};
  if (out.request) out.request = { url: String(out.request.url ?? "").split("?")[0], method: out.request.method };
  return out as E;
}
