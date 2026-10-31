// Picks the provider from SMS_PROVIDER. Adding a provider: a new file in this
// folder and one entry below.
import { twilioProvider } from "./twilio.ts";
import { Channel, EnvGetter, SmsProvider } from "./types.ts";

const PROVIDERS: Record<string, (get: EnvGetter) => SmsProvider> = {
  twilio: twilioProvider,
};

export const CHANNELS: readonly Channel[] = ["sms", "whatsapp"];

/** Throws on any configuration problem, so the hook fails closed instead of guessing. */
export function providerFromEnv(get: EnvGetter): { provider: SmsProvider; channel: Channel } {
  const name = get("SMS_PROVIDER")?.trim().toLowerCase() ?? "";
  const factory = PROVIDERS[name];
  if (!factory) throw new Error(`SMS_PROVIDER must be one of: ${Object.keys(PROVIDERS).join(", ")}`);

  const channel = (get("SMS_CHANNEL")?.trim().toLowerCase() || "sms") as Channel;
  if (!CHANNELS.includes(channel)) throw new Error(`SMS_CHANNEL must be one of: ${CHANNELS.join(", ")}`);

  const provider = factory(get);
  if (!provider.channels.includes(channel)) {
    throw new Error(`${provider.name} does not support the ${channel} channel`);
  }
  return { provider, channel };
}
