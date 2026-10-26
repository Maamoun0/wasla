import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { handleDispatch } from "./handler.ts";
import { supabaseDeps } from "./deps.ts";
import { FcmClient, ServiceAccount } from "./fcm.ts";

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
    if (!supabaseUrl || !serviceRoleKey || !serviceAccountJson) {
      throw new Error("dispatch-notifications: required environment variables are missing");
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const fcm = new FcmClient(JSON.parse(serviceAccountJson) as ServiceAccount);

    return await handleDispatch(
      req,
      supabaseDeps(supabase, serviceRoleKey, (token, n) => fcm.send(token, n.title, n.body, n.data ?? {})),
    );
  } catch (error) {
    console.error("dispatch-notifications: unhandled error", error instanceof Error ? error.message : error);
    return new Response(JSON.stringify({ error: "internal error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
