// Live check of push notifications with a real Firebase service account,
// through the FcmClient that dispatch-notifications uses.
// Skipped unless FIREBASE_SERVICE_ACCOUNT (the JSON, one line) is set.
// With WASLA_TEST_FCM_TOKEN (copied from a debug build's log) it also sends a
// real notification to that device.
//   deno test --config supabase/functions/deno.json --no-lock --allow-env --allow-net supabase/tests/live/fcm.live.ts
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { FcmClient, ServiceAccount } from "../../functions/dispatch-notifications/fcm.ts";

const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
const deviceToken = Deno.env.get("WASLA_TEST_FCM_TOKEN") ?? "";

Deno.test({
  name: "the service account gets an OAuth token and FCM accepts requests for the project",
  ignore: !saJson,
  async fn() {
    const client = new FcmClient(JSON.parse(saJson) as ServiceAccount);
    await client.getAccessToken();
    // A made-up token: FCM answers about the token, not about permissions (403).
    const result = await client.send("not-a-real-device-token", "وصلة", "اختبار", {});
    console.log(result);
    assertEquals(result.kind === "error" && result.message.startsWith("FCM 403"), false, "service account lacks FCM permission");
  },
});

Deno.test({
  name: "a real notification reaches the test device",
  ignore: !saJson || !deviceToken,
  async fn() {
    const client = new FcmClient(JSON.parse(saJson) as ServiceAccount);
    const result = await client.send(deviceToken, "وصلة — اختبار", "لو الإشعار ده وصلك، FCM شغال.", { type: "live_test" });
    assertEquals(result, { kind: "sent" });
  },
});
