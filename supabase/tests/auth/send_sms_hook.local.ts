// Send SMS Hook end to end on a local stack: real Auth (GoTrue) -> signed
// request -> send-sms-hook in the local edge runtime -> Twilio provider ->
// a fake Twilio started here on the host (TWILIO_API_BASE in supabase/.env).
// Checks the code that reaches the provider signs the user in, Auth's OTP
// limits still apply with the hook, provider failures reach the app as
// errors, unsigned calls are refused, and the OTP appears in no container log.
// Needs WASLA_SUPABASE_URL (localhost) and WASLA_SUPABASE_ANON_KEY.
//   deno test --no-lock --no-check --allow-env --allow-net --allow-run=docker supabase/tests/auth/send_sms_hook.local.ts
import { assert, assertEquals, assertMatch } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const url = Deno.env.get("WASLA_SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("WASLA_SUPABASE_ANON_KEY") ?? "";
const enabled = /^http:\/\/(localhost|127\.0\.0\.1)/.test(url) && anonKey !== "";
const FAKE_TWILIO_PORT = 54399;
// Container names follow project_id in supabase/config.toml.
const CONTAINERS = ["supabase_auth_wasla", "supabase_edge_runtime_wasla"];

interface Captured {
  to: string;
  body: string;
  from: string;
}

// Random Egyptian-format numbers so reruns never hit a previous run's 60 s lock.
const randomPhone = () => `+2010${String(Math.floor(Math.random() * 1e8)).padStart(8, "0")}`;
const client = () => createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });

async function containerLogs(name: string, since: string): Promise<string> {
  const out = await new Deno.Command("docker", { args: ["logs", "--since", since, name], stdout: "piped", stderr: "piped" }).output();
  return new TextDecoder().decode(out.stdout) + new TextDecoder().decode(out.stderr);
}

Deno.test({
  name: "Send SMS Hook through real Auth and the edge runtime",
  ignore: !enabled,
  sanitizeOps: false,
  sanitizeResources: false,
  async fn(t) {
    const started = new Date().toISOString();
    const received: Captured[] = [];
    let failNext = false;
    const fakeTwilio = Deno.serve({ hostname: "0.0.0.0", port: FAKE_TWILIO_PORT, onListen() {} }, async (req) => {
      const form = new URLSearchParams(await req.text());
      if (failNext) return Response.json({ code: 21211, message: "Invalid 'To' Phone Number" }, { status: 400 });
      received.push({ to: form.get("To") ?? "", body: form.get("Body") ?? "", from: form.get("From") ?? "" });
      return Response.json({ sid: "SMfake", status: "queued" }, { status: 201 });
    });
    const otps: string[] = [];

    try {
      const phone = randomPhone();

      await t.step("the provider receives the right number and a code that signs in", async () => {
        const { error } = await client().auth.signInWithOtp({ phone });
        assertEquals(error, null, error?.message);
        assertEquals(received.length, 1);
        assertEquals(received[0].to, phone);
        assertEquals(received[0].from, "+15550000000");
        assertMatch(received[0].body, /^رمز التحقق في وصلة: \d{6}\n/);
        const otp = /(\d{6})/.exec(received[0].body)![1];
        otps.push(otp);
        const { data, error: verifyError } = await client().auth.verifyOtp({ phone, token: otp, type: "sms" });
        assertEquals(verifyError, null, verifyError?.message);
        assert(data.session, "the delivered code signs in");
      });

      await t.step("Auth's 60 s per-number limit (OTP-01) still applies with the hook", async () => {
        const other = randomPhone();
        assertEquals((await client().auth.signInWithOtp({ phone: other })).error, null);
        const before = received.length;
        const second = await client().auth.signInWithOtp({ phone: other });
        assertEquals(second.error?.status, 429, second.error?.message);
        assertMatch(second.error?.message ?? "", /\d+\s*seconds?/);
        assertEquals(received.length, before, "the hook is not called for a refused request");
        otps.push(/(\d{6})/.exec(received[before - 1].body)![1]);
      });

      await t.step("a provider failure reaches the app as an error (fail closed)", async () => {
        const failing = randomPhone();
        failNext = true;
        const { error } = await client().auth.signInWithOtp({ phone: failing });
        failNext = false;
        assert(error, "the app gets an error");
        assertEquals(error.status, 500);
        assertMatch(error.message, /SMS provider failed to send the code/);
        // A failed send does not lock the number: the user can retry at once.
        const retry = await client().auth.signInWithOtp({ phone: failing });
        assertEquals(retry.error, null, retry.error?.message);
        otps.push(/(\d{6})/.exec(received[received.length - 1].body)![1]);
      });

      await t.step("unsigned calls to the function are refused", async () => {
        const res = await fetch(`${url}/functions/v1/send-sms-hook`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ user: { phone: "201012345678" }, sms: { otp: "123456" } }),
        });
        assertEquals(res.status, 401);
        assertEquals((await res.json()).error.message, "invalid webhook signature");
      });

      await t.step("no OTP appears in the Auth or edge-runtime logs", async () => {
        for (const name of CONTAINERS) {
          const logs = await containerLogs(name, started);
          for (const otp of otps) assert(!logs.includes(otp), `${name} logged an OTP`);
        }
      });
    } finally {
      await fakeTwilio.shutdown();
    }
  },
});
