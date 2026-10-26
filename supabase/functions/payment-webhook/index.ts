import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { corsHeaders, FulfilResult, handleWebhook } from "./handler.ts";

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const hmacSecret = Deno.env.get("PAYMOB_HMAC_SECRET") ?? "";
    if (!supabaseUrl || !supabaseServiceKey || !hmacSecret) {
      throw new Error("payment-webhook: required environment variables are missing");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    return await handleWebhook(req, {
      hmacSecret,
      async findTransactionByOrderId(orderId) {
        const { data, error } = await supabase
          .from("transactions")
          .select("id, user_id")
          .eq("payment_gateway", "paymob")
          .eq("gateway_transaction_id", orderId)
          .maybeSingle();
        if (error) throw error;
        return data;
      },
      async fulfil({ transactionId, success, amountCents, currency, gatewayData }) {
        const { data, error } = await supabase.rpc("fulfill_payment", {
          p_transaction_id: transactionId,
          p_success: success,
          p_amount_cents: amountCents,
          p_currency: currency,
          p_gateway_data: gatewayData,
        });
        if (error) throw error;
        return data as FulfilResult;
      },
      async onCompleted(tx, ipAddress) {
        await supabase.from("user_activity_log").insert({
          user_id: tx.user_id,
          action_type: "payment_completed",
          ip_address: ipAddress,
          metadata: { transaction_id: tx.id },
        });
      },
    });
  } catch (error) {
    console.error("payment-webhook: unhandled error", error instanceof Error ? error.message : error);
    return new Response(
      JSON.stringify({ error: "حدث خطأ داخلي أثناء معالجة الطلب" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
