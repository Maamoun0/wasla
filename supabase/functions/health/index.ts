import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { handleHealth } from "./handler.ts";
import { reportError } from "../_shared/error_reporting.ts";

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) throw new Error("health: required environment variables are missing");
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    return await handleHealth(req, {
      async check(name) {
        if (name === "database") {
          const { error } = await supabase.from("app_configs").select("key").limit(1);
          if (error) throw error;
        } else {
          const { error } = await supabase.storage.getBucket("ads");
          if (error) throw error;
        }
      },
      now: () => Date.now(),
      timeoutMs: 3000,
    });
  } catch (error) {
    console.error("health: unhandled error", error instanceof Error ? error.message : error);
    await reportError("health", error);
    return new Response(JSON.stringify({ status: "down" }), {
      status: 503,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }
});
