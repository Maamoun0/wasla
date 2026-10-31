// Twilio Programmable Messaging (REST, no SDK). Used for testing; a local
// Egyptian provider can replace it through SMS_PROVIDER.
import { EnvGetter, OutboundMessage, ProviderError, SmsProvider } from "./types.ts";

const DEFAULT_API_BASE = "https://api.twilio.com";

export function twilioProvider(get: EnvGetter): SmsProvider {
  const accountSid = get("TWILIO_ACCOUNT_SID")?.trim() ?? "";
  const authToken = get("TWILIO_AUTH_TOKEN")?.trim() ?? "";
  // Either a sender number or a Messaging Service.
  const from = get("TWILIO_FROM")?.trim() ?? "";
  const messagingServiceSid = get("TWILIO_MESSAGING_SERVICE_SID")?.trim() ?? "";
  // Overridable only so local tests can point at a fake Twilio.
  const apiBase = (get("TWILIO_API_BASE")?.trim() || DEFAULT_API_BASE).replace(/\/+$/, "");
  if (!accountSid || !authToken || (!from && !messagingServiceSid)) {
    throw new Error("twilio: TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN and TWILIO_FROM or TWILIO_MESSAGING_SERVICE_SID are required");
  }

  return {
    name: "twilio",
    channels: ["sms"],
    async send(message: OutboundMessage, signal: AbortSignal) {
      const form = new URLSearchParams({ To: message.to, Body: message.body });
      if (messagingServiceSid) form.set("MessagingServiceSid", messagingServiceSid);
      else form.set("From", from);

      let res: Response;
      try {
        res = await fetch(`${apiBase}/2010-04-01/Accounts/${encodeURIComponent(accountSid)}/Messages.json`, {
          method: "POST",
          headers: {
            Authorization: `Basic ${btoa(`${accountSid}:${authToken}`)}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: form,
          signal,
        });
      } catch (err) {
        throw new ProviderError(`twilio: request failed (${err instanceof Error ? err.name : "error"})`);
      }
      if (res.ok) {
        await res.body?.cancel();
        return;
      }
      // Only Twilio's numeric error code: its message text can echo request fields.
      const payload = await res.json().catch(() => ({})) as { code?: number };
      throw new ProviderError(`twilio: HTTP ${res.status}${payload.code ? `, error ${payload.code}` : ""}`);
    },
  };
}
