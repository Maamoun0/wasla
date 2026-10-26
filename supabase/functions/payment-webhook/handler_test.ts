import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { computePaymobHmac, FulfilResult, handleWebhook, WebhookDeps } from "./handler.ts";

const SECRET = "test_hmac_secret";

// Reference vector computed independently with Python's hmac/hashlib (SHA-512).
const OBJ = {
  amount_cents: 6000,
  created_at: "2026-10-26T10:00:00.000000",
  currency: "EGP",
  error_occured: false,
  has_parent_transaction: false,
  id: 192837465,
  integration_id: 4567890,
  is_3d_secure: true,
  is_auth: false,
  is_capture: false,
  is_refunded: false,
  is_standalone_payment: true,
  is_voided: false,
  order: { id: 88776655 },
  owner: 112233,
  pending: false,
  source_data: { pan: "2346", sub_type: "MasterCard", type: "card" },
  success: true,
};
const OBJ_HMAC =
  "8c7867c0121feb5414cd80ac4d3ea4eaad5df22e280a9ca25abb7d6182c6e5256990030886bbad019c3c9a9a8166e998f5eee879479302cfe295736c7aa01fb0";

function fakeDeps(result: FulfilResult = "completed") {
  const calls: Parameters<WebhookDeps["fulfil"]>[0][] = [];
  const deps: WebhookDeps = {
    hmacSecret: SECRET,
    findTransactionByOrderId: (orderId) =>
      Promise.resolve(orderId === "88776655" ? { id: "tx-1", user_id: "user-1" } : null),
    fulfil: (args) => {
      calls.push(args);
      return Promise.resolve(result);
    },
  };
  return { deps, calls };
}

function post(body: unknown, hmac?: string): Request {
  const url = "https://example.test/payment-webhook" + (hmac === undefined ? "" : `?hmac=${hmac}`);
  return new Request(url, { method: "POST", body: typeof body === "string" ? body : JSON.stringify(body) });
}

Deno.test("HMAC matches the independent reference vector", async () => {
  assertEquals(await computePaymobHmac(SECRET, OBJ), OBJ_HMAC);
});

Deno.test("valid HMAC: fulfils with the paid amount and currency from Paymob", async () => {
  const { deps, calls } = fakeDeps();
  const res = await handleWebhook(post({ obj: OBJ }, OBJ_HMAC), deps);
  assertEquals(res.status, 200);
  assertEquals((await res.json()).result, "completed");
  assertEquals(calls.length, 1);
  assertEquals(calls[0].transactionId, "tx-1");
  assertEquals(calls[0].amountCents, 6000);
  assertEquals(calls[0].currency, "EGP");
  assertEquals(calls[0].success, true);
});

Deno.test("upper-case HMAC is accepted", async () => {
  const { deps, calls } = fakeDeps();
  const res = await handleWebhook(post({ obj: OBJ }, OBJ_HMAC.toUpperCase()), deps);
  assertEquals(res.status, 200);
  assertEquals(calls.length, 1);
});

Deno.test("wrong HMAC: 401 and nothing is fulfilled", async () => {
  const { deps, calls } = fakeDeps();
  const bad = OBJ_HMAC.slice(0, -1) + (OBJ_HMAC.endsWith("0") ? "1" : "0");
  const res = await handleWebhook(post({ obj: OBJ }, bad), deps);
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test("tampered amount with the original HMAC: 401", async () => {
  const { deps, calls } = fakeDeps();
  const res = await handleWebhook(post({ obj: { ...OBJ, amount_cents: 100 } }, OBJ_HMAC), deps);
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test("missing HMAC: 401", async () => {
  const { deps, calls } = fakeDeps();
  const res = await handleWebhook(post({ obj: OBJ }), deps);
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test("pending or unsuccessful payment is passed on as not successful", async () => {
  const pendingObj = { ...OBJ, pending: true };
  const { deps, calls } = fakeDeps("failed");
  const res = await handleWebhook(post({ obj: pendingObj }, await computePaymobHmac(SECRET, pendingObj)), deps);
  assertEquals(res.status, 200);
  assertEquals(calls[0].success, false);
});

Deno.test("duplicate callback: 200 already_processed", async () => {
  const { deps } = fakeDeps("already_processed");
  const res = await handleWebhook(post({ obj: OBJ }, OBJ_HMAC), deps);
  assertEquals(res.status, 200);
  assertEquals((await res.json()).result, "already_processed");
});

Deno.test("unknown order: 404", async () => {
  const other = { ...OBJ, order: { id: 1 } };
  const { deps, calls } = fakeDeps();
  const res = await handleWebhook(post({ obj: other }, await computePaymobHmac(SECRET, other)), deps);
  assertEquals(res.status, 404);
  assertEquals(calls.length, 0);
});

Deno.test("malformed body: 400", async () => {
  const { deps } = fakeDeps();
  assertEquals((await handleWebhook(post("{not json", OBJ_HMAC), deps)).status, 400);
  assertEquals((await handleWebhook(post({ nope: 1 }, OBJ_HMAC), deps)).status, 400);
});

Deno.test("non-POST: 405", async () => {
  const { deps } = fakeDeps();
  const res = await handleWebhook(new Request("https://example.test/payment-webhook", { method: "GET" }), deps);
  assertEquals(res.status, 405);
});

Deno.test("completed payment triggers the activity hook once", async () => {
  const { deps } = fakeDeps("completed");
  let hooked = 0;
  deps.onCompleted = () => {
    hooked++;
    return Promise.resolve();
  };
  await handleWebhook(post({ obj: OBJ }, OBJ_HMAC), deps);
  assert(hooked === 1);
});
