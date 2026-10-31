import { assert, assertEquals, assertNotEquals, assertThrows } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { DuplicateNationalIdError, handleSubmitKyc, NATIONAL_ID_REJECTED, SubmitKycDeps } from "./handler.ts";
import { hmacSecretFrom, nationalIdHmac, normalizeNationalId } from "./national_id.ts";

const SECRET = "test-secret-0123456789abcdef0123456789abcdef";
const ID = "29001011234567";
const IMAGE = btoa("not-really-a-jpeg");

type Row = Parameters<SubmitKycDeps["createVerification"]>[0];

function fakeDeps(opts: { inUse?: boolean; insertError?: Error; settings?: Record<string, boolean> } = {}) {
  const rows: Row[] = [];
  const uploaded: string[] = [];
  const removed: string[] = [];
  const deps: SubmitKycDeps = {
    authenticate: (token) => Promise.resolve(token === "user-token" ? "user-1" : null),
    setting: (key, fallback) => Promise.resolve(opts.settings?.[key] ?? fallback),
    hasPendingRequest: () => Promise.resolve(false),
    nationalIdHmac: (id) => nationalIdHmac(id, SECRET),
    nationalIdInUse: () => Promise.resolve(opts.inUse ?? false),
    uploadDocument: (path) => {
      uploaded.push(path);
      return Promise.resolve();
    },
    removeDocuments: (paths) => {
      removed.push(...paths);
      return Promise.resolve();
    },
    createVerification: (row) => {
      if (opts.insertError) return Promise.reject(opts.insertError);
      rows.push(row);
      return Promise.resolve();
    },
    updateFullName: () => Promise.resolve(),
    now: () => 1700000000000,
  };
  return { deps, rows, uploaded, removed };
}

const submit = (nationalId: string) =>
  new Request("https://x.test/submit-kyc-request", {
    method: "POST",
    headers: { Authorization: "Bearer user-token" },
    body: JSON.stringify({ full_name: "مستخدم", national_id: nationalId, front_image: IMAGE, back_image: IMAGE }),
  });

Deno.test("spaces and Arabic digits normalize to the same ID and the same HMAC", async () => {
  const variants = [ID, " 2900 1011 234567 ", "٢٩٠٠١٠١١٢٣٤٥٦٧", "۲۹۰۰۱۰۱۱۲۳۴۵۶۷", "٢٩٠٠ ١٠١١ ٢٣٤٥٦٧"];
  for (const v of variants) assertEquals(normalizeNationalId(v), ID, v);
  const hmacs = await Promise.all(variants.map((v) => nationalIdHmac(normalizeNationalId(v), SECRET)));
  assertEquals(new Set(hmacs).size, 1);
  assert(/^[0-9a-f]{64}$/.test(hmacs[0]));
});

Deno.test("the HMAC is keyed: another secret gives another value, and it is not a plain SHA-256", async () => {
  const withSecret = await nationalIdHmac(ID, SECRET);
  assertNotEquals(withSecret, await nationalIdHmac(ID, SECRET.replace("test", "prod")));
  const sha = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(ID)));
  assertNotEquals(withSecret, Array.from(sha, (b) => b.toString(16).padStart(2, "0")).join(""));
});

Deno.test("refuses to run without a strong secret", () => {
  assertThrows(() => hmacSecretFrom(undefined));
  assertThrows(() => hmacSecretFrom("short"));
  assertEquals(hmacSecretFrom(SECRET), SECRET);
});

Deno.test("stores the last 4 digits and the HMAC, never the full ID", async () => {
  const { deps, rows } = fakeDeps();
  const res = await handleSubmitKyc(submit("٢٩٠٠١٠١١٢٣٤٥٦٧"), deps);
  assertEquals(res.status, 200, await res.clone().text());
  assertEquals(rows.length, 1);
  assertEquals(rows[0].national_id_last4, "4567");
  assertEquals(rows[0].national_id_hmac, await nationalIdHmac(ID, SECRET));
  assert(!JSON.stringify(rows[0]).includes(ID), "the full ID is in no column");
});

Deno.test("an ID held by another account is refused with a generic message before anything is uploaded", async () => {
  const { deps, rows, uploaded } = fakeDeps({ inUse: true });
  const res = await handleSubmitKyc(submit(ID), deps);
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error, NATIONAL_ID_REJECTED);
  assertEquals([rows.length, uploaded.length], [0, 0]);
});

Deno.test("a concurrent duplicate caught by the unique index gets the same message, and its images are removed", async () => {
  const { deps, uploaded, removed } = fakeDeps({ insertError: new DuplicateNationalIdError() });
  const res = await handleSubmitKyc(submit(ID), deps);
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error, NATIONAL_ID_REJECTED);
  assertEquals(removed.sort(), uploaded.sort());
});

Deno.test("an invalid ID is rejected after normalization", async () => {
  const { deps, rows } = fakeDeps();
  const res = await handleSubmitKyc(submit("٢٩٠٠١٠١١٢٣٤٥"), deps);
  assertEquals(res.status, 400);
  assertEquals(rows.length, 0);
});

Deno.test("KYC requests stop when the switch is off or during maintenance, before any upload", async () => {
  for (const [settings, status, code] of [
    [{ enable_kyc_verification: false }, 403, "kyc_disabled"],
    [{ maintenance_mode: true }, 503, "maintenance"],
  ] as const) {
    const { deps, uploaded, rows } = fakeDeps({ settings });
    const res = await handleSubmitKyc(submit(ID), deps);
    assertEquals(res.status, status);
    assertEquals((await res.json()).code, code);
    assertEquals([uploaded.length, rows.length], [0, 0]);
  }
});
