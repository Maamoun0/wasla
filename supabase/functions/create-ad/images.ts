// Ad images must be public URLs of objects the caller uploaded to their own
// folder of the "ads" bucket: {origin}/storage/v1/object/public/ads/{userId}/...
// (storage policies only allow writes there). The per-plan photo limit is
// enforced in the database (plan_violation); this is only a sanity cap at the
// largest plan's limit.

export const MAX_AD_IMAGES = 20;

export interface AdImageInput {
  url?: unknown;
  is_primary?: unknown;
  sort_order?: unknown;
}

export function validateAdImages(
  images: unknown,
  userId: string,
  allowedOrigins: string[],
): string | null {
  if (images === undefined || images === null) return null;
  if (!Array.isArray(images)) return "قائمة الصور غير صالحة";
  if (images.length > MAX_AD_IMAGES) return `الحد الأقصى ${MAX_AD_IMAGES} صور للإعلان`;

  const prefix = `/storage/v1/object/public/ads/${userId}/`;
  for (const img of images as AdImageInput[]) {
    if (typeof img?.url !== "string") return "رابط صورة غير صالح";
    let parsed: URL;
    try {
      parsed = new URL(img.url);
    } catch {
      return "رابط صورة غير صالح";
    }
    if (!allowedOrigins.includes(parsed.origin)) return "الصور يجب أن تكون مرفوعة على وصلة";
    const path = decodeURIComponent(parsed.pathname);
    if (!path.startsWith(prefix) || path.includes("..")) return "الصور يجب أن تكون من مجلدك";
  }
  return null;
}
