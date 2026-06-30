import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { ad_id } = await req.json();
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 1. Fetch Ad Details
    const { data: ad } = await supabase
      .from("ads")
      .select("id, title, category_id, city_id, price")
      .eq("id", ad_id)
      .single();

    if (!ad) throw new Error("Ad not found");

    // 2. Find Matching Watchlists (Saved Searches)
    // Matches category, city, and price range
    const { data: matches } = await supabase
      .from("saved_searches")
      .select(`
        id, 
        user_id,
        users!inner(notification_preferences)
      `)
      .eq("category_id", ad.category_id)
      .eq("is_active", true)
      .or(`city_id.is.null,city_id.eq.${ad.city_id}`)
      // Filter by price if search has constraints
      .or(`min_price.is.null,min_price.lte.${ad.price}`)
      .or(`max_price.is.null,max_price.gte.${ad.price}`);

    if (!matches || matches.length === 0) {
      return new Response(JSON.stringify({ message: "No matches found" }), { status: 200 });
    }

    // 3. Filter by User Preferences & Deduplicate (Piece 2.3)
    for (const match of matches) {
      const prefs = match.users?.notification_preferences;
      if (prefs?.watchlist_matches === false) continue;

      // Check if already notified for this ad (Piece 2.3)
      const { data: alreadySent } = await supabase
        .from("watchlist_notifications")
        .select("id")
        .eq("user_id", match.user_id)
        .eq("ad_id", ad.id)
        .maybeSingle();

      if (alreadySent) continue;

      // 4. Get User Push Tokens (Piece 2.2 - Multiple devices)
      const { data: tokens } = await supabase
        .from("push_tokens")
        .select("token")
        .eq("user_id", match.user_id)
        .eq("is_active", true);

    if (tokens && tokens.length > 0) {
      console.log(`Sending Watchlist Notification to User ${match.user_id} for Ad ${ad.id}`);
      
      // Record as sent
      await supabase.from("watchlist_notifications").insert({
        user_id: match.user_id,
        ad_id: ad.id
      });

      // Piece 5.2 - Including type/id in data for routing
      // Note: This assumes an FCM integration or provider is configured.
      // For now we log the payload we would send.
      console.log("FCM Payload:", {
        title: "إعلان جديد يهمك! 🔔",
        body: `لقينا إعلان "${ad.title}" يطابق بحثك المحفوظ.`,
        data: { type: "watchlist_match", ad_id: ad.id }
      });
    }
    }

    return new Response(JSON.stringify({ success: true }), { 
      headers: { ...corsHeaders, "Content-Type": "application/json" } 
    });

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
