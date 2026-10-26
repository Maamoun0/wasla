import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { corsHeaders, handleSubmitKyc } from "./handler.ts";
import { supabaseDeps } from "./deps.ts";

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("submit-kyc-request: required environment variables are missing");
    }
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    return await handleSubmitKyc(req, supabaseDeps(supabase));
  } catch (error) {
    // Log without request data: it carries identity documents.
    console.error("submit-kyc-request: unhandled error", error instanceof Error ? error.message : error);
    return new Response(JSON.stringify({ error: "حدث خطأ غير متوقع أثناء معالجة طلبك" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
