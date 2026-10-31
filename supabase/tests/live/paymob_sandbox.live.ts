// Live check of the Paymob sandbox (test-mode) credentials, through the same
// createPaymobPayment that create-payment uses: auth token -> order -> payment
// key -> iframe. No money moves. Skipped unless PAYMOB_API_KEY,
// PAYMOB_INTEGRATION_ID and PAYMOB_IFRAME_ID are set.
//   deno test --config supabase/functions/deno.json --no-lock --allow-env --allow-net supabase/tests/live/paymob_sandbox.live.ts
import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createPaymobPayment } from "../../functions/create-payment/paymob.ts";

const cfg = {
  apiKey: Deno.env.get("PAYMOB_API_KEY") ?? "",
  integrationId: parseInt(Deno.env.get("PAYMOB_INTEGRATION_ID") ?? "0"),
  iframeId: parseInt(Deno.env.get("PAYMOB_IFRAME_ID") ?? "0"),
};

Deno.test({
  name: "sandbox credentials create an order and a payment page",
  ignore: !cfg.apiKey || !cfg.integrationId || !cfg.iframeId,
  async fn() {
    const { orderId, iframeUrl } = await createPaymobPayment(cfg, {
      amountCents: 1000,
      merchantOrderId: `live-test-${crypto.randomUUID()}`,
      billing: { fullName: "اختبار وصلة", email: "live-test@wasla.test", phone: "+201000000000" },
    });
    console.log({ orderId, iframeUrl: iframeUrl.replace(/payment_token=.*/, "payment_token=…") });
    assert(/^\d+$/.test(orderId));
    const page = await fetch(iframeUrl);
    await page.body?.cancel();
    assertEquals(page.status, 200, "the iframe page opens");
  },
});
