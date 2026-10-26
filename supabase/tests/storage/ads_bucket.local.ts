// Ad image storage through the real Storage API of a local stack
// (supabase start). Covers what SQL tests cannot: delete/overwrite through
// the API, MIME and size limits enforced by storage-api.
// Needs WASLA_SUPABASE_URL (localhost), WASLA_SUPABASE_ANON_KEY and
// WASLA_SUPABASE_SERVICE_ROLE_KEY; never point it at a hosted project.
//   deno test --no-lock --no-check --allow-env --allow-net supabase/tests/storage/ads_bucket.local.ts
import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const url = Deno.env.get("WASLA_SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("WASLA_SUPABASE_ANON_KEY") ?? "";
const serviceKey = Deno.env.get("WASLA_SUPABASE_SERVICE_ROLE_KEY") ?? "";
const enabled = /^http:\/\/(localhost|127\.0\.0\.1)/.test(url) && anonKey !== "" && serviceKey !== "";

const opts = { auth: { persistSession: false, autoRefreshToken: false } };
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1, 0xff, 0xd9]);

async function signedInUser(admin: SupabaseClient, label: string) {
  const email = `${label}-${crypto.randomUUID()}@test.local`;
  const password = "Test-password-123!";
  const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
  if (error) throw error;
  const client = createClient(url, anonKey, opts);
  const { error: signInError } = await client.auth.signInWithPassword({ email, password });
  if (signInError) throw signInError;
  return { id: data.user.id, client };
}

Deno.test({
  name: "ads bucket: owner-only writes, public read, images only, 5 MB max (local Storage API)",
  ignore: !enabled,
  sanitizeOps: false,
  sanitizeResources: false,
  async fn(t) {
    const admin = createClient(url, serviceKey, opts);
    const a = await signedInUser(admin, "a");
    const b = await signedInUser(admin, "b");
    const anon = createClient(url, anonKey, opts);
    const aPath = `${a.id}/draft-1/img-1.jpg`;

    try {
      await t.step("owner uploads into own folder", async () => {
        const { error } = await a.client.storage.from("ads").upload(aPath, JPEG, { contentType: "image/jpeg" });
        assertEquals(error, null);
      });

      await t.step("anyone can read it through the public URL", async () => {
        const res = await fetch(admin.storage.from("ads").getPublicUrl(aPath).data.publicUrl);
        await res.body?.cancel();
        assertEquals(res.status, 200);
      });

      await t.step("another user cannot overwrite it", async () => {
        const { error } = await b.client.storage.from("ads").upload(aPath, JPEG, { contentType: "image/jpeg", upsert: true });
        assert(error !== null, "overwrite must be refused");
      });

      await t.step("another user cannot delete it", async () => {
        await b.client.storage.from("ads").remove([aPath]);
        const { data } = await admin.storage.from("ads").list(`${a.id}/draft-1`);
        assertEquals(data?.map((f) => f.name), ["img-1.jpg"]);
      });

      await t.step("another user cannot upload into the owner's folder", async () => {
        const { error } = await b.client.storage.from("ads").upload(`${a.id}/draft-1/evil.jpg`, JPEG, { contentType: "image/jpeg" });
        assert(error !== null);
      });

      await t.step("anonymous upload is refused", async () => {
        const { error } = await anon.storage.from("ads").upload(`${a.id}/anon.jpg`, JPEG, { contentType: "image/jpeg" });
        assert(error !== null);
      });

      await t.step("non-image content is refused", async () => {
        const { error } = await a.client.storage.from("ads").upload(`${a.id}/draft-1/notes.txt`, new TextEncoder().encode("hi"), { contentType: "text/plain" });
        assert(error !== null);
      });

      await t.step("files over 5 MB are refused", async () => {
        const big = new Uint8Array(5 * 1024 * 1024 + 1);
        big.set(JPEG);
        const { error } = await a.client.storage.from("ads").upload(`${a.id}/draft-1/big.jpg`, big, { contentType: "image/jpeg" });
        assert(error !== null);
      });

      await t.step("owner can delete own image", async () => {
        await a.client.storage.from("ads").remove([aPath]);
        const { data } = await admin.storage.from("ads").list(`${a.id}/draft-1`);
        assertEquals(data?.length ?? 0, 0);
      });
    } finally {
      const { data: leftovers } = await admin.storage.from("ads").list(`${a.id}/draft-1`);
      if (leftovers?.length) await admin.storage.from("ads").remove(leftovers.map((f) => `${a.id}/draft-1/${f.name}`));
      await admin.auth.admin.deleteUser(a.id);
      await admin.auth.admin.deleteUser(b.id);
    }
  },
});
