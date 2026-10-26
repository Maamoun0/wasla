import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { CreateAdDeps, handleCreateAd, NewAd } from "./handler.ts";
import type { ModerationResult } from "./moderation.ts";

const USER = "11111111-1111-1111-1111-111111111111";
const BODY = {
  temp_draft_id: "draft-1", category_id: 30, title: "سباك محترف", description: "خبرة 10 سنوات في السباكة",
  city_id: 1, price: 200, dynamic_fields: { service_location: "في منزل العميل" }, images: [],
};
const LOW: ModerationResult = { riskLevel: "low", notes: "سليم", layer: 2, model: "fast", error: null };

function fakeDeps(over: Partial<CreateAdDeps> = {}) {
  const created: NewAd[] = [];
  const logs: { moderation: ModerationResult; adId: string | null }[] = [];
  let moderated = 0;
  const deps: CreateAdDeps = {
    allowedImageOrigins: ["https://abc.supabase.co"],
    authenticate: (t) => Promise.resolve(t === "good" ? USER : null),
    findAdByDraft: () => Promise.resolve(null),
    getCategoryName: () => Promise.resolve("سباكة"),
    getCategoryFields: () => Promise.resolve([
      { id: 1, field_name: "service_location", label_ar: "مكان", field_type: "select", is_required: true, options: ["في منزل العميل"] },
    ]),
    moderationAllowed: () => Promise.resolve(true),
    moderate: () => {
      moderated++;
      return Promise.resolve(LOW);
    },
    createAd: (ad) => {
      created.push(ad);
      return Promise.resolve("ad-1");
    },
    logModeration: (_userId, _draft, moderation, adId) => {
      logs.push({ moderation, adId });
      return Promise.resolve();
    },
    ...over,
  };
  return { deps, created, logs, moderatedCount: () => moderated };
}

const post = (body: unknown, token: string | null = "good") =>
  new Request("https://x.test/create-ad", {
    method: "POST",
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });

Deno.test("no token or a bad token: 401 and moderation never runs", async () => {
  const { deps, moderatedCount, created } = fakeDeps();
  assertEquals((await handleCreateAd(post(BODY, null), deps)).status, 401);
  assertEquals((await handleCreateAd(post(BODY, "anon-key"), deps)).status, 401);
  assertEquals(moderatedCount(), 0);
  assertEquals(created.length, 0);
});

Deno.test("the ad is created with the moderation result and the decision is logged", async () => {
  const { deps, created, logs } = fakeDeps();
  const res = await handleCreateAd(post(BODY), deps);
  assertEquals(res.status, 200);
  assertEquals([created[0].aiRiskLevel, created[0].aiLayer, created[0].aiNotes], ["low", 2, "سليم"]);
  assertEquals(logs, [{ moderation: LOW, adId: "ad-1" }]);
});

Deno.test("over the daily AI limit: no API call, ad goes to manual review", async () => {
  const { deps, created, moderatedCount, logs } = fakeDeps({ moderationAllowed: () => Promise.resolve(false) });
  assertEquals((await handleCreateAd(post(BODY), deps)).status, 200);
  assertEquals(moderatedCount(), 0);
  assertEquals([created[0].aiRiskLevel, created[0].aiLayer], ["unreviewed", 0]);
  assertEquals(logs[0].moderation.error, "daily_ai_limit");
});

Deno.test("moderation crashing still creates the ad for manual review", async () => {
  const { deps, created } = fakeDeps({ moderate: () => Promise.reject(new Error("boom")) });
  assertEquals((await handleCreateAd(post(BODY), deps)).status, 200);
  assertEquals(created[0].aiRiskLevel, "unreviewed");
});

Deno.test("a repeated draft returns the existing ad without moderating again", async () => {
  const { deps, moderatedCount, created } = fakeDeps({ findAdByDraft: () => Promise.resolve("ad-0") });
  const res = await handleCreateAd(post(BODY), deps);
  assertEquals((await res.json()).ad_id, "ad-0");
  assertEquals(moderatedCount(), 0);
  assertEquals(created.length, 0);
});

Deno.test("missing required dynamic field: 400 before any AI call", async () => {
  const { deps, moderatedCount } = fakeDeps();
  const res = await handleCreateAd(post({ ...BODY, dynamic_fields: {} }), deps);
  assertEquals(res.status, 400);
  assertEquals(moderatedCount(), 0);
});
