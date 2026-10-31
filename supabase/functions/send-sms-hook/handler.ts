// Supabase Auth "Send SMS" hook: Auth calls this instead of a built-in SMS
// provider, signed per Standard Webhooks. The OTP lives only in memory here:
// it is never logged, stored or returned. Any failure is reported to Auth as
// an error (fail closed), and Auth returns it to the app.
import { Channel, ProviderError, SmsProvider } from "./providers/types.ts";

export interface SendSmsHookDeps {
  /** Verifies the Standard Webhooks signature and returns the parsed payload; throws if invalid. */
  verify(payload: string, headers: Record<string, string>): unknown;
  /** Null when the provider is misconfigured: every request then fails. */
  provider: SmsProvider | null;
  channel: Channel;
  timeoutMs: number;
  log(message: string): void;
}

// Auth gives the hook 5 seconds in total; leave room for the response.
export const DEFAULT_TIMEOUT_MS = 4000;

export function otpMessage(otp: string): string {
  return `رمز التحقق في وصلة: ${otp}\nلا تشاركه مع أي شخص.`;
}

// Errors for Auth: Auth reads { error: { http_code, message } } only from a
// 200 response and turns it into that HTTP error for the app. Any other status
// becomes a generic "Unexpected status code returned from hook".
function authError(httpCode: number, message: string): Response {
  return new Response(JSON.stringify({ error: { http_code: httpCode, message } }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

// Refusals for callers that are not Auth (no or bad signature): plain status.
function refuse(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: { http_code: status, message } }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Last 3 digits only, for logs. */
function maskPhone(phone: string): string {
  return `***${phone.slice(-3)}`;
}

export async function handleSendSmsHook(req: Request, deps: SendSmsHookDeps): Promise<Response> {
  if (req.method !== "POST") return refuse(405, "method not allowed");

  const payload = await req.text();
  let event: unknown;
  try {
    event = deps.verify(payload, Object.fromEntries(req.headers));
  } catch {
    deps.log("send-sms-hook: rejected a request with a missing or invalid signature");
    return refuse(401, "invalid webhook signature");
  }

  const e = event as { user?: { phone?: unknown }; sms?: { otp?: unknown } };
  const digits = typeof e.user?.phone === "string" ? e.user.phone.replace(/^\+/, "") : "";
  const otp = typeof e.sms?.otp === "string" ? e.sms.otp : "";
  if (!/^\d{8,15}$/.test(digits) || !/^\d{4,10}$/.test(otp)) return authError(400, "invalid hook payload");
  const to = `+${digits}`;

  if (!deps.provider) {
    deps.log("send-sms-hook: no SMS provider configured");
    return authError(500, "SMS provider is not configured");
  }

  try {
    await deps.provider.send({ to, body: otpMessage(otp), channel: deps.channel }, AbortSignal.timeout(deps.timeoutMs));
  } catch (err) {
    // ProviderError messages are built without the body; anything else is reduced to its type.
    const reason = err instanceof ProviderError ? err.message : `unexpected ${err instanceof Error ? err.name : "error"}`;
    deps.log(`send-sms-hook: ${deps.provider.name} failed for ${maskPhone(to)}: ${reason}`);
    return authError(500, "SMS provider failed to send the code");
  }

  deps.log(`send-sms-hook: sent via ${deps.provider.name} (${deps.channel}) to ${maskPhone(to)}`);
  return new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } });
}
