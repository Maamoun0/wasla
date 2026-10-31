// Live check of the SMS provider configured in a dev Supabase project's Auth.
// Two runs, because the code arrives on a real phone:
//   1. WASLA_TEST_PHONE only: sends the OTP.
//   2. WASLA_TEST_PHONE + WASLA_TEST_OTP (the code you received): verifies it.
// Needs WASLA_DEV_SUPABASE_URL and WASLA_DEV_SUPABASE_ANON_KEY of a dev project
// (never production). Sending twice within 60 s is refused by design.
//   deno test --no-lock --allow-env --allow-net supabase/tests/live/sms_otp.live.ts
import { assert } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const url = Deno.env.get("WASLA_DEV_SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("WASLA_DEV_SUPABASE_ANON_KEY") ?? "";
const phone = Deno.env.get("WASLA_TEST_PHONE") ?? "";
const otp = Deno.env.get("WASLA_TEST_OTP") ?? "";
const ready = url !== "" && anonKey !== "" && phone !== "";
const client = () => createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });

Deno.test({
  name: "step 1: the provider sends the OTP",
  ignore: !ready || otp !== "",
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
  ignore: !ready || otp === "",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const { data, error } = await client().auth.verifyOtp({ phone, token: otp, type: "sms" });
    assert(!error, error?.message);
    assert(data.session, "a session is returned");
  },
});
