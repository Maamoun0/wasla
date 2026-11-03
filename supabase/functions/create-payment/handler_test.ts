import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { CreatePaymentDeps, handleCreatePayment, NewTransaction, PaymentPackage, paymentsUnavailable } from "./handler.ts";

const AD_ID = "aaaaaaaa-0000-0000-0000-000000000001";
const PACKAGES: Record<string, PaymentPackage> = {
  boost_featured_7d: { id: "boost_featured_7d", kind: "ad_boost", price_egp: 60, boost_type: "featured" },
  sub_premium_monthly: { id: "sub_premium_monthly", kind: "subscription", price_egp: 199, boost_type: null },
  credit_100: { id: "credit_100", kind: "credit_purchase", price_egp: 95, boost_type: null },
};

function fakeDeps(overrides: Partial<CreatePaymentDeps> = {}) {
  const inserted: NewTransaction[] = [];
  const paymobCalls: { amountCents: number; merchantOrderId: string }[] = [];
  const failed: string[] = [];
  const attached: [string, string][] = [];
  const deps: CreatePaymentDeps = {
    authenticate: (t) => Promise.resolve(t === "good" ? "user-1" : null),
    accountBlocked: () => Promise.resolve(false),
    setting: (_key, fallback) => Promise.resolve(fallback),
    getActivePackage: (id) => Promise.resolve(PACKAGES[id] ?? null),
    getAd: (id) => Promise.resolve(id === AD_ID ? { user_id: "user-1", status: "active" } : null),
    hasActiveBoost: () => Promise.resolve(false),
    getBillingProfile: () => Promise.resolve({ fullName: "Test User", email: null, phone: "+201000000001" }),
    insertTransaction: (tx) => {
      inserted.push(tx);
      return Promise.resolve("tx-1");
    },
    createPaymobPayment: (args) => {
      paymobCalls.push(args);
      return Promise.resolve({ orderId: "order-9", iframeUrl: "https://accept.paymob.com/iframe" });
    },
    attachGatewayOrder: (tx, order) => {
      attached.push([tx, order]);
      return Promise.resolve();
    },
    markFailed: (tx) => {
      failed.push(tx);
      return Promise.resolve();
    },
    ...overrides,
  };
  return { deps, inserted, paymobCalls, failed, attached };
}

function post(body: unknown, token = "good"): Request {
  return new Request("https://example.test/create-payment", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
}

Deno.test("amount sent by the client is ignored; package price is charged", async () => {
  const { deps, inserted, paymobCalls } = fakeDeps();
  const res = await handleCreatePayment(
    post({ package_id: "boost_featured_7d", ad_id: AD_ID, amount: 1, metadata: { duration_days: 365 } }),
    deps,
  );
  assertEquals(res.status, 200);
  assertEquals(inserted[0].amount, 60);
  assertEquals(inserted[0].package_id, "boost_featured_7d");
  assertEquals(inserted[0].reference_id, AD_ID);
  assertEquals(paymobCalls[0].amountCents, 6000);
  assertEquals(paymobCalls[0].merchantOrderId, "tx-1");
  assertEquals((await res.json()).amount, 60);
});

Deno.test("subscription package: no ad needed, reference is null", async () => {
  const { deps, inserted } = fakeDeps();
  const res = await handleCreatePayment(post({ package_id: "sub_premium_monthly" }), deps);
  assertEquals(res.status, 200);
  assertEquals(inserted[0].type, "subscription");
  assertEquals(inserted[0].reference_id, null);
  assertEquals(inserted[0].amount, 199);
});

Deno.test("missing or unknown package: 400 and nothing inserted", async () => {
  const { deps, inserted } = fakeDeps();
  assertEquals((await handleCreatePayment(post({ amount: 60 }), deps)).status, 400);
  assertEquals((await handleCreatePayment(post({ package_id: "nope" }), deps)).status, 400);
  assertEquals(inserted.length, 0);
});

Deno.test("no or bad token: 401", async () => {
  const { deps, inserted } = fakeDeps();
  const noAuth = new Request("https://example.test/create-payment", { method: "POST", body: "{}" });
  assertEquals((await handleCreatePayment(noAuth, deps)).status, 401);
  assertEquals((await handleCreatePayment(post({ package_id: "sub_premium_monthly" }, "bad"), deps)).status, 401);
  assertEquals(inserted.length, 0);
});

Deno.test("boosting someone else's ad: 403", async () => {
  const { deps, inserted } = fakeDeps({ getAd: () => Promise.resolve({ user_id: "user-2", status: "active" }) });
  const res = await handleCreatePayment(post({ package_id: "boost_featured_7d", ad_id: AD_ID }), deps);
  assertEquals(res.status, 403);
  assertEquals(inserted.length, 0);
});

Deno.test("boosting an inactive ad: 400", async () => {
  const { deps } = fakeDeps({ getAd: () => Promise.resolve({ user_id: "user-1", status: "pending" }) });
  assertEquals((await handleCreatePayment(post({ package_id: "boost_featured_7d", ad_id: AD_ID }), deps)).status, 400);
});

Deno.test("boost without a valid ad id: 400", async () => {
  const { deps } = fakeDeps();
  assertEquals((await handleCreatePayment(post({ package_id: "boost_featured_7d", ad_id: "x" }), deps)).status, 400);
});

Deno.test("same boost already active: 409", async () => {
  const { deps, inserted } = fakeDeps({ hasActiveBoost: () => Promise.resolve(true) });
  const res = await handleCreatePayment(post({ package_id: "boost_featured_7d", ad_id: AD_ID }), deps);
  assertEquals(res.status, 409);
  assertEquals(inserted.length, 0);
});

Deno.test("unsupported payment method: 400", async () => {
  const { deps } = fakeDeps();
  const res = await handleCreatePayment(post({ package_id: "sub_premium_monthly", payment_method: "bitcoin" }), deps);
  assertEquals(res.status, 400);
});

Deno.test("Paymob failure: 502 and the pending transaction is marked failed", async () => {
  const { deps, failed, attached } = fakeDeps({ createPaymobPayment: () => Promise.reject(new Error("down")) });
  const res = await handleCreatePayment(post({ package_id: "sub_premium_monthly" }), deps);
  assertEquals(res.status, 502);
  assertEquals(failed, ["tx-1"]);
  assertEquals(attached.length, 0);
});

Deno.test("Paymob order id is stored on the transaction", async () => {
  const { deps, attached } = fakeDeps();
  await handleCreatePayment(post({ package_id: "sub_premium_monthly" }), deps);
  assertEquals(attached, [["tx-1", "order-9"]]);
});

Deno.test("credit purchases are disabled until prices are set: 400 and nothing inserted", async () => {
  const { deps, inserted, paymobCalls } = fakeDeps();
  const res = await handleCreatePayment(post({ package_id: "credit_100" }), deps);
  assertEquals(res.status, 400);
  assertEquals(inserted.length, 0);
  assertEquals(paymobCalls.length, 0);
});

Deno.test("maintenance stops new payments before anything is created", async () => {
  const { deps, inserted, paymobCalls } = fakeDeps({ setting: (key, fallback) => Promise.resolve(key === "maintenance_mode" ? true : fallback) });
  const res = await handleCreatePayment(post({ package_id: "boost_featured_7d", ad_id: AD_ID }), deps);
  assertEquals(res.status, 503);
  assertEquals((await res.json()).code, "maintenance");
  assertEquals([inserted.length, paymobCalls.length], [0, 0]);
});

Deno.test("with boosting switched off, boost packages cannot be bought", async () => {
  const { deps, inserted } = fakeDeps({ setting: (key, fallback) => Promise.resolve(key === "enable_boost_feature" ? false : fallback) });
  const res = await handleCreatePayment(post({ package_id: "boost_featured_7d", ad_id: AD_ID }), deps);
  assertEquals(res.status, 403);
  assertEquals((await res.json()).code, "boost_disabled");
  assertEquals(inserted.length, 0);
});

Deno.test("a suspended or banned account cannot start a payment with its remaining token", async () => {
  const { deps, inserted } = fakeDeps({ accountBlocked: () => Promise.resolve(true) });
  const res = await handleCreatePayment(post({ package_id: "boost_featured_7d", ad_id: AD_ID }), deps);
  assertEquals(res.status, 403);
  assertEquals((await res.json()).code, "account_blocked");
  assertEquals(inserted.length, 0);
});

Deno.test("without Paymob keys the answer is a clear 503, not an unexpected error", async () => {
  const res = paymentsUnavailable();
  assertEquals(res.status, 503);
  assertEquals((await res.json()).error, "الدفع الإلكتروني مش متاح في النسخة دي حالياً.");
});
