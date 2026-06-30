import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { ad_id, new_status, rejection_reason } = await req.json();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 1. Fetch Ad & Owner Details
    const { data: ad } = await supabase
      .from("ads")
      .select("id, title, user_id, users(notification_preferences)")
      .eq("id", ad_id)
      .single();

    if (!ad) throw new Error("Ad not found");

    const prefs = ad.users?.notification_preferences;
    if (prefs?.ad_status_updates === false) {
      return new Response(JSON.stringify({ message: "User disabled status notifications" }));
    }

    // 2. Compose Message (Piece 3.2 - Brand Voice)
    let title = "";
    let body = "";

    if (new_status === "active") {
      title = "تم قبول إعلانك 🎉";
      body = `✅ إعلانك "${ad.title}" اتنشر وبقى مرئي للجميع!`;
    } else if (new_status === "rejected") {
      title = "تحديث بخصوص إعلانك";
      body = `❌ إعلانك "${ad.title}" اترفض. السبب: ${rejection_reason || "مخالف لشروط النشر"}`;
    }

    // 3. Get User Tokens
    const { data: tokens } = await supabase
      .from("push_tokens")
      .select("token")
      .eq("user_id", ad.user_id)
      .eq("is_active", true);

    if (tokens && tokens.length > 0) {
      console.log(`Sending Ad Status Notification to Owner ${ad.user_id} - New Status: ${new_status}`);
      // Piece 5.2 - Including type/id in data for routing
      console.log("FCM Payload:", {
        title: title,
        body: body,
        data: { type: "ad_status_change", ad_id: ad.id }
      });
    }

    return new Response(JSON.stringify({ success: true }), { 
      headers: { ...corsHeaders, "Content-Type": "application/json" } 
    });

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
