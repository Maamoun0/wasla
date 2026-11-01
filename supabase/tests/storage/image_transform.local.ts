// NFR-1.2 on a local stack (supabase start with imgproxy): an ad photo
// uploaded as the app does is served resized, compressed and as WebP from
// /storage/v1/render/image, while /storage/v1/object ignores those params.
// Needs WASLA_SUPABASE_URL (localhost) and WASLA_SUPABASE_SERVICE_ROLE_KEY.
//   deno test --no-lock --no-check --allow-env --allow-net --allow-read supabase/tests/storage/image_transform.local.ts
import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const url = Deno.env.get("WASLA_SUPABASE_URL") ?? "";
const key = Deno.env.get("WASLA_SUPABASE_SERVICE_ROLE_KEY") ?? "";
const enabled = /^http:\/\/(localhost|127\.0\.0\.1)/.test(url) && key !== "";
const IMAGE = new URL("../../../frontend/mobile/wasla/assets/images/logo.png", import.meta.url);

Deno.test({
  name: "ad photos are served resized and as WebP from the render endpoint",
  ignore: !enabled,
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
    const bytes = await Deno.readFile(IMAGE);
    const path = `${crypto.randomUUID()}/test/photo.png`;
    const { error } = await admin.storage.from("ads").upload(path, bytes, { contentType: "image/png" });
    assertEquals(error, null, error?.message);
    try {
      // What ImageUtils.thumbnail builds from the object URL.
      const object = `${url}/storage/v1/object/public/ads/${path}`;
      const render = `${url}/storage/v1/render/image/public/ads/${path}?width=200&quality=70`;

      const original = await fetch(`${object}?width=200&quality=70`, { headers: { Accept: "image/webp,image/*" } });
      const originalBytes = (await original.arrayBuffer()).byteLength;
      assertEquals(original.headers.get("content-type"), "image/png", "the object endpoint ignores width/quality");

      const small = await fetch(render, { headers: { Accept: "image/webp,image/*" } });
      assertEquals(small.status, 200, await small.clone().text());
      assertEquals(small.headers.get("content-type"), "image/webp", "WebP when the client accepts it");
      const smallBytes = (await small.arrayBuffer()).byteLength;
      assert(smallBytes < originalBytes / 2, `thumbnail ${smallBytes} B should be far smaller than ${originalBytes} B`);
    } finally {
      await admin.storage.from("ads").remove([path]);
    }
  },
});
