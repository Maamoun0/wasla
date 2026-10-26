// KYC-01 end to end on a local stack (supabase start): submit (real Storage
// upload) -> moderator approval -> ✓ badge visible to everyone -> documents
// deleted after the retention window, decision kept. Rejected documents stay
// through the 30-day appeal window.
// Needs WASLA_SUPABASE_URL (localhost), WASLA_SUPABASE_ANON_KEY and
// WASLA_SUPABASE_SERVICE_ROLE_KEY; never point it at a hosted project.
//   deno test --no-lock --no-check --allow-env --allow-net supabase/tests/kyc/kyc_flow.local.ts
import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { handleSubmitKyc } from "../../functions/submit-kyc-request/handler.ts";
import { supabaseDeps as submitDeps } from "../../functions/submit-kyc-request/deps.ts";
import { handlePurgeKyc } from "../../functions/purge-kyc-documents/handler.ts";
import { supabaseDeps as purgeDeps } from "../../functions/purge-kyc-documents/deps.ts";

const url = Deno.env.get("WASLA_SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("WASLA_SUPABASE_ANON_KEY") ?? "";
const key = Deno.env.get("WASLA_SUPABASE_SERVICE_ROLE_KEY") ?? "";
const enabled = /^http:\/\/(localhost|127\.0\.0\.1)/.test(url) && anonKey !== "" && key !== "";
const opts = { auth: { persistSession: false, autoRefreshToken: false } };
const JPEG_B64 = btoa(String.fromCharCode(0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1, 0xff, 0xd9));

async function createUser(admin: SupabaseClient, label: string) {
  const email = `${label}-${crypto.randomUUID()}@test.local`;
  const password = "Test-password-123!";
  const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
  if (error) throw error;
  const client = createClient(url, anonKey, opts);
  const { data: session, error: signInError } = await client.auth.signInWithPassword({ email, password });
  if (signInError) throw signInError;
  return { id: data.user.id, token: session.session!.access_token };
}

const submit = (token: string) =>
  new Request("http://local/submit-kyc-request", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
    body: JSON.stringify({ full_name: "مستخدم تجريبي", national_id: "29001011234567", front_image: JPEG_B64, back_image: JPEG_B64 }),
  });
const purge = () => new Request("http://local/purge-kyc", { method: "POST", headers: { Authorization: `Bearer ${key}` } });

Deno.test({
  name: "submit -> approve -> badge -> documents deleted after 7 days; rejected kept until 30 days",
  ignore: !enabled,
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const admin = createClient(url, key, opts);
    const anon = createClient(url, anonKey, opts);
    const approvedUser = await createUser(admin, "kyc-ok");
    const rejectedUser = await createUser(admin, "kyc-no");
    const moderator = await createUser(admin, "kyc-mod");
    const folderOf = async (userId: string) =>
      (await admin.storage.from("id-documents").list(`${userId}/kyc`)).data ?? [];

    try {
      // 1. Submit through the real handler (uploads to the private bucket).
      for (const u of [approvedUser, rejectedUser]) {
        const res = await handleSubmitKyc(submit(u.token), submitDeps(admin));
        assertEquals(res.status, 200, await res.clone().text());
      }
      const { data: requests } = await admin.from("user_verifications")
        .select("id, user_id, document_url, document_back_url")
        .in("user_id", [approvedUser.id, rejectedUser.id]);
      assertEquals(requests?.length, 2);
      const req = (userId: string) => requests!.find((r) => r.user_id === userId)!;
      const { data: files } = await admin.storage.from("id-documents").list(req(approvedUser.id).document_url.split("/").slice(0, 3).join("/"));
      assertEquals(files?.map((f) => f.name).sort(), ["back.jpg", "front.jpg"]);

      // The documents are not public.
      const { data: anonList } = await anon.storage.from("id-documents").list(`${approvedUser.id}/kyc`);
      assertEquals(anonList ?? [], []);

      // 2. Moderator decisions, as the admin panel's server actions make them.
      const decide = (userId: string, action: string) =>
        admin.rpc("moderate_kyc", { p_verification_id: req(userId).id, p_moderator_id: moderator.id, p_action: action, p_reason: null });
      assertEquals((await decide(approvedUser.id, "approved")).data, { success: true });
      assertEquals((await decide(rejectedUser.id, "rejected")).data, { success: true });

      // 3. Badge: visible to anyone reading the public profile (profile pages, ads).
      const { data: profile } = await anon.from("users").select("is_id_verified").eq("id", approvedUser.id).single();
      assertEquals(profile?.is_id_verified, true);

      // 4. Retention: approved after 7 days, rejected only after 30.
      const age = (userId: string, days: number) =>
        admin.from("user_verifications").update({ decided_at: new Date(Date.now() - days * 86_400_000).toISOString() })
          .eq("id", req(userId).id);
      await age(approvedUser.id, 8);
      await age(rejectedUser.id, 29);
      const first = await (await handlePurgeKyc(purge(), purgeDeps(admin, key))).json();
      assertEquals(first.purged, 1);
      assertEquals((await folderOf(approvedUser.id)).length, 0, "approved documents deleted from Storage");
      assert((await folderOf(rejectedUser.id)).length > 0, "rejected documents kept during the appeal window");

      const { data: decision } = await admin.from("user_verifications")
        .select("status, document_url, document_back_url, documents_deleted_at").eq("id", req(approvedUser.id).id).single();
      assertEquals([decision?.status, decision?.document_url, decision?.document_back_url], ["approved", null, null]);
      assert(decision?.documents_deleted_at, "deletion time recorded");

      await age(rejectedUser.id, 31);
      const second = await (await handlePurgeKyc(purge(), purgeDeps(admin, key))).json();
      assertEquals(second.purged, 1);
      assertEquals((await folderOf(rejectedUser.id)).length, 0, "rejected documents deleted after 30 days");

      const { data: stillVerified } = await anon.from("users").select("is_id_verified").eq("id", approvedUser.id).single();
      assertEquals(stillVerified?.is_id_verified, true, "badge stays after the documents are gone");
    } finally {
      for (const u of [approvedUser, rejectedUser]) {
        const leftovers = await folderOf(u.id);
        for (const dir of leftovers) {
          const { data } = await admin.storage.from("id-documents").list(`${u.id}/kyc/${dir.name}`);
          if (data?.length) await admin.storage.from("id-documents").remove(data.map((f) => `${u.id}/kyc/${dir.name}/${f.name}`));
        }
      }
      for (const u of [approvedUser, rejectedUser, moderator]) await admin.auth.admin.deleteUser(u.id);
    }
  },
});
