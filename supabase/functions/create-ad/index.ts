import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { buildAdFields, FieldDefinition } from "./fields.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Supabase environment variables are not configured on the host.");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "رأس المصادقة (Authorization Header) مفقود." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(token);

    if (authErr || !user) {
      return new Response(
        JSON.stringify({ error: "غير مصرح: رمز الجلسة غير صالح أو منتهي الصلاحية." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const {
      temp_draft_id,
      category_id,
      title,
      description,
      ad_type,
      price,
      price_type,
      city_id,
      district_id,
      latitude,
      longitude,
      images,
      dynamic_fields,
    } = body;

    if (!temp_draft_id || !category_id || !title || !description || !city_id) {
      return new Response(
        JSON.stringify({ error: "البيانات الأساسية للإعلان غير مكتملة." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: existingAd, error: checkErr } = await supabase
      .from("ads")
      .select("id")
      .eq("temp_draft_id", temp_draft_id)
      .maybeSingle();

    if (checkErr) throw checkErr;
    if (existingAd) {
      return new Response(
        JSON.stringify({ success: true, ad_id: existingAd.id, message: "تم نشر الإعلان مسبقاً بنجاح." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let categoryName = "غير محدد";
    try {
      const { data: catData, error: catFetchErr } = await supabase
        .from("categories")
        .select("name_ar")
        .eq("id", category_id)
        .single();
      if (!catFetchErr && catData) {
        categoryName = catData.name_ar;
      }
    } catch (e) {
      console.warn("Could not fetch category name for review:", e);
    }

    let aiRiskLevel = "medium";
    let aiReviewNotes = "فشلت المراجعة التلقائية، تم تعيين مستوى الخطورة افتراضياً إلى متوسط.";
    let aiLayerUsed = 0;

    try {
      const reviewUrl = `${supabaseUrl}/functions/v1/ai-content-review`;
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 10000);

      const reviewResponse = await fetch(reviewUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`
        },
        body: JSON.stringify({
          title,
          description,
          price,
          category: categoryName
        }),
        signal: controller.signal
      });

      clearTimeout(timeoutId);

      if (reviewResponse.status === 200) {
        const reviewData = await reviewResponse.json();
        aiRiskLevel = reviewData.ai_risk_level ?? "medium";
        aiReviewNotes = reviewData.ai_review_notes ?? "مراجعة الذكاء الاصطناعي اكتملت.";
        aiLayerUsed = Number(reviewData.ai_layer_used ?? 0);
      } else {
        console.error("AI review function returned non-200 status:", reviewResponse.status);
      }
    } catch (err) {
      console.error("Error invoking AI review function or timeout reached:", err);
    }

    // Effective fields for the chosen subcategory: the parent's shared fields plus its own.
    const { data: catFields, error: catFieldsErr } = await supabase
      .rpc("get_category_fields", { p_category_id: category_id });

    if (catFieldsErr) throw catFieldsErr;

    const { rows: fieldsToInsert, missingRequired, invalid } = buildAdFields(
      (catFields ?? []) as FieldDefinition[],
      dynamic_fields,
    );
    if (missingRequired.length > 0 || invalid.length > 0) {
      return new Response(
        JSON.stringify({
          error: missingRequired.length > 0
            ? `حقول مطلوبة غير مكتملة: ${missingRequired.join("، ")}`
            : `قيم غير صالحة في: ${invalid.join("، ")}`,
          missing_fields: missingRequired,
          invalid_fields: invalid,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: adId, error: txErr } = await supabase.rpc("create_ad_transaction", {
      p_user_id: user.id,
      p_temp_draft_id: temp_draft_id,
      p_category_id: category_id,
      p_title: title,
      p_description: description,
      p_ad_type: ad_type ?? "offering",
      p_price: price,
      p_price_type: price_type ?? "fixed",
      p_city_id: city_id,
      p_district_id: district_id ?? null,
      p_latitude: latitude ?? null,
      p_longitude: longitude ?? null,
      p_ai_risk_level: aiRiskLevel,
      p_ai_review_notes: aiReviewNotes,
      p_ai_layer_used: aiLayerUsed,
      p_images: images ?? [],
      p_fields: fieldsToInsert,
    });

    if (txErr) throw txErr;

    // ── Sprint 8: User Activity Logging ──
    const ipAddress = req.headers.get("x-real-ip") ?? req.headers.get("x-forwarded-for") ?? "unknown";
    await supabase.from("user_activity_log").insert({
      user_id: user.id,
      action_type: "ad_published",
      ip_address: ipAddress,
      metadata: { ad_id: adId, title: title }
    });

    return new Response(
      JSON.stringify({ success: true, ad_id: adId, message: "تم نشر الإعلان بنجاح." }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message ?? "حدث خطأ أثناء معالجة طلب نشر الإعلان." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
