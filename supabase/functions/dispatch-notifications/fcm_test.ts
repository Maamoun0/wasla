import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createSignedJwt, FcmClient, ServiceAccount } from "./fcm.ts";

// A throwaway RSA key pair stands in for a Firebase service account.
async function testAccount(): Promise<{ sa: ServiceAccount; publicKey: CryptoKey }> {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let bin = "";
  for (const b of pkcs8) bin += String.fromCharCode(b);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(bin).match(/.{1,64}/g)!.join("\n")}\n-----END PRIVATE KEY-----\n`;
  return {
    sa: { project_id: "wasla-test", client_email: "push@wasla-test.iam.gserviceaccount.com", private_key: pem },
    publicKey: pair.publicKey,
  };
}

function b64urlDecode(s: string): Uint8Array {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (s.length % 4)) % 4);
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

Deno.test("service-account JWT is RS256-signed with the expected claims", async () => {
  const { sa, publicKey } = await testAccount();
  const jwt = await createSignedJwt(sa, 1_800_000_000);
  const [h, p, s] = jwt.split(".");
  const valid = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", publicKey, b64urlDecode(s), new TextEncoder().encode(`${h}.${p}`));
  assert(valid, "signature verifies with the matching public key");
  assertEquals(JSON.parse(new TextDecoder().decode(b64urlDecode(h))), { alg: "RS256", typ: "JWT" });
  assertEquals(JSON.parse(new TextDecoder().decode(b64urlDecode(p))), {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: 1_800_000_000,
    exp: 1_800_003_600,
  });
});

function recordingFetch(responses: Response[]) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fn = (input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(input), init: init ?? {} });
    return Promise.resolve(responses.shift()!);
  };
  return { fn: fn as typeof fetch, calls };
}

const tokenResponse = () => new Response(JSON.stringify({ access_token: "ya29.test", expires_in: 3600 }), { status: 200 });

Deno.test("sends an HTTP v1 message with string data and reuses the access token", async () => {
  const { sa } = await testAccount();
  const { fn, calls } = recordingFetch([tokenResponse(), new Response("{}", { status: 200 }), new Response("{}", { status: 200 })]);
  const client = new FcmClient(sa, fn, () => 1_800_000_000_000);

  assertEquals(await client.send("device-1", "عنوان", "نص", { type: "watchlist_match", ad_id: "ad-1", n: 3 }), { kind: "sent" });
  assertEquals(await client.send("device-2", "t", "b", {}), { kind: "sent" });

  assertEquals(calls.length, 3, "one OAuth exchange, two sends");
  assertEquals(calls[0].url, "https://oauth2.googleapis.com/token");
  assert(String(calls[0].init.body).includes("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer"));
  assertEquals(calls[1].url, "https://fcm.googleapis.com/v1/projects/wasla-test/messages:send");
  assertEquals((calls[1].init.headers as Record<string, string>).Authorization, "Bearer ya29.test");
  const message = JSON.parse(String(calls[1].init.body)).message;
  assertEquals(message.token, "device-1");
  assertEquals(message.notification, { title: "عنوان", body: "نص" });
  assertEquals(message.data, { type: "watchlist_match", ad_id: "ad-1", n: "3" });
});

Deno.test("UNREGISTERED / 404 means the token is dead; other failures are errors", async () => {
  const { sa } = await testAccount();
  const unregistered = new Response(JSON.stringify({ error: { status: "NOT_FOUND", details: [{ errorCode: "UNREGISTERED" }] } }), { status: 404 });
  const unavailable = new Response(JSON.stringify({ error: { status: "UNAVAILABLE" } }), { status: 503 });
  const { fn } = recordingFetch([tokenResponse(), unregistered, unavailable]);
  const client = new FcmClient(sa, fn, () => 1_800_000_000_000);
  assertEquals(await client.send("dead", "t", "b", {}), { kind: "invalid_token" });
  assertEquals(await client.send("live", "t", "b", {}), { kind: "error", message: "FCM 503 UNAVAILABLE" });
});

Deno.test("an expired access token is refreshed", async () => {
  const { sa } = await testAccount();
  let now = 1_800_000_000_000;
  const { fn, calls } = recordingFetch([tokenResponse(), new Response("{}"), tokenResponse(), new Response("{}")]);
  const client = new FcmClient(sa, fn, () => now);
  await client.send("d", "t", "b", {});
  now += 3600 * 1000;
  await client.send("d", "t", "b", {});
  assertEquals(calls.filter((c) => c.url.includes("oauth2")).length, 2);
});
