import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  const method = req.method;

  // Handle CORS preflight requests
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

    // ── HTTP GET: Serve the Mock Payment HTML Page ──
    if (method === "GET") {
      const url = new URL(req.url);
      const txId = url.searchParams.get("tx_id") ?? "unknown";
      const amount = url.searchParams.get("amount") ?? "0.00";

      const html = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <title>بوابة دفع وصلة التجريبية | Paymob Sandbox</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background-color: #F9F7F3;
      color: #1F2937;
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
    }
    .container {
      background: white;
      padding: 30px;
      border-radius: 12px;
      box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1), 0 2px 4px -1px rgba(0,0,0,0.06);
      width: 100%;
      max-width: 450px;
      box-sizing: border-box;
      text-align: center;
    }
    .logo {
      color: #0D7A84;
      font-size: 28px;
      font-weight: bold;
      margin-bottom: 20px;
    }
    .amount-box {
      background: #F3F4F6;
      padding: 15px;
      border-radius: 8px;
      font-size: 18px;
      margin-bottom: 25px;
    }
    .amount-val {
      font-weight: bold;
      color: #0D7A84;
    }
    .card-fields {
      text-align: right;
      margin-bottom: 25px;
    }
    .form-group {
      margin-bottom: 15px;
    }
    label {
      display: block;
      font-size: 14px;
      margin-bottom: 5px;
      color: #4B5563;
    }
    input {
      width: 100%;
      padding: 10px;
      border: 1px solid #D1D5DB;
      border-radius: 6px;
      font-size: 16px;
      box-sizing: border-box;
    }
    .flex-inputs {
      display: flex;
      gap: 15px;
    }
    .flex-inputs .form-group {
      flex: 1;
    }
    .btn {
      display: block;
      width: 100%;
      background: #E89510;
      color: white;
      border: none;
      padding: 14px;
      font-size: 16px;
      font-weight: bold;
      border-radius: 6px;
      cursor: pointer;
      margin-bottom: 10px;
      transition: background 0.2s;
    }
    .btn:hover {
      background: #D1840E;
    }
    .btn-cancel {
      background: #E5E7EB;
      color: #374151;
    }
    .btn-cancel:hover {
      background: #D1D5DB;
    }
    .btn-fail {
      background: #EF4444;
      color: white;
    }
    .btn-fail:hover {
      background: #DC2626;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">وصلة Wasla</div>
    <h3>بوابة الدفع الآمنة (Paymob Sandbox)</h3>
    <div class="amount-box">
      مبلغ الدفع المطلوب: <span class="amount-val"><span id="amount-text">${amount}</span> ج.م</span>
    </div>
    
    <div class="card-fields">
      <div class="form-group">
        <label>رقم البطاقة الائتمانية</label>
        <input type="text" value="4000 1234 5678 9010" disabled>
      </div>
      <div class="flex-inputs">
        <div class="form-group">
          <label>تاريخ الانتهاء</label>
          <input type="text" value="12 / 29" disabled>
        </div>
        <div class="form-group">
          <label>الرمز السري (CVV)</label>
          <input type="text" value="123" disabled>
        </div>
      </div>
    </div>
    
    <button class="btn" onclick="triggerSuccess()">تأكيد الدفع (تفعيل نجاح المعاملة)</button>
    <button class="btn btn-fail" onclick="triggerFail()">محاكاة فشل الدفع</button>
    <button class="btn btn-cancel" onclick="triggerCancel()">إلغاء المعاملة والعودة</button>
  </div>

  <script>
    function triggerSuccess() {
      window.location.href = 'https://wasla.eg/payment/callback?success=true&id=${txId}';
    }
    function triggerFail() {
      window.location.href = 'https://wasla.eg/payment/callback?success=false&id=${txId}';
    }
    function triggerCancel() {
      window.location.href = 'https://wasla.eg/payment/cancel?id=${txId}';
    }
  </script>
</body>
</html>`;

      return new Response(html, {
        headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
      });
    }

    // ── HTTP POST: Generate Transaction & Return Payment URL ──
    if (method === "POST") {
      const authHeader = req.headers.get("Authorization") ?? "";
      if (!authHeader.startsWith("Bearer ")) {
        return new Response(
          JSON.stringify({ error: "غير مصرح بالدخول (رمز مصادقة مفقود)" }),
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

      // Read request body
      const { type, reference_id, amount, payment_method } = await req.json();

      if (!type || !amount || !payment_method) {
        return new Response(
          JSON.stringify({ error: "البيانات المرسلة غير مكتملة (type, amount, payment_method مطلوبة)" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Validate payment method
      const validMethods = ["card", "fawry", "instapay", "vodafone_cash"];
      if (!validMethods.includes(payment_method)) {
        return new Response(
          JSON.stringify({ error: "طريقة الدفع المحددة غير مدعومة" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Validate transaction type
      const validTypes = ["subscription", "ad_boost", "credit_purchase"];
      if (!validTypes.includes(type)) {
        return new Response(
          JSON.stringify({ error: "نوع المعاملة المحدد غير صالح" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Insert transaction into public.transactions (initially status = 'pending')
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
        })
        .select("id")
        .single();

      if (insertError) {
        throw new Error(`فشل إدراج المعاملة في قاعدة البيانات: ${insertError.message}`);
      }

      // Construct Sandbox payment redirect URL (points back to this function's GET method)
      const functionUrl = `${new URL(req.url).origin}/create-payment`;
      const paymentUrl = `${functionUrl}?tx_id=${transaction.id}&amount=${amount}`;

      return new Response(
        JSON.stringify({
          success: true,
          transaction_id: transaction.id,
          payment_url: paymentUrl,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "طريقة الطلب غير مدعومة" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Payment creation stub error:", error);
    return new Response(
      JSON.stringify({ error: error.message ?? "حدث خطأ غير متوقع أثناء معالجة الطلب" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
