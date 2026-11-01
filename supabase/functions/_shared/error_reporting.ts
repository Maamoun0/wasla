// Crash reporting for Edge Functions (🟡17). Off unless the SENTRY_DSN secret
// is set; then Sentry is loaded on the first error, with no default PII and
// every event passed through scrubEvent.
import { scrubEvent, scrubText } from "./scrub.ts";

// deno-lint-ignore no-explicit-any
let sentry: Promise<any> | null = null;

function client(dsn: string) {
  sentry ??= import("npm:@sentry/deno@8.55.0").then((Sentry) => {
    Sentry.init({
      dsn,
      environment: Deno.env.get("SENTRY_ENVIRONMENT") ?? "production",
      sendDefaultPii: false,
      defaultIntegrations: false,
      tracesSampleRate: 0,
      beforeSend: scrubEvent,
      // deno-lint-ignore no-explicit-any
      beforeBreadcrumb: (crumb: any) => scrubEvent(crumb),
    });
    return Sentry;
  });
  return sentry;
}

/** Reports an unhandled error; never throws and never delays more than 2s. */
export async function reportError(fn: string, error: unknown): Promise<void> {
  const dsn = Deno.env.get("SENTRY_DSN");
  if (!dsn) return;
  try {
    const Sentry = await client(dsn);
    const err = error instanceof Error ? error : new Error(scrubText(String(error)));
    Sentry.captureException(err, { tags: { function: fn } });
    await Sentry.flush(2000);
  } catch (e) {
    console.error(`${fn}: error reporting failed`, e instanceof Error ? e.message : e);
  }
}
