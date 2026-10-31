import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { corsHeaders, handleCreatePayment } from "./handler.ts";
import { createPaymobPayment } from "./paymob.ts";

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const paymob = {
      apiKey: Deno.env.get("PAYMOB_API_KEY") ?? "",
      integrationId: parseInt(Deno.env.get("PAYMOB_INTEGRATION_ID") ?? "0"),
      iframeId: parseInt(Deno.env.get("PAYMOB_IFRAME_ID") ?? "0"),
    };
    if (!supabaseUrl || !supabaseServiceKey || !paymob.apiKey || !paymob.integrationId || !paymob.iframeId) {
      throw new Error("create-payment: required environment variables are missing");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    return await handleCreatePayment(req, {
      async authenticate(token) {
        const { data, error } = await supabase.auth.getUser(token);
        return error || !data.user ? null : data.user.id;
      },
      async setting(key, fallback) {
        const { data, error } = await supabase.rpc("app_setting_bool", { p_key: key, p_default: fallback });
        if (error) throw error;
        return data === true;
      },
      async getActivePackage(id) {
        const { data, error } = await supabase
          .from("payment_packages")
          .select("id, kind, price_egp, boost_type")
          .eq("id", id)
          .eq("is_active", true)
          .maybeSingle();
        if (error) throw error;
        return data;
      },
      async getAd(id) {
        const { data, error } = await supabase.from("ads").select("user_id, status").eq("id", id).maybeSingle();
        if (error) throw error;
        return data;
      },
      async hasActiveBoost(adId, boostType) {
        const { count, error } = await supabase
          .from("ad_boosts")
          .select("id", { count: "exact", head: true })
          .eq("ad_id", adId)
          .eq("boost_type", boostType)
          .gt("expires_at", new Date().toISOString());
        if (error) throw error;
        return (count ?? 0) > 0;
      },
      async getBillingProfile(userId) {
        const { data } = await supabase.from("users").select("full_name, email, phone").eq("id", userId).maybeSingle();
        return { fullName: data?.full_name ?? "", email: data?.email ?? null, phone: data?.phone ?? null };
      },
      async insertTransaction(tx) {
        const { data, error } = await supabase.from("transactions").insert(tx).select("id").single();
        if (error) throw error;
        return data.id;
      },
      createPaymobPayment: (args) => createPaymobPayment(paymob, args),
      async attachGatewayOrder(transactionId, orderId) {
        const { error } = await supabase
          .from("transactions")
          .update({ gateway_transaction_id: orderId })
          .eq("id", transactionId);
        if (error) throw error;
      },
      async markFailed(transactionId, reason) {
        await supabase
          .from("transactions")
          .update({ status: "failed", metadata: { failure_reason: reason } })
          .eq("id", transactionId)
          .eq("status", "pending");
      },
    });
  } catch (error) {
    console.error("create-payment: unhandled error", error instanceof Error ? error.message : error);
    return new Response(
      JSON.stringify({ error: "حدث خطأ غير متوقع أثناء معالجة طلبك" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
