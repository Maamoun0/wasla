import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Supabase environment variables are not configured on the host.");
    }

    // Initialize Supabase client using service role key (bypasses RLS to write records on behalf of user)
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Parse Authorization Header to authenticate user
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

    // Parse Request Body
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

    // Validate required fields
    if (!temp_draft_id || !category_id || !title || !description || !city_id) {
      return new Response(
        JSON.stringify({ error: "البيانات الأساسية للإعلان غير مكتملة." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 1. Idempotency Check ──
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

    // ── 2. AI Content Review ──
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

    try {
      const reviewUrl = `${supabaseUrl}/functions/v1/ai-content-review`;
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 10000); // 10 seconds timeout

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
      } else {
        console.error("AI review function returned non-200 status:", reviewResponse.status);
      }
    } catch (err) {
      console.error("Error invoking AI review function or timeout reached:", err);
      // Under failure, fallback to 'medium' is already set above
    }

    // ── 3. Map Dynamic Field Names to DB Field IDs ──
    const { data: catFields, error: catFieldsErr } = await supabase
      .from("category_fields")
      .select("id, field_name, field_type")
      .eq("category_id", category_id);

    if (catFieldsErr) throw catFieldsErr;

    const fieldsToInsert = [];
    if (dynamic_fields && typeof dynamic_fields === "object") {
      for (const field of catFields) {
        const val = dynamic_fields[field.field_name];
        if (val === undefined || val === null) continue;

        let valText = null;
        let valNum = null;
        let valBool = null;
        let valJson = null;

        if (field.field_type === "text" || field.field_type === "select") {
          valText = String(val);
        } else if (field.field_type === "number") {
          valNum = Number(val);
        } else if (field.field_type === "boolean") {
          valBool = Boolean(val);
          valText = valBool ? "نعم" : "لا"; // Fallback text for backward compatibility
        } else if (field.field_type === "range") {
          valJson = val; // Expected to be Map/Object {min: x, max: y}
          if (val.min !== undefined && val.max !== undefined) {
            valText = `${val.min} - ${val.max}`; // Fallback text
          }
        } else if (field.field_type === "multi_select") {
          valJson = val; // Expected to be array of strings
          if (Array.isArray(val)) {
            valText = val.join(", "); // Fallback text
          }
        }

        fieldsToInsert.push({
          field_id: field.id,
          value_text: valText,
          value_number: valNum,
          value_boolean: valBool,
          value_json: valJson,
        });
      }
    }

    // ── 4. Call DB Transaction Function ──
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
      p_images: images ?? [],
      p_fields: fieldsToInsert,
    });

    if (txErr) throw txErr;

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
