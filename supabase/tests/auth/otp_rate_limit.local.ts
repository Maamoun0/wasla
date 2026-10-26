// OTP-01: SMS OTP limits are enforced by Supabase Auth itself, not just by
// the app. Runs against a local stack (supabase start) using the local-only
// test number from supabase/config.toml. Needs WASLA_SUPABASE_URL (localhost)
// and WASLA_SUPABASE_ANON_KEY; never point it at a hosted project.
//   deno test --no-lock --no-check --allow-env --allow-net supabase/tests/auth/otp_rate_limit.local.ts
import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const url = Deno.env.get("WASLA_SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("WASLA_SUPABASE_ANON_KEY") ?? "";
const enabled = /^http:\/\/(localhost|127\.0\.0\.1)/.test(url) && anonKey !== "";
const PHONE = "+201000000101";

Deno.test({
  name: "Auth refuses a second OTP for the same number within 60 seconds",
  ignore: !enabled,
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const client = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });

    // A run less than a minute ago may still hold the number: wait it out.
    let first = await client.auth.signInWithOtp({ phone: PHONE });
    const leftover = Number(/(\d+)\s*seconds?/.exec(first.error?.message ?? "")?.[1]);
    if (first.error?.status === 429 && leftover) {
      await new Promise((r) => setTimeout(r, (leftover + 1) * 1000));
      first = await client.auth.signInWithOtp({ phone: PHONE });
    }
    assertEquals(first.error, null, `first request should be sent, got: ${first.error?.message}`);

    // Even after a short pause the number stays locked for the full window.
    await new Promise((r) => setTimeout(r, 7000));
    const second = await client.auth.signInWithOtp({ phone: PHONE });
    assert(second.error !== null, "second request within 60s must be refused");
    assertEquals(second.error?.status, 429);
    const wait = Number(/(\d+)\s*seconds?/.exec(second.error?.message ?? "")?.[1]);
    assert(wait >= 45 && wait <= 60, `server should ask to wait ~53s, got: ${second.error?.message}`);
  },
});
