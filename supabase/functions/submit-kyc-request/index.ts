import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Local Egyptian National ID validation
function validateNationalId(id: string): { isValid: boolean; error?: string } {
  if (!id) {
    return { isValid: false, error: "الرقم القومي مطلوب" };
  }
  
  const trimmed = id.trim();
  
  if (trimmed.length !== 14) {
    return { isValid: false, error: "يجب أن يتكون الرقم القومي من 14 رقماً" };
  }
  
  if (!/^\d+$/.test(trimmed)) {
    return { isValid: false, error: "يجب أن يحتوي الرقم القومي على أرقام فقط" };
  }
  
  const firstDigit = trimmed.charAt(0);
  if (firstDigit !== "2" && firstDigit !== "3") {
    return { isValid: false, error: "الرقم القومي غير صحيح (يجب أن يبدأ بـ 2 أو 3)" };
  }
  
  const yyStr = trimmed.substring(1, 3);
  const mmStr = trimmed.substring(3, 5);
  const ddStr = trimmed.substring(5, 7);
  
  const yy = parseInt(yyStr, 10);
  const mm = parseInt(mmStr, 10);
  const dd = parseInt(ddStr, 10);
  
  if (mm < 1 || mm > 12) {
    return { isValid: false, error: "صيغة التاريخ في الرقم القومي غير صحيحة (الشهر غير صالح)" };
  }
  
  if (dd < 1 || dd > 31) {
    return { isValid: false, error: "صيغة التاريخ في الرقم القومي غير صحيحة (اليوم غير صالح)" };
  }
  
  const birthYear = (firstDigit === "2" ? 1900 : 2000) + yy;
  const birthDate = new Date(birthYear, mm - 1, dd);
  
  if (
    birthDate.getFullYear() !== birthYear ||
    birthDate.getMonth() !== mm - 1 ||
    birthDate.getDate() !== dd
  ) {
    return { isValid: false, error: "تاريخ الميلاد في الرقم القومي غير صالح" };
  }
  
  if (birthDate.getTime() > Date.now()) {
    return { isValid: false, error: "تاريخ الميلاد في الرقم القومي لا يمكن أن يكون في المستقبل" };
  }
  
  return { isValid: true };
}

function base64ToBytes(base64: string): Uint8Array {
  const clean = base64.replace(/^data:image\/[a-z]+;base64,/, "");
  const binaryString = atob(clean);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

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

    // Authenticate user
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "غير مصرح بالدخول (توكن مفقود)" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const token = authHeader.substring(7);
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "جلسة العمل منتهية أو غير صالحة" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = user.id;

    // Parse body
    const { full_name, national_id, front_image, back_image } = await req.json();

    if (!full_name || !full_name.trim()) {
      return new Response(
        JSON.stringify({ error: "الاسم الكامل مطلوب" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Validate ID format
    const idValidation = validateNationalId(national_id);
    if (!idValidation.isValid) {
      return new Response(
        JSON.stringify({ error: idValidation.error }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!front_image || !back_image) {
      return new Response(
        JSON.stringify({ error: "صور بطاقة الرقم القومي مطلوبة (الوجه والخلفية)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check if there is an active pending request
    const { data: pendingRequests, error: checkError } = await supabase
      .from("user_verifications")
      .select("id")
      .eq("user_id", userId)
      .eq("status", "pending")
      .eq("type", "national_id");

    if (checkError) throw checkError;

    if (pendingRequests && pendingRequests.length > 0) {
      return new Response(
        JSON.stringify({ error: "لديك طلب تحقق قيد المراجعة بالفعل" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Decode and upload files
    const timestamp = Date.now();
    const frontPath = `${userId}/kyc/${timestamp}/front.jpg`;
    const backPath = `${userId}/kyc/${timestamp}/back.jpg`;

    let frontBytes: Uint8Array;
    let backBytes: Uint8Array;
    try {
      frontBytes = base64ToBytes(front_image);
      backBytes = base64ToBytes(back_image);
    } catch (decodeErr) {
      return new Response(
        JSON.stringify({ error: "فشل فك تشفير الصور. يرجى التأكد من إرسال صيغة base64 صالحة." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Upload front image
    const { error: frontUploadError } = await supabase.storage
      .from("id-documents")
      .upload(frontPath, frontBytes, { contentType: "image/jpeg", upsert: true });

    if (frontUploadError) {
      throw new Error(`فشل رفع الصورة الأمامية للبطاقة: ${frontUploadError.message}`);
    }

    // Upload back image
    const { error: backUploadError } = await supabase.storage
      .from("id-documents")
      .upload(backPath, backBytes, { contentType: "image/jpeg", upsert: true });

    if (backUploadError) {
      throw new Error(`فشل رفع الصورة الخلفية للبطاقة: ${backUploadError.message}`);
    }

    // Insert verification request
    const { error: insertError } = await supabase
      .from("user_verifications")
      .insert({
        user_id: userId,
        type: "national_id",
        document_url: frontPath,
        document_back_url: backPath,
        national_id: national_id.trim(),
        status: "pending",
        expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      });

    if (insertError) {
      throw new Error(`فشل إدراج طلب التحقق في قاعدة البيانات: ${insertError.message}`);
    }

    // Update full name in user profile
    const { error: userUpdateError } = await supabase
      .from("users")
      .update({ full_name: full_name.trim() })
      .eq("id", userId);

    if (userUpdateError) {
      throw new Error(`فشل تحديث الاسم في ملف المستخدم: ${userUpdateError.message}`);
    }

    return new Response(
      JSON.stringify({ success: true, message: "تم تقديم طلب التحقق بنجاح." }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("KYC submission error:", error);
    return new Response(
      JSON.stringify({ error: error.message ?? "حدث خطأ غير متوقع أثناء معالجة طلبك" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
