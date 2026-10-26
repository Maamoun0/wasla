// End-to-end account deletion against a local stack (supabase start):
// request -> (30 days later) purge through the real Storage and Auth APIs.
// Needs WASLA_SUPABASE_URL (localhost), WASLA_SUPABASE_ANON_KEY and
// WASLA_SUPABASE_SERVICE_ROLE_KEY; never point it at a hosted project.
// Not picked up by a plain `deno test`; run it explicitly:
//   deno test --no-lock --no-check --allow-env --allow-net purge-deleted-accounts/integration.local.ts
import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { handlePurge } from "./handler.ts";
import { supabaseDeps } from "./deps.ts";

const url = Deno.env.get("WASLA_SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("WASLA_SUPABASE_ANON_KEY") ?? "";
const key = Deno.env.get("WASLA_SUPABASE_SERVICE_ROLE_KEY") ?? "";
const enabled = /^http:\/\/(localhost|127\.0\.0\.1)/.test(url) && anonKey !== "" && key !== "";
const opts = { auth: { persistSession: false, autoRefreshToken: false } };
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1, 0xff, 0xd9]);

Deno.test({
  name: "request deletion -> sign-in blocked -> purge removes files, auth user and profile (local Supabase)",
  ignore: !enabled,
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const admin = createClient(url, key, opts);
    const email = `delete-${crypto.randomUUID()}@test.local`;
    const password = "Test-password-123!";
    const { data: created, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
    if (error) throw error;
    const userId = created.user.id;

    try {
      const user = createClient(url, anonKey, opts);
      await user.auth.signInWithPassword({ email, password });
      await user.storage.from("ads").upload(`${userId}/draft-1/img-1.jpg`, JPEG, { contentType: "image/jpeg" });
      await user.storage.from("ads").upload(`${userId}/draft-2/img-1.jpg`, JPEG, { contentType: "image/jpeg" });
      await user.storage.from("avatars").upload(`${userId}/avatar.jpg`, JPEG, { contentType: "image/jpeg" });

      const { data: tx, error: txError } = await admin.from("transactions").insert({
        user_id: userId, type: "ad_boost", amount: 60, payment_method: "card", payment_gateway: "paymob",
        gateway_transaction_id: `order-${userId}`, status: "completed",
        metadata: { billing: { userEmail: email }, gateway: { id: 4242, order_id: `order-${userId}`, amount_cents: 6000 } },
      }).select("id").single();
      if (txError) throw txError;

      const { data: req, error: reqError } = await user.rpc("request_account_deletion", { p_reason: "test" }).single<{ id: string }>();
      if (reqError) throw reqError;

      const again = createClient(url, anonKey, opts);
      const { error: signInError } = await again.auth.signInWithPassword({ email, password });
      assert(/banned/i.test(signInError?.message ?? ""), `sign-in is refused as banned, got: ${signInError?.message}`);

      // Fast-forward the 30-day window.
      await admin.from("account_deletion_requests").update({ scheduled_for: new Date(Date.now() - 60_000).toISOString() }).eq("id", req!.id);

      const res = await handlePurge(
        new Request("http://local/purge", { method: "POST", headers: { Authorization: `Bearer ${key}` } }),
        supabaseDeps(admin, key),
      );
      const summary = await res.json();
      assertEquals(summary.purged, 1);
      assertEquals(summary.files_removed, 3);

      const { data: authUser } = await admin.auth.admin.getUserById(userId);
      assertEquals(authUser.user, null);
      const { data: profile } = await admin.from("users").select("id").eq("id", userId);
      assertEquals(profile, []);
      const { data: ads } = await admin.storage.from("ads").list(userId);
      assertEquals(ads, []);
      const { data: avatars } = await admin.storage.from("avatars").list(userId);
      assertEquals(avatars, []);
      const { data: closed } = await admin.from("account_deletion_requests").select("status, user_id").eq("id", req!.id).single();
      assertEquals(closed, { status: "completed", user_id: null });

      // The payment record is kept, without anything linking it to the person.
      const { data: kept } = await admin.from("transactions").select("user_id, amount, gateway_transaction_id, metadata").eq("id", tx!.id).single();
      assertEquals(kept, {
        user_id: null,
        amount: 60,
        gateway_transaction_id: `order-${userId}`,
        metadata: { gateway: { id: 4242, order_id: `order-${userId}`, amount_cents: 6000 } },
      });
      await admin.from("transactions").delete().eq("id", tx!.id);
    } finally {
      await admin.auth.admin.deleteUser(userId).catch(() => {});
    }
  },
});
