import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Web Crypto HMAC SHA-512 Generator
async function computeHmacSha512(secret: string, data: string): Promise<string> {
  const encoder = new TextEncoder();
  const keyBuf = encoder.encode(secret);
  const dataBuf = encoder.encode(data);

  const key = await crypto.subtle.importKey(
    "raw",
    keyBuf,
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign("HMAC", key, dataBuf);
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req) => {
  const method = req.method;

  if (method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const paymobHmacSecret = Deno.env.get("PAYMOB_HMAC_SECRET") ?? "";

    if (!supabaseUrl || !supabaseServiceKey || !paymobHmacSecret) {
      throw new Error("Required environment variables are not configured on the host.");
    }

    // Initialize Supabase Client with service_role to securely perform activations bypassing RLS
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    if (method !== "POST") {
      return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
    }

    // Parse the Webhook request body
    const body = await req.json();
    const transaction = body.obj;

    if (!transaction) {
      return new Response(
        JSON.stringify({ error: "محتوى الطلب غير صالح" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 1. Secure HMAC Signature Verification ──
    const url = new URL(req.url);
    const receivedHmac = url.searchParams.get("hmac") ?? "";

    if (!receivedHmac) {
      return new Response(
        JSON.stringify({ error: "توقيع HMAC مفقود" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Retrieve fields in the strict lexicographical order required by Paymob Egypt
    const values = [
      transaction.amount_cents,
      transaction.created_at,
      transaction.currency,
      transaction.error_occured,
      transaction.has_parent_transaction,
      transaction.id,
      transaction.integration_id,
      transaction.is_3d_secure,
      transaction.is_auth,
      transaction.is_capture,
      transaction.is_refunded,
      transaction.is_standalone_payment,
      transaction.is_voided,
      transaction.order?.id ?? transaction.order,
      transaction.owner,
      transaction.pending,
      transaction.source_data?.pan ?? "",
      transaction.source_data?.sub_type ?? "",
      transaction.source_data?.type ?? "",
      transaction.success,
    ];

    const concatenatedString = values.map((val) => String(val)).join("");
    const calculatedHmac = await computeHmacSha512(paymobHmacSecret, concatenatedString);

    if (calculatedHmac !== receivedHmac) {
      console.warn("HMAC verification failed. Possible fraud attempt.");
      return new Response(
        JSON.stringify({ error: "توقيع HMAC غير صحيح" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 2. Idempotency Check & Transaction lookup ──
    const paymobOrderId = (transaction.order?.id ?? transaction.order)?.toString();
    
    const { data: dbTx, error: selectError } = await supabase
      .from("transactions")
      .select("*")
      .eq("gateway_transaction_id", paymobOrderId)
      .maybeSingle();

    if (selectError) {
      throw new Error(`فشل الاستعلام عن المعاملة: ${selectError.message}`);
    }

    if (!dbTx) {
      console.warn(`Transaction not found for Paymob Order ID: ${paymobOrderId}`);
      return new Response(
        JSON.stringify({ error: "المعاملة غير مسجلة بالنظام" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // If transaction is already resolved (completed or failed), exit immediately
    if (dbTx.status === "completed" || dbTx.status === "failed") {
      console.info(`Transaction ${dbTx.id} already processed. Idempotency triggered.`);
      return new Response(
        JSON.stringify({ success: true, message: "تمت معالجة المعاملة مسبقاً" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 3. Update Transaction Record status ──
    const isSuccess = transaction.success === true && transaction.pending === false;
    const finalStatus = isSuccess ? "completed" : "failed";

    const { error: updateError } = await supabase
      .from("transactions")
      .update({
        status: finalStatus,
        completed_at: new Date().toISOString(),
        metadata: {
          ...(dbTx.metadata || {}),
          paymob_callback_payload: transaction,
        },
      })
      .eq("id", dbTx.id);

    if (updateError) {
      throw new Error(`فشل تحديث حالة المعاملة: ${updateError.message}`);
    }

    // If payment failed, stop here
    if (!isSuccess) {
      console.info(`Transaction ${dbTx.id} resolved as failed.`);
      return new Response(
        JSON.stringify({ success: true, message: "تم تسجيل فشل المعاملة بنجاح" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 4. Secure Activation Logic (Service Role) ──
    if (dbTx.type === "ad_boost") {
      const boostType = dbTx.metadata?.boost_type || "featured";
      const durationDays = parseInt(dbTx.metadata?.duration_days?.toString() || "7");
      
      const startedAt = new Date();
      const expiresAt = new Date(startedAt.getTime() + durationDays * 24 * 60 * 60 * 1000);

      // Insert boost record
      const { error: boostError } = await supabase
        .from("ad_boosts")
        .insert({
          ad_id: dbTx.reference_id,
          user_id: dbTx.user_id,
          boost_type: boostType,
          started_at: startedAt.toISOString(),
          expires_at: expiresAt.toISOString(),
        });

      if (boostError) {
        throw new Error(`فشل إدراج سجل ترويج الإعلان: ${boostError.message}`);
      }

      // Update flags in ads table
      const updateFlags: Record<string, any> = {};
      if (boostType === "featured") {
        updateFlags["is_featured"] = true;
      } else if (boostType === "urgent") {
        updateFlags["is_urgent"] = true;
      } else if (boostType === "bump") {
        updateFlags["refreshed_at"] = startedAt.toISOString();
      }

      const { error: adUpdateError } = await supabase
        .from("ads")
        .update(updateFlags)
        .eq("id", dbTx.reference_id);

      if (adUpdateError) {
        throw new Error(`فشل تحديث علامات الترويج للإعلان: ${adUpdateError.message}`);
      }

      console.info(`Successfully activated boost type ${boostType} for Ad: ${dbTx.reference_id}`);
    }

    if (dbTx.type === "subscription") {
      const planId = parseInt(dbTx.reference_id);
      const startedAt = new Date();
      const expiresAt = new Date(startedAt.getTime() + 30 * 24 * 60 * 60 * 1000); // 30 Days expiration

      // Expire or cancel any previous active subscriptions for the user
      const { error: expireError } = await supabase
        .from("user_subscriptions")
        .update({ status: "cancelled" })
        .eq("user_id", dbTx.user_id)
        .eq("status", "active");

      if (expireError) {
        console.warn(`Warning: Could not cancel previous subscriptions: ${expireError.message}`);
      }

      // Insert new active user subscription
      const { error: subError } = await supabase
        .from("user_subscriptions")
        .insert({
          user_id: dbTx.user_id,
          plan_id: planId,
          status: "active",
          started_at: startedAt.toISOString(),
          expires_at: expiresAt.toISOString(),
          auto_renew: false,
        });

      if (subError) {
        throw new Error(`فشل تفعيل باقة الاشتراك للمستخدم: ${subError.message}`);
      }

      console.info(`Successfully activated subscription plan ${planId} for User: ${dbTx.user_id}`);
    }

    return new Response(
      JSON.stringify({ success: true, message: "تم تفعيل المعاملة والترقية بنجاح" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Webhook processing error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message ?? "حدث خطأ داخلي أثناء معالجة الطلب" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
