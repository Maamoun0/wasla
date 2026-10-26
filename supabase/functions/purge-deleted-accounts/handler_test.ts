import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { DueDeletion, handlePurge, PurgeDeps } from "./handler.ts";

const KEY = "service-role-test-key";

function fakeDeps(due: DueDeletion[], failOn: string | null = null) {
  const calls: string[] = [];
  let listed = 0;
  const deps: PurgeDeps = {
    serviceRoleKey: KEY,
    listDue: () => {
      listed++;
      return Promise.resolve(due);
    },
    removeUserFiles: (bucket, userId) => {
      calls.push(`files:${bucket}:${userId}`);
      return Promise.resolve(2);
    },
    deleteAuthUser: (userId) => {
      calls.push(`auth:${userId}`);
      return userId === failOn ? Promise.reject(new Error("auth down")) : Promise.resolve();
    },
    complete: (requestId) => {
      calls.push(`complete:${requestId}`);
      return Promise.resolve();
    },
  };
  return { deps, calls, listedCount: () => listed };
}

const authed = () => new Request("https://x.test/purge", { method: "POST", headers: { Authorization: `Bearer ${KEY}` } });

Deno.test("refuses callers without the service-role key", async () => {
  const { deps, listedCount } = fakeDeps([]);
  const res = await handlePurge(new Request("https://x.test/purge", { method: "POST", headers: { Authorization: "Bearer anon" } }), deps);
  assertEquals(res.status, 401);
  assertEquals(listedCount(), 0);
});

Deno.test("files first, then the auth user, then the request is closed", async () => {
  const { deps, calls } = fakeDeps([{ request_id: "r1", user_id: "u1" }]);
  const summary = await (await handlePurge(authed(), deps)).json();
  assertEquals(calls, ["files:ads:u1", "files:avatars:u1", "files:id-documents:u1", "auth:u1", "complete:r1"]);
  assertEquals(summary, { due: 1, purged: 1, failed: 0, files_removed: 6 });
});

Deno.test("a failure leaves that request open (retried next run) and does not stop the batch", async () => {
  const { deps, calls } = fakeDeps([{ request_id: "r1", user_id: "u1" }, { request_id: "r2", user_id: "u2" }], "u1");
  const summary = await (await handlePurge(authed(), deps)).json();
  assertEquals(calls.includes("complete:r1"), false);
  assertEquals(calls.includes("complete:r2"), true);
  assertEquals(summary.purged, 1);
  assertEquals(summary.failed, 1);
});
