import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { Classifier, configFromEnv, moderateAd, Verdict } from "./moderation.ts";

const CONFIG = { fastModel: "fast-model", deepModel: "deep-model", timeoutMs: 50 };
const AD = { title: "تويوتا كورولا 2019", description: "حالة ممتازة", price: 350000, category: "سيارات" };

function fakeClassifier(byModel: Record<string, Verdict | null | "throw" | "hang">) {
  const calls: string[] = [];
  const classifier: Classifier = {
    classify(model, _ad, signal) {
      calls.push(model);
      const b = byModel[model];
      if (b === "throw") return Promise.reject(new Error("529 overloaded"));
      if (b === "hang") {
        return new Promise((_, reject) => signal.addEventListener("abort", () => reject(new Error("aborted"))));
      }
      return Promise.resolve(b ?? null);
    },
  };
  return { classifier, calls };
}

Deno.test("model names come from the environment, not the code", () => {
  const env: Record<string, string> = { MODERATION_MODEL_FAST: "m-fast", MODERATION_MODEL_DEEP: "m-deep" };
  assertEquals(configFromEnv((k) => env[k])?.fastModel, "m-fast");
  assertEquals(configFromEnv((k) => env[k])?.deepModel, "m-deep");
  assertEquals(configFromEnv(() => undefined), null);
});

Deno.test("layer 1: banned words are flagged high without calling the API", async () => {
  const { classifier, calls } = fakeClassifier({});
  const r = await moderateAd({ ...AD, title: "مسدس للبيع" }, classifier, CONFIG);
  assertEquals([r.riskLevel, r.layer], ["high", 1]);
  assertEquals(calls, []);
});

Deno.test("layer 2: a low verdict from the fast model stops there", async () => {
  const { classifier, calls } = fakeClassifier({ "fast-model": { risk_level: "low", reason: "سليم" } });
  const r = await moderateAd(AD, classifier, CONFIG);
  assertEquals([r.riskLevel, r.layer, r.model], ["low", 2, "fast-model"]);
  assertEquals(calls, ["fast-model"]);
});

Deno.test("layer 3: anything but low goes to the deep model", async () => {
  const { classifier, calls } = fakeClassifier({
    "fast-model": { risk_level: "medium", reason: "سعر غريب" },
    "deep-model": { risk_level: "high", reason: "نصب" },
  });
  const r = await moderateAd(AD, classifier, CONFIG);
  assertEquals([r.riskLevel, r.layer, r.model, r.notes], ["high", 3, "deep-model", "نصب"]);
  assertEquals(calls, ["fast-model", "deep-model"]);
});

Deno.test("fail-safe: API error -> unreviewed (manual review), never low", async () => {
  const { classifier } = fakeClassifier({ "fast-model": "throw" });
  const r = await moderateAd(AD, classifier, CONFIG);
  assertEquals([r.riskLevel, r.layer], ["unreviewed", 0]);
  assertEquals(r.error, "529 overloaded");
});

Deno.test("fail-safe: timeout -> unreviewed", async () => {
  const { classifier } = fakeClassifier({ "fast-model": "hang" });
  const r = await moderateAd(AD, classifier, CONFIG);
  assertEquals(r.riskLevel, "unreviewed");
});

Deno.test("fail-safe: unparseable or refused answer (null) -> unreviewed", async () => {
  const { classifier } = fakeClassifier({ "fast-model": null });
  assertEquals((await moderateAd(AD, classifier, CONFIG)).riskLevel, "unreviewed");
});

Deno.test("fail-safe: deep model failing after a flag keeps the flag (never downgrades to low)", async () => {
  const { classifier } = fakeClassifier({ "fast-model": { risk_level: "medium", reason: "شك" }, "deep-model": "throw" });
  const r = await moderateAd(AD, classifier, CONFIG);
  assertEquals([r.riskLevel, r.layer], ["medium", 2]);
});

Deno.test("fail-safe: no API key or no model configuration -> unreviewed", async () => {
  assertEquals((await moderateAd(AD, null, CONFIG)).riskLevel, "unreviewed");
  const { classifier } = fakeClassifier({});
  assertEquals((await moderateAd(AD, classifier, null)).riskLevel, "unreviewed");
});
