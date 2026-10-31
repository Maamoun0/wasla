// One interface for every message provider. A new provider is a new file in
// this folder implementing SmsProvider, plus one line in registry.ts.

/** How the code reaches the user. Only "sms" is implemented today. */
export type Channel = "sms" | "whatsapp";

export interface OutboundMessage {
  /** E.164 with a leading "+", e.g. +201012345678. */
  to: string;
  body: string;
  channel: Channel;
}

export interface SmsProvider {
  readonly name: string;
  readonly channels: readonly Channel[];
  /** Resolves when the provider accepted the message; throws ProviderError otherwise. */
  send(message: OutboundMessage, signal: AbortSignal): Promise<void>;
}

/** A provider refusal or outage. The message must never contain the message body (it holds the OTP). */
export class ProviderError extends Error {}

export type EnvGetter = (key: string) => string | undefined;
