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

    // Initialize Supabase client with service_role bypass RLS to check/insert throttling logs
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Parse request body
    const { phone_number } = await req.json();
    if (!phone_number) {
      return new Response(
        JSON.stringify({ error: "رقم الهاتف مطلوب" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Standardize phone number formatting (e.g. ensure +20 prefix for Egyptian numbers)
    let formattedPhone = phone_number.trim();
    if (formattedPhone.startsWith("01") && formattedPhone.length === 11) {
      formattedPhone = "+20" + formattedPhone.substring(1);
    } else if (formattedPhone.startsWith("201") && formattedPhone.length === 12) {
      formattedPhone = "+" + formattedPhone;
    }

    const ipAddress = req.headers.get("x-real-ip") ?? req.headers.get("x-forwarded-for") ?? "unknown";

    // ── Throttling Rule A: Short Limiter (1 request per 3 minutes) ──
    const threeMinutesAgo = new Date(Date.now() - 3 * 60 * 1000).toISOString();
    const { data: recentRequests, error: errShort } = await supabase
      .from("otp_requests")
      .select("id")
      .eq("phone_number", formattedPhone)
      .gt("requested_at", threeMinutesAgo);

    if (errShort) throw errShort;

    if (recentRequests && recentRequests.length >= 1) {
      return new Response(
        JSON.stringify({
          code: "RATE_LIMIT_SHORT",
          message: "يرجى الانتظار 3 دقائق قبل طلب رمز تحقق جديد.",
        }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Throttling Rule B: Daily Limiter (10 requests per 24 hours) ──
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { data: dailyRequests, error: errDaily } = await supabase
      .from("otp_requests")
      .select("id")
      .eq("phone_number", formattedPhone)
      .gt("requested_at", twentyFourHoursAgo);

    if (errDaily) throw errDaily;

    if (dailyRequests && dailyRequests.length >= 10) {
      return new Response(
        JSON.stringify({
          code: "RATE_LIMIT_DAILY",
          message: "لقد تجاوزت الحد الأقصى لطلبات التحقق اليومية (10 طلبات). يرجى المحاولة غداً.",
        }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Log the Request ──
    const { error: errLog } = await supabase
      .from("otp_requests")
      .insert({
        phone_number: formattedPhone,
        ip_address: ipAddress,
      });

    if (errLog) throw errLog;

    // ── Trigger Supabase OTP auth challenge ──
    const { error: errOtp } = await supabase.auth.signInWithOtp({
      phone: formattedPhone,
    });

    if (errOtp) {
      return new Response(
        JSON.stringify({ error: `فشل إرسال الرمز: ${errOtp.message}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, message: "تم إرسال رمز التحقق بنجاح." }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message ?? "حدث خطأ غير متوقع" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
