import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { validateAdImages } from "./images.ts";

const ORIGIN = "https://abc.supabase.co";
const USER = "11111111-1111-1111-1111-111111111111";
const own = (n: number) => ({ url: `${ORIGIN}/storage/v1/object/public/ads/${USER}/draft-1/img-${n}.jpg`, sort_order: n });

Deno.test("images in the caller's own ads folder are accepted", () => {
  assertEquals(validateAdImages([own(0), own(1)], USER, [ORIGIN]), null);
  assertEquals(validateAdImages(undefined, USER, [ORIGIN]), null);
  assertEquals(validateAdImages([], USER, [ORIGIN]), null);
});

Deno.test("another user's folder is rejected", () => {
  const other = { url: `${ORIGIN}/storage/v1/object/public/ads/22222222-2222-2222-2222-222222222222/x.jpg` };
  assertEquals(validateAdImages([other], USER, [ORIGIN]), "الصور يجب أن تكون من مجلدك");
});

Deno.test("path traversal out of the folder is rejected", () => {
  const sneaky = { url: `${ORIGIN}/storage/v1/object/public/ads/${USER}/%2E%2E/other/x.jpg` };
  assertEquals(validateAdImages([sneaky], USER, [ORIGIN]), "الصور يجب أن تكون من مجلدك");
});

Deno.test("external hosts and other buckets are rejected", () => {
  assertEquals(validateAdImages([{ url: `https://evil.example/storage/v1/object/public/ads/${USER}/x.jpg` }], USER, [ORIGIN]),
    "الصور يجب أن تكون مرفوعة على وصلة");
  assertEquals(validateAdImages([{ url: `${ORIGIN}/storage/v1/object/public/avatars/${USER}/x.jpg` }], USER, [ORIGIN]),
    "الصور يجب أن تكون من مجلدك");
  assertEquals(validateAdImages([{ url: "not a url" }], USER, [ORIGIN]), "رابط صورة غير صالح");
});

Deno.test("more than 8 images are rejected", () => {
  assertEquals(validateAdImages(Array.from({ length: 9 }, (_, i) => own(i)), USER, [ORIGIN]), "الحد الأقصى 8 صور للإعلان");
});
