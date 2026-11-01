import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { reportError } from "./error_reporting.ts";

// Sends a real event to a local stand-in for Sentry and checks what arrived.
Deno.test({
  name: "with SENTRY_DSN an error is sent, tagged with the function, and scrubbed",
  sanitizeResources: false,
  sanitizeOps: false,
  fn: async () => {
    const bodies: string[] = [];
    const server = Deno.serve({ hostname: "127.0.0.1", port: 0, onListen: () => {} }, async (req) => {
      bodies.push(await req.text());
      return new Response("{}");
    });
    try {
      Deno.env.set("SENTRY_DSN", `http://publickey@127.0.0.1:${server.addr.port}/1`);
      await reportError("send-sms-hook", new Error("sms to +201012345678 for a@b.com failed, token=abc"));
      const sent = bodies.join("\n");
      assert(sent.includes('"function":"send-sms-hook"'), sent);
      assert(sent.includes("sms to [number] for [email] failed, token=[filtered]"), sent);
      assertEquals(/201012345678|a@b\.com|token=abc/.test(sent), false);
    } finally {
      Deno.env.delete("SENTRY_DSN");
      await server.shutdown();
    }
  },
});
