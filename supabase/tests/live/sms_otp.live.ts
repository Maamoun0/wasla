// Live check of SMS delivery for a dev project. OTPs go Auth -> Send SMS Hook
// (send-sms-hook) -> the provider chosen by SMS_PROVIDER.
//
//   0. Provider only (SMS_PROVIDER + its credentials + WASLA_TEST_PHONE):
//      sends one test message straight through the provider code, before
//      anything is deployed.
//   1. WASLA_DEV_SUPABASE_URL + WASLA_DEV_SUPABASE_ANON_KEY + WASLA_TEST_PHONE:
//      asks Auth for an OTP, which must arrive through the deployed hook.
//   2. Same, plus WASLA_TEST_OTP (the code you received): verifies it.
// Never point it at production. Asking twice within 60 s is refused by design.
//   deno test --config supabase/functions/deno.json --no-lock --allow-env --allow-net --env-file=supabase/functions/.env supabase/tests/live/sms_otp.live.ts
import { assert } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { providerFromEnv } from "../../functions/send-sms-hook/providers/registry.ts";

const url = Deno.env.get("WASLA_DEV_SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("WASLA_DEV_SUPABASE_ANON_KEY") ?? "";
const phone = Deno.env.get("WASLA_TEST_PHONE") ?? "";
const otp = Deno.env.get("WASLA_TEST_OTP") ?? "";
const providerReady = !!Deno.env.get("SMS_PROVIDER") && phone !== "";
const authReady = url !== "" && anonKey !== "" && phone !== "";
const client = () => createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });

Deno.test({
  name: "step 0: the provider credentials deliver a message",
  ignore: !providerReady || otp !== "",
  async fn() {
    const { provider, channel } = providerFromEnv((k) => Deno.env.get(k));
    await provider.send({ to: phone, body: "وصلة: رسالة اختبار لمزوّد الرسائل.", channel }, AbortSignal.timeout(10000));
    console.log(`Sent via ${provider.name} (${channel}). Check the phone.`);
  },
});

Deno.test({
  name: "step 1: Auth sends the OTP through the hook",
  ignore: !authReady || otp !== "",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const { error } = await client().auth.signInWithOtp({ phone, options: { shouldCreateUser: true } });
    assert(!error, error?.message);
    console.log(`OTP sent to ${phone}. Run again with WASLA_TEST_OTP=<code>.`);
  },
});

Deno.test({
  name: "step 2: the received code signs in",
  ignore: !authReady || otp === "",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const { data, error } = await client().auth.verifyOtp({ phone, token: otp, type: "sms" });
    assert(!error, error?.message);
    assert(data.session, "a session is returned");
  },
});
