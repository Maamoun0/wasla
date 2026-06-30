import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  const method = req.method;

  if (method === "OPTIONS") {
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

    if (method !== "POST") {
      return new Response(
        JSON.stringify({ error: "طريقة الطلب غير مدعومة" }),
        { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

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

    const { type, reference_id, amount, payment_method, metadata } = await req.json();

    if (!type || !amount || !payment_method) {
      return new Response(
        JSON.stringify({ error: "البيانات المرسلة غير مكتملة (type, amount, payment_method مطلوبة)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const validMethods = ["card", "fawry", "instapay", "vodafone_cash"];
    if (!validMethods.includes(payment_method)) {
      return new Response(
        JSON.stringify({ error: "طريقة الدفع المحددة غير مدعومة" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const validTypes = ["subscription", "ad_boost", "credit_purchase"];
    if (!validTypes.includes(type)) {
      return new Response(
        JSON.stringify({ error: "نوع المعاملة المحدد غير صالح" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (type === "ad_boost") {
      if (!reference_id) {
        return new Response(
          JSON.stringify({ error: "رقم تعريف الإعلان مطلوب للترقية" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: ad, error: adError } = await supabase
        .from("ads")
        .select("user_id, status")
        .eq("id", reference_id)
        .single();

      if (adError || !ad) {
        return new Response(
          JSON.stringify({ error: "الإعلان المحدد غير موجود" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (ad.user_id !== user.id) {
        return new Response(
          JSON.stringify({ error: "غير مصرح لك بترقية هذا الإعلان (أنت لا تملكه)" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (ad.status !== "active") {
        return new Response(
          JSON.stringify({ error: "لا يمكن ترقية إعلان غير نشط" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    if (type === "subscription") {
      if (!reference_id) {
        return new Response(
          JSON.stringify({ error: "رقم باقة الاشتراك مطلوبة للعملية" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: plan, error: planError } = await supabase
        .from("subscription_plans")
        .select("id, is_active")
        .eq("id", parseInt(reference_id))
        .single();

      if (planError || !plan) {
        return new Response(
          JSON.stringify({ error: "باقة الاشتراك المحددة غير موجودة" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (!plan.is_active) {
        return new Response(
          JSON.stringify({ error: "باقة الاشتراك المحددة غير مفعلة حالياً" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    const { data: transaction, error: insertError } = await supabase
      .from("transactions")
      .insert({
        user_id: user.id,
        type: type,
        reference_id: reference_id ?? null,
        reference_type: type === "ad_boost" ? "ad" : type === "subscription" ? "subscription_plan" : null,
        amount: parseFloat(amount),
        currency: "EGP",
        payment_method: payment_method,
        payment_gateway: "paymob",
        status: "pending",
        metadata: metadata ?? {},
      })
      .select("id")
      .single();

    if (insertError || !transaction) {
      throw new Error(`فشل إدراج المعاملة محلياً: ${insertError?.message}`);
    }

    const paymobApiKey = Deno.env.get("PAYMOB_API_KEY") ?? "";
    const paymobIntegrationId = parseInt(Deno.env.get("PAYMOB_INTEGRATION_ID") ?? "0");
    const paymobIframeId = parseInt(Deno.env.get("PAYMOB_IFRAME_ID") ?? "0");

    if (!paymobApiKey || !paymobIntegrationId || !paymobIframeId) {
      throw new Error("Paymob credentials are not configured in environment variables.");
    }

    const amountCents = Math.round(parseFloat(amount) * 100);

    const { data: userProfile } = await supabase
      .from("users")
      .select("full_name, email, phone")
      .eq("id", user.id)
      .single();

    const fullName = userProfile?.full_name?.trim() || "Wasla User";
    const nameParts = fullName.split(" ");
    const firstName = nameParts[0] || "Wasla";
    const lastName = nameParts.slice(1).join(" ") || "User";
    const userEmail = userProfile?.email || user.email || "test@wasla.eg";
    const userPhone = userProfile?.phone || user.phone || "+201000000000";

    let paymobToken = "";
    let paymobOrderId = "";
    let paymentKey = "";

    try {
      const authRes = await fetch("https://accept.paymob.com/api/auth/tokens", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ api_key: paymobApiKey }),
      });
      const authData = await authRes.json();
      paymobToken = authData.token;
      if (!paymobToken) throw new Error(authData.message || "Token is empty");
    } catch (err: any) {
      throw new Error(`[Step 1/4] فشل استدعاء مصادقة Paymob: ${err.message}`);
    }

    try {
      const orderRes = await fetch("https://accept.paymob.com/api/ecommerce/orders", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          auth_token: paymobToken,
          delivery_needed: "false",
          amount_cents: amountCents,
          currency: "EGP",
          items: [],
        }),
      });
      const orderData = await orderRes.json();
      paymobOrderId = orderData.id?.toString();
      if (!paymobOrderId) throw new Error("Order ID is empty");
    } catch (err: any) {
      throw new Error(`[Step 2/4] فشل تسجيل الطلب في Paymob: ${err.message}`);
    }

    try {
      const keyRes = await fetch("https://accept.paymob.com/api/acceptance/payment_keys", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          auth_token: paymobToken,
          amount_cents: amountCents,
          expiration: 3600,
          order_id: parseInt(paymobOrderId),
          billing_data: {
            apartment: "NA",
            floor: "NA",
            street: "NA",
            building: "NA",
            room_number: "NA",
            additional_info: "NA",
            city: "Cairo",
            state: "Cairo",
            country: "EGP",
            first_name: firstName,
            last_name: lastName,
            email: userEmail,
            phone_number: userPhone,
          },
          currency: "EGP",
          integration_id: paymobIntegrationId,
        }),
      });
      const keyData = await keyRes.json();
      paymentKey = keyData.token;
      if (!paymentKey) throw new Error(keyData.message || "Payment key token is empty");
    } catch (err: any) {
      throw new Error(`[Step 3/4] فشل إصدار مفتاح الدفع من Paymob: ${err.message}`);
    }

    const iframeUrl = `https://accept.paymob.com/api/acceptance/iframes/${paymobIframeId}?payment_token=${paymentKey}`;

    const { error: updateError } = await supabase
      .from("transactions")
      .update({
        gateway_transaction_id: paymobOrderId,
        metadata: {
          ...(metadata || {}),
          paymob_payment_key: paymentKey,
          paymob_order_id: paymobOrderId,
          billing: { firstName, lastName, userEmail, userPhone }
        }
      })
      .eq("id", transaction.id);

    if (updateError) {
      throw new Error(`فشل تحديث المعاملة بمعرفات Paymob: ${updateError.message}`);
    }

    // ── Sprint 8: User Activity Logging ──
    const ipAddress = req.headers.get("x-real-ip") ?? req.headers.get("x-forwarded-for") ?? "unknown";
    await supabase.from("user_activity_log").insert({
      user_id: user.id,
      action_type: "payment_attempted",
      ip_address: ipAddress,
      metadata: { transaction_id: transaction.id, amount, type }
    });

    return new Response(
      JSON.stringify({
        success: true,
        transaction_id: transaction.id,
        payment_url: iframeUrl,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Payment creation error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message ?? "حدث خطأ غير متوقع أثناء معالجة طلبك" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
