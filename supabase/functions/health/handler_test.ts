import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { CheckName, handleHealth, HealthDeps } from "./handler.ts";

function deps(failing: CheckName[] = [], hang: CheckName[] = []): HealthDeps {
  return {
    check: (name) => {
      if (hang.includes(name)) return new Promise(() => {});
      return failing.includes(name) ? Promise.reject(new Error(`secret detail ${name}`)) : Promise.resolve();
    },
    now: () => 0,
    timeoutMs: 20,
  };
}

const get = () => new Request("https://x.test/health");

Deno.test("200 when the database and Storage answer", async () => {
  const res = await handleHealth(get(), deps());
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Cache-Control"), "no-store");
  const body = await res.json();
  assertEquals([body.status, body.checks.database.ok, body.checks.storage.ok], ["ok", true, true]);
});

Deno.test("503 naming the failing check, without its error text", async () => {
  const res = await handleHealth(get(), deps(["database"]));
  assertEquals(res.status, 503);
  const text = await res.text();
  assertEquals(JSON.parse(text).checks.database.ok, false);
  assertEquals(text.includes("secret detail"), false);
});

Deno.test("a hanging dependency counts as down after the timeout", async () => {
  const res = await handleHealth(get(), deps([], ["storage"]));
  assertEquals(res.status, 503);
  assertEquals((await res.json()).checks.storage.ok, false);
});

Deno.test("only GET and HEAD", async () => {
  assertEquals((await handleHealth(new Request("https://x.test/health", { method: "POST" }), deps())).status, 405);
});
