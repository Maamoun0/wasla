import { depsFromEnv } from "./deps.ts";
import { handleSendSmsHook } from "./handler.ts";

Deno.serve(async (req) => {
  try {
    return await handleSendSmsHook(req, depsFromEnv((k) => Deno.env.get(k)));
  } catch (err) {
    // Missing hook secret or an unexpected error: refuse, without request data.
    console.error("send-sms-hook: unhandled error", err instanceof Error ? err.message : err);
    return new Response(JSON.stringify({ error: { http_code: 500, message: "SMS hook is not available" } }), {
      // 200 so Auth relays the error body (see handler.ts).
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }
});
