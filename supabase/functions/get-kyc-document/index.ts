import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

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

    // Check if the user is admin or moderator
    const { data: userData, error: dbUserError } = await supabase
      .from("users")
      .select("user_type")
      .eq("id", user.id)
      .single();

    if (dbUserError || !userData || (userData.user_type !== "admin" && userData.user_type !== "moderator")) {
      return new Response(
        JSON.stringify({ error: "غير مصرح لك بالوصول لمستندات الهوية (مشرفين فقط)" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse body for file path
    const { file_path } = await req.json();

    if (!file_path || !file_path.trim()) {
      return new Response(
        JSON.stringify({ error: "مسار الملف مطلوب" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Generate signed URL (expires in 5 minutes = 300 seconds)
    const { data: signedData, error: signedError } = await supabase.storage
      .from("id-documents")
      .createSignedUrl(file_path.trim(), 300);

    if (signedError || !signedData) {
      throw new Error(`فشل إنشاء الرابط المؤقت: ${signedError?.message ?? "خطأ مجهول"}`);
    }

    // Write to audit log
    const { error: logError } = await supabase
      .from("audit_log")
      .insert({
        action: "generate_signed_url",
        user_id: user.id,
        details: `طلب رابط مؤقت للمستند: ${file_path.trim()}`,
      });

    if (logError) {
      console.error("Failed to insert audit log:", logError);
      // We still return the URL to the administrator but warning is printed in log
    }

    return new Response(
      JSON.stringify({ signed_url: signedData.signedUrl }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Get KYC document error:", error);
    return new Response(
      JSON.stringify({ error: error.message ?? "حدث خطأ غير متوقع أثناء معالجة طلبك" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
