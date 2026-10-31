import { assert, assertEquals, assertThrows } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { Webhook } from "npm:standardwebhooks@1.0.0";
import { webhookVerifier } from "./deps.ts";
import { handleSendSmsHook, otpMessage, SendSmsHookDeps } from "./handler.ts";
import { providerFromEnv } from "./providers/registry.ts";
import { twilioProvider } from "./providers/twilio.ts";
import { OutboundMessage, ProviderError, SmsProvider } from "./providers/types.ts";

// Same shape as the secret Supabase generates for a hook ("v1,whsec_<base64>").
const SECRET_B64 = btoa("0123456789abcdef0123456789abcdef");
const HOOK_SECRETS = `v1,whsec_${SECRET_B64}`;
const OTP = "482915";
const EVENT = { user: { id: "u1", phone: "201012345678" }, sms: { otp: OTP } };

function signedRequest(body: unknown, secretB64 = SECRET_B64): Request {
  const payload = JSON.stringify(body);
  const id = `msg_${crypto.randomUUID()}`;
  const now = new Date();
  const signature = new Webhook(secretB64).sign(id, now, payload);
  return new Request("https://x.test/send-sms-hook", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "webhook-id": id,
      "webhook-timestamp": String(Math.floor(now.getTime() / 1000)),
      "webhook-signature": signature,
    },
    body: payload,
  });
}

function fakeProvider(fail: Error | null = null) {
  const sent: OutboundMessage[] = [];
  const provider: SmsProvider = {
    name: "fake",
    channels: ["sms"],
    send(message) {
      if (fail) return Promise.reject(fail);
      sent.push(message);
      return Promise.resolve();
    },
  };
  return { provider, sent };
}

function deps(provider: SmsProvider | null) {
  const logs: string[] = [];
  const d: SendSmsHookDeps = {
    verify: webhookVerifier(HOOK_SECRETS),
    provider,
    channel: "sms",
    timeoutMs: 1000,
    log: (m) => logs.push(m),
  };
  return { d, logs };
}

Deno.test("the fake provider receives the number in E.164 and the exact code", async () => {
  const { provider, sent } = fakeProvider();
  const { d, logs } = deps(provider);
  const res = await handleSendSmsHook(signedRequest(EVENT), d);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Content-Type"), "application/json");
  assertEquals(sent, [{ to: "+201012345678", body: otpMessage(OTP), channel: "sms" }]);
  assert(sent[0].body.includes(OTP));
  assert(!logs.join("\n").includes(OTP), "the OTP is never logged");
  assert(!logs.join("\n").includes("201012345678"), "the full number is never logged");
});

Deno.test("the message is short Arabic text", () => {
  const body = otpMessage(OTP);
  assert(/[؀-ۿ]/.test(body));
  assert(body.length <= 70, `fits one Unicode SMS segment, got ${body.length}`);
});

Deno.test("unsigned, wrongly signed and tampered requests are rejected before the provider", async () => {
  const { provider, sent } = fakeProvider();
  const { d } = deps(provider);
  const unsigned = new Request("https://x.test/send-sms-hook", { method: "POST", body: JSON.stringify(EVENT) });
  const wrongKey = signedRequest(EVENT, btoa("another-secret-another-secret-12"));
  const original = signedRequest(EVENT);
  const tampered = new Request(original.url, {
    method: "POST",
    headers: original.headers,
    body: JSON.stringify({ ...EVENT, user: { phone: "201099999999" } }),
  });
  for (const req of [unsigned, wrongKey, tampered]) {
    const res = await handleSendSmsHook(req, d);
    assertEquals(res.status, 401);
    assertEquals((await res.json()).error.http_code, 401);
  }
  assertEquals(sent.length, 0);
});

Deno.test("a provider failure returns an Auth error and logs no OTP", async () => {
  const { provider } = fakeProvider(new ProviderError("fake: HTTP 400, error 21211"));
  const { d, logs } = deps(provider);
  const res = await handleSendSmsHook(signedRequest(EVENT), d);
  assertEquals(res.status, 200, "Auth relays the error body only from a 200 response");
  assertEquals((await res.json()).error, { http_code: 500, message: "SMS provider failed to send the code" });
  assert(logs.some((l) => l.includes("21211")));
  assert(!logs.join("\n").includes(OTP));
});

Deno.test("an unexpected exception is reduced to its type in logs", async () => {
  const { provider } = fakeProvider(new TypeError(`boom ${OTP}`));
  const { d, logs } = deps(provider);
  const res = await handleSendSmsHook(signedRequest(EVENT), d);
  assertEquals(res.status, 200);
  assert(!logs.join("\n").includes(OTP));
});

Deno.test("no configured provider fails closed", async () => {
  const { d } = deps(null);
  const res = await handleSendSmsHook(signedRequest(EVENT), d);
  assertEquals(res.status, 200);
  assertEquals((await res.json()).error.message, "SMS provider is not configured");
});

Deno.test("malformed payloads are refused", async () => {
  const { provider, sent } = fakeProvider();
  const { d } = deps(provider);
  for (const bad of [{ user: { phone: "abc" }, sms: { otp: OTP } }, { user: { phone: "201012345678" }, sms: {} }]) {
    assertEquals((await (await handleSendSmsHook(signedRequest(bad), d)).json()).error.http_code, 400);
  }
  assertEquals(sent.length, 0);
});

Deno.test("the hook secret is required; rotated secrets separated by | are all accepted", async () => {
  assertThrows(() => webhookVerifier(""));
  const other = btoa("rotated-secret-rotated-secret-12");
  const verify = webhookVerifier(`v1,whsec_${other}|${HOOK_SECRETS}`);
  const req = signedRequest(EVENT);
  assertEquals(verify(await req.text(), Object.fromEntries(req.headers)), EVENT);
});

Deno.test("provider selection comes from SMS_PROVIDER and refuses unknown providers and channels", () => {
  const env: Record<string, string> = { SMS_PROVIDER: "twilio", TWILIO_ACCOUNT_SID: "AC1", TWILIO_AUTH_TOKEN: "t", TWILIO_FROM: "+15550001111" };
  assertEquals(providerFromEnv((k) => env[k]).provider.name, "twilio");
  assertThrows(() => providerFromEnv((k) => ({ ...env, SMS_PROVIDER: "" })[k]));
  assertThrows(() => providerFromEnv((k) => ({ ...env, SMS_PROVIDER: "carrier-pigeon" })[k]));
  assertThrows(() => providerFromEnv((k) => ({ ...env, SMS_CHANNEL: "telegram" })[k]));
  // WhatsApp is a known channel but no provider implements it yet.
  assertThrows(() => providerFromEnv((k) => ({ ...env, SMS_CHANNEL: "whatsapp" })[k]), Error, "does not support the whatsapp channel");
  assertThrows(() => providerFromEnv((k) => ({ ...env, TWILIO_AUTH_TOKEN: "" })[k]));
});

Deno.test("twilio sends the documented form fields and reports errors without the body", async () => {
  const calls: { url: string; auth: string | null; form: URLSearchParams }[] = [];
  let status = 201;
  const server = Deno.serve({ hostname: "127.0.0.1", port: 0, onListen() {} }, async (req) => {
    calls.push({ url: new URL(req.url).pathname, auth: req.headers.get("Authorization"), form: new URLSearchParams(await req.text()) });
    return status === 201
      ? Response.json({ sid: "SM1", status: "queued" }, { status })
      : Response.json({ code: 21211, message: `Invalid 'To' ... ${OTP}` }, { status });
  });
  try {
    const provider = twilioProvider((k) => ({
      TWILIO_ACCOUNT_SID: "AC123",
      TWILIO_AUTH_TOKEN: "tok",
      TWILIO_FROM: "+15550001111",
      TWILIO_API_BASE: `http://127.0.0.1:${server.addr.port}`,
    } as Record<string, string>)[k]);
    await provider.send({ to: "+201012345678", body: otpMessage(OTP), channel: "sms" }, AbortSignal.timeout(2000));
    assertEquals(calls[0].url, "/2010-04-01/Accounts/AC123/Messages.json");
    assertEquals(calls[0].auth, `Basic ${btoa("AC123:tok")}`);
    assertEquals([calls[0].form.get("To"), calls[0].form.get("From"), calls[0].form.get("Body")], ["+201012345678", "+15550001111", otpMessage(OTP)]);

    status = 400;
    const err = await provider.send({ to: "+201012345678", body: otpMessage(OTP), channel: "sms" }, AbortSignal.timeout(2000))
      .then(() => null, (e) => e);
    assert(err instanceof ProviderError);
    assertEquals(err.message, "twilio: HTTP 400, error 21211");
  } finally {
    await server.shutdown();
  }
});
