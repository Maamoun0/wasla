// Runs the real dispatcher against a local Supabase stack (supabase start)
// with a fake FCM sender, to check the TypeScript <-> SQL contract.
// Skipped unless WASLA_SUPABASE_URL (localhost) and
// WASLA_SUPABASE_SERVICE_ROLE_KEY are set; never point it at a hosted project.
// Not picked up by a plain `deno test` (needs a running stack); run it explicitly:
//   deno test --no-lock --no-check --allow-env --allow-net dispatch-notifications/integration.local.ts
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { handleDispatch } from "./handler.ts";
import { supabaseDeps } from "./deps.ts";

const url = Deno.env.get("WASLA_SUPABASE_URL") ?? "";
const key = Deno.env.get("WASLA_SUPABASE_SERVICE_ROLE_KEY") ?? "";
const enabled = /^http:\/\/(localhost|127\.0\.0\.1)/.test(url) && key !== "";

Deno.test({
  name: "approval -> outbox -> dispatcher -> sent, dead token deactivated (local Supabase)",
  ignore: !enabled,
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: created, error: userError } = await db.auth.admin.createUser({
      email: `dispatch-${Date.now()}@test.local`,
      password: "Test-password-123!",
      email_confirm: true,
    });
    if (userError) throw userError;
    const userId = created.user.id;

    try {
      await db.from("push_tokens").insert([
        { user_id: userId, token: `live-${userId}`, platform: "android" },
        { user_id: userId, token: `dead-${userId}`, platform: "ios" },
      ]);
      const { data: cat } = await db.from("categories").select("id").eq("slug", "cars").single();
      const { data: city } = await db.from("cities").select("id").limit(1).single();
      const { data: ad, error: adError } = await db.from("ads").insert({
        user_id: userId, category_id: cat!.id, title: "اختبار الإشعارات", description: "desc", city_id: city!.id,
      }).select("id").single();
      if (adError) throw adError;

      // Approve exactly as the admin panel does.
      const { data: mod } = await db.from("users").select("id").eq("id", userId).single();
      const { error: modError } = await db.rpc("moderate_ad", {
        p_ad_id: ad!.id, p_moderator_id: mod!.id, p_action: "approved", p_reason: null,
      });
      if (modError) throw modError;

      const sentTo: string[] = [];
      const deps = supabaseDeps(db, key, (token) => {
        sentTo.push(token);
        return Promise.resolve(token.startsWith("dead-") ? { kind: "invalid_token" } : { kind: "sent" });
      });
      const res = await handleDispatch(
        new Request("http://local/dispatch", { method: "POST", headers: { Authorization: `Bearer ${key}` } }),
        deps,
      );
      assertEquals(res.status, 200);

      const { data: row } = await db.from("notifications_outbox").select("status, data")
        .eq("user_id", userId).single();
      assertEquals(row!.status, "sent");
      assertEquals(row!.data.type, "ad_status_change");
      assertEquals(sentTo.sort(), [`dead-${userId}`, `live-${userId}`]);

      const { data: tokens } = await db.from("push_tokens").select("token, is_active").eq("user_id", userId).order("token");
      assertEquals(tokens, [
        { token: `dead-${userId}`, is_active: false },
        { token: `live-${userId}`, is_active: true },
      ]);
    } finally {
      await db.auth.admin.deleteUser(userId);
    }
  },
});
