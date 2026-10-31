// Publishes a draft ad: validates input, runs the AI review on the server
// (never callable by a client), and stores the ad as 'pending' for a
// moderator. The AI verdict only orders the moderation queue.
import { buildAdFields, FieldDefinition } from "./fields.ts";
import { validateAdImages } from "./images.ts";
import type { AdText, ModerationResult } from "./moderation.ts";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export interface NewAd {
  userId: string;
  tempDraftId: string;
  categoryId: number;
  title: string;
  description: string;
  adType: string;
  price: number | null;
  priceType: string;
  cityId: number;
  districtId: number | null;
  latitude: number | null;
  longitude: number | null;
  aiRiskLevel: ModerationResult["riskLevel"];
  aiNotes: string;
  aiLayer: number;
  images: unknown[];
  fields: unknown[];
}

/** Why posting is refused (posting_block / create_ad_transaction). */
export type PostingBlock = "maintenance" | "trust_score_too_low" | "ad_limit_reached" | "image_limit_exceeded";
export const POSTING_BLOCKS: readonly PostingBlock[] = ["maintenance", "trust_score_too_low", "ad_limit_reached", "image_limit_exceeded"];

export class PostingBlockedError extends Error {
  constructor(readonly block: PostingBlock) {
    super(block);
  }
}

const POSTING_BLOCK_RESPONSES: Record<PostingBlock, [number, string]> = {
  maintenance: [503, "النشر متوقف مؤقتاً للصيانة. حاول بعد شوية."],
  trust_score_too_low: [403, "مؤشر الثقة في حسابك أقل من المطلوب للنشر. وثّق هويتك عشان ترفعه."],
  ad_limit_reached: [403, "وصلت للحد الأقصى لعدد الإعلانات في باقتك. احذف إعلاناً أو رقِّ باقتك للنشر."],
  image_limit_exceeded: [400, "عدد الصور أكبر من المسموح في باقتك."],
};

function postingBlockedResponse(block: PostingBlock): Response {
  const [status, message] = POSTING_BLOCK_RESPONSES[block];
  return json({ error: message, code: block }, status);
}

export interface CreateAdDeps {
  allowedImageOrigins: string[];
  authenticate(token: string): Promise<string | null>;
  findAdByDraft(tempDraftId: string, userId: string): Promise<string | null>;
  getCategoryName(categoryId: number): Promise<string>;
  getCategoryFields(categoryId: number): Promise<FieldDefinition[]>;
  moderationAllowed(userId: string): Promise<boolean>;
  /** The admin switch ai_moderation_enabled (off: every ad goes straight to human review). */
  aiModerationEnabled(): Promise<boolean>;
  /** Why this ad may not be posted, if anything (checked before the AI review). */
  postingBlock(userId: string, imageCount: number): Promise<PostingBlock | null>;
  moderate(ad: AdText): Promise<ModerationResult>;
  createAd(ad: NewAd): Promise<string>;
  logModeration(userId: string, tempDraftId: string, result: ModerationResult, adId: string | null): Promise<void>;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

const MANUAL_REVIEW = (error: string): ModerationResult => ({
  riskLevel: "unreviewed",
  notes: "لم تكتمل المراجعة الآلية، الإعلان بانتظار مراجعة المشرف.",
  layer: 0,
  model: null,
  error,
});

export async function handleCreateAd(req: Request, deps: CreateAdDeps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "طريقة الطلب غير مدعومة" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "رأس المصادقة (Authorization Header) مفقود." }, 401);
  const userId = await deps.authenticate(authHeader.substring(7));
  if (!userId) return json({ error: "غير مصرح: رمز الجلسة غير صالح أو منتهي الصلاحية." }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "محتوى الطلب غير صالح" }, 400);
  }

  const tempDraftId = typeof body.temp_draft_id === "string" ? body.temp_draft_id : "";
  const categoryId = Number(body.category_id);
  const title = typeof body.title === "string" ? body.title.trim() : "";
  const description = typeof body.description === "string" ? body.description.trim() : "";
  const cityId = Number(body.city_id);
  if (!tempDraftId || !categoryId || !title || !description || !cityId) {
    return json({ error: "البيانات الأساسية للإعلان غير مكتملة." }, 400);
  }

  const imagesError = validateAdImages(body.images, userId, deps.allowedImageOrigins);
  if (imagesError) return json({ error: imagesError }, 400);

  const existing = await deps.findAdByDraft(tempDraftId, userId);
  if (existing) return json({ success: true, ad_id: existing, message: "تم نشر الإعلان مسبقاً بنجاح." }, 200);

  const { rows: fields, missingRequired, invalid } = buildAdFields(
    await deps.getCategoryFields(categoryId),
    body.dynamic_fields as Record<string, unknown> | undefined,
  );
  if (missingRequired.length > 0 || invalid.length > 0) {
    return json({
      error: missingRequired.length > 0
        ? `حقول مطلوبة غير مكتملة: ${missingRequired.join("، ")}`
        : `قيم غير صالحة في: ${invalid.join("، ")}`,
      missing_fields: missingRequired,
      invalid_fields: invalid,
    }, 400);
  }

  const imageCount = Array.isArray(body.images) ? body.images.length : 0;
  const blocked = await deps.postingBlock(userId, imageCount);
  if (blocked) return postingBlockedResponse(blocked);

  const price = body.price === null || body.price === undefined ? null : Number(body.price);
  let moderation: ModerationResult;
  if (!(await deps.aiModerationEnabled())) {
    moderation = MANUAL_REVIEW("ai_disabled");
  } else if (!(await deps.moderationAllowed(userId))) {
    moderation = MANUAL_REVIEW("daily_ai_limit");
  } else {
    try {
      moderation = await deps.moderate({ title, description, price, category: await deps.getCategoryName(categoryId) });
    } catch (err) {
      moderation = MANUAL_REVIEW(err instanceof Error ? err.message : String(err));
    }
  }

  let adId: string;
  try {
    adId = await deps.createAd({
    userId,
    tempDraftId,
    categoryId,
    title,
    description,
    adType: typeof body.ad_type === "string" ? body.ad_type : "offering",
    price,
    priceType: typeof body.price_type === "string" ? body.price_type : "fixed",
    cityId,
    districtId: body.district_id ? Number(body.district_id) : null,
    latitude: typeof body.latitude === "number" ? body.latitude : null,
    longitude: typeof body.longitude === "number" ? body.longitude : null,
    aiRiskLevel: moderation.riskLevel,
    aiNotes: moderation.notes,
    aiLayer: moderation.layer,
    images: Array.isArray(body.images) ? body.images : [],
    fields,
  });
  } catch (err) {
    // The database re-checks atomically (two requests at once, or a switch flipped meanwhile).
    if (err instanceof PostingBlockedError) return postingBlockedResponse(err.block);
    throw err;
  }

  await deps.logModeration(userId, tempDraftId, moderation, adId);
  return json({ success: true, ad_id: adId, message: "تم إرسال الإعلان للمراجعة." }, 200);
}
