import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { corsHeaders, handleCreateAd, POSTING_BLOCKS, PostingBlock, PostingBlockedError } from "./handler.ts";
import type { FieldDefinition } from "./fields.ts";
import { anthropicClassifier, configFromEnv, moderateAd } from "./moderation.ts";
import { reportError } from "../_shared/error_reporting.ts";

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("create-ad: required environment variables are missing");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    const classifier = apiKey ? anthropicClassifier(apiKey) : null;
    const moderationConfig = configFromEnv((k) => Deno.env.get(k));

    // The app builds image URLs from the project URL; PUBLIC_SUPABASE_URL covers
    // setups where this function sees an internal SUPABASE_URL (local development).
    const allowedImageOrigins = [supabaseUrl, Deno.env.get("PUBLIC_SUPABASE_URL") ?? ""]
      .filter(Boolean)
      .map((u) => new URL(u).origin);

    return await handleCreateAd(req, {
      allowedImageOrigins,
      async authenticate(token) {
        const { data, error } = await supabase.auth.getUser(token);
        return error || !data.user ? null : data.user.id;
      },
      async findAdByDraft(tempDraftId, userId) {
        const { data, error } = await supabase.from("ads").select("id")
          .eq("temp_draft_id", tempDraftId).eq("user_id", userId).maybeSingle();
        if (error) throw error;
        return data?.id ?? null;
      },
      async getCategoryName(categoryId) {
        const { data } = await supabase.from("categories").select("name_ar").eq("id", categoryId).maybeSingle();
        return data?.name_ar ?? "غير محدد";
      },
      async getCategoryFields(categoryId) {
        const { data, error } = await supabase.rpc("get_category_fields", { p_category_id: categoryId });
        if (error) throw error;
        return (data ?? []) as FieldDefinition[];
      },
      async moderationAllowed(userId) {
        const { data, error } = await supabase.rpc("ai_moderation_allowed", { p_user_id: userId });
        if (error) throw error;
        return data === true;
      },
      moderate: (ad) => moderateAd(ad, classifier, moderationConfig),
      async aiModerationEnabled() {
        const { data, error } = await supabase.rpc("app_setting_bool", { p_key: "ai_moderation_enabled", p_default: true });
        if (error) throw error;
        return data !== false;
      },
      async postingBlock(userId, imageCount) {
        const { data, error } = await supabase.rpc("posting_block", { p_user_id: userId, p_image_count: imageCount });
        if (error) throw error;
        return (data as PostingBlock | null) ?? null;
      },
      async createAd(ad) {
        const { data, error } = await supabase.rpc("create_ad_transaction", {
          p_user_id: ad.userId,
          p_temp_draft_id: ad.tempDraftId,
          p_category_id: ad.categoryId,
          p_title: ad.title,
          p_description: ad.description,
          p_ad_type: ad.adType,
          p_price: ad.price,
          p_price_type: ad.priceType,
          p_city_id: ad.cityId,
          p_district_id: ad.districtId,
          p_latitude: ad.latitude,
          p_longitude: ad.longitude,
          p_ai_risk_level: ad.aiRiskLevel,
          p_ai_review_notes: ad.aiNotes,
          p_ai_layer_used: ad.aiLayer,
          p_images: ad.images,
          p_fields: ad.fields,
        });
        if (error && (POSTING_BLOCKS as readonly string[]).includes(error.message)) {
          throw new PostingBlockedError(error.message as PostingBlock);
        }
        if (error) throw error;
        return data as string;
      },
      async logModeration(userId, tempDraftId, result, adId) {
        const { error } = await supabase.from("ai_moderation_log").insert({
          user_id: userId,
          ad_id: adId,
          temp_draft_id: tempDraftId,
          layer: result.layer,
          risk_level: result.riskLevel,
          notes: result.notes,
          model: result.model,
          error: result.error,
        });
        if (error) console.error("create-ad: moderation log insert failed:", error.code);
      },
    });
  } catch (error) {
    console.error("create-ad: unhandled error", error instanceof Error ? error.message : error);
    await reportError("create-ad", error);
    return new Response(JSON.stringify({ error: "حدث خطأ أثناء معالجة طلب نشر الإعلان." }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
