import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { handlePurge } from "./handler.ts";
import { supabaseDeps } from "./deps.ts";
import { reportError } from "../_shared/error_reporting.ts";

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("purge-deleted-accounts: required environment variables are missing");
    }
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    return await handlePurge(req, supabaseDeps(supabase, serviceRoleKey));
  } catch (error) {
    console.error("purge-deleted-accounts: unhandled error", error instanceof Error ? error.message : error);
    await reportError("purge-deleted-accounts", error);
    return new Response(JSON.stringify({ error: "internal error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
