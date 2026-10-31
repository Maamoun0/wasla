import { Webhook } from "npm:standardwebhooks@1.0.0";
import { DEFAULT_TIMEOUT_MS, SendSmsHookDeps } from "./handler.ts";
import { providerFromEnv } from "./providers/registry.ts";
import { EnvGetter } from "./providers/types.ts";

/**
 * Verifier for SEND_SMS_HOOK_SECRETS as Supabase shows it ("v1,whsec_<base64>").
 * Several secrets separated by "|" are all accepted (rotation).
 */
export function webhookVerifier(secrets: string): (payload: string, headers: Record<string, string>) => unknown {
  const hooks = secrets.split("|").map((s) => s.trim().replace(/^v1,/, "")).filter(Boolean).map((s) => new Webhook(s));
  if (hooks.length === 0) throw new Error("SEND_SMS_HOOK_SECRETS is not set");
  return (payload, headers) => {
    let lastError: unknown;
    for (const hook of hooks) {
      try {
        return hook.verify(payload, headers);
      } catch (err) {
        lastError = err;
      }
    }
    throw lastError;
  };
}

export function depsFromEnv(get: EnvGetter): SendSmsHookDeps {
  const log = (message: string) => console.log(message);
  let configured: ReturnType<typeof providerFromEnv> | null = null;
  try {
    configured = providerFromEnv(get);
  } catch (err) {
    // Configuration errors name variables, never values.
    log(`send-sms-hook: provider configuration error: ${err instanceof Error ? err.message : err}`);
  }
  return {
    verify: webhookVerifier(get("SEND_SMS_HOOK_SECRETS") ?? ""),
    provider: configured?.provider ?? null,
    channel: configured?.channel ?? "sms",
    timeoutMs: Number(get("SMS_TIMEOUT_MS")) || DEFAULT_TIMEOUT_MS,
    log,
  };
}
