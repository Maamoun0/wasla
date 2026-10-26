import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { ClaimedNotification, DispatchDeps, handleDispatch } from "./handler.ts";

const KEY = "service-role-test-key";

function notification(id: string, tokens: string[]): ClaimedNotification {
  return { id, user_id: `user-${id}`, title: "t", body: "b", data: { type: "ad_status_change", ad_id: "ad-1" }, attempts: 1, tokens };
}

function fakeDeps(batch: ClaimedNotification[], behaviour: Record<string, "sent" | "invalid_token" | "error" | "throw">) {
  const completed: { id: string; status: string; error: string | null; invalid: string[] }[] = [];
  let claims = 0;
  const deps: DispatchDeps = {
    serviceRoleKey: KEY,
    claim: () => {
      claims++;
      return Promise.resolve(batch);
    },
    send: (token) => {
      const b = behaviour[token];
      if (b === "throw") return Promise.reject(new Error("network down"));
      if (b === "error") return Promise.resolve({ kind: "error", message: "FCM 503 UNAVAILABLE" });
      return Promise.resolve({ kind: b });
    },
    complete: (id, status, error, invalid) => {
      completed.push({ id, status, error, invalid });
      return Promise.resolve();
    },
  };
  return { deps, completed, claimCount: () => claims };
}

const authed = () => new Request("https://x.test/dispatch", { method: "POST", headers: { Authorization: `Bearer ${KEY}` } });

Deno.test("refuses callers without the service-role key and claims nothing", async () => {
  const { deps, claimCount } = fakeDeps([], {});
  const anon = new Request("https://x.test/dispatch", { method: "POST", headers: { Authorization: "Bearer anon-key" } });
  assertEquals((await handleDispatch(anon, deps)).status, 401);
  assertEquals((await handleDispatch(new Request("https://x.test/dispatch", { method: "POST" }), deps)).status, 401);
  assertEquals(claimCount(), 0);
});

Deno.test("delivered to at least one device: sent; dead tokens reported", async () => {
  const { deps, completed } = fakeDeps([notification("n1", ["good", "dead"])], { good: "sent", dead: "invalid_token" });
  const res = await handleDispatch(authed(), deps);
  assertEquals((await res.json()).sent, 1);
  assertEquals(completed, [{ id: "n1", status: "sent", error: null, invalid: ["dead"] }]);
});

Deno.test("no tokens: skipped", async () => {
  const { deps, completed } = fakeDeps([notification("n2", [])], {});
  await handleDispatch(authed(), deps);
  assertEquals(completed[0].status, "skipped");
});

Deno.test("every token unregistered: skipped and all tokens reported", async () => {
  const { deps, completed } = fakeDeps([notification("n3", ["a", "b"])], { a: "invalid_token", b: "invalid_token" });
  await handleDispatch(authed(), deps);
  assertEquals(completed[0], { id: "n3", status: "skipped", error: "all device tokens are unregistered", invalid: ["a", "b"] });
});

Deno.test("transient FCM error: failed (the database schedules the retry)", async () => {
  const { deps, completed } = fakeDeps([notification("n4", ["a"])], { a: "error" });
  await handleDispatch(authed(), deps);
  assertEquals(completed[0], { id: "n4", status: "failed", error: "FCM 503 UNAVAILABLE", invalid: [] });
});

Deno.test("an exception on one row does not stop the batch", async () => {
  const { deps, completed } = fakeDeps(
    [notification("n5", ["boom"]), notification("n6", ["ok"])],
    { boom: "throw", ok: "sent" },
  );
  const summary = await (await handleDispatch(authed(), deps)).json();
  assertEquals(summary, { claimed: 2, sent: 1, skipped: 0, failed: 1 });
  assertEquals(completed.map((c) => [c.id, c.status]), [["n5", "failed"], ["n6", "sent"]]);
});
