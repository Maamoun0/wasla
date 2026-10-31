// Live check of AI ad review against the real Anthropic API, through the same
// moderateAd + anthropicClassifier that create-ad uses. Spends a few cents.
// Skipped unless ANTHROPIC_API_KEY is set.
//   deno test --config supabase/functions/deno.json --no-lock --allow-env --allow-net supabase/tests/live/anthropic_moderation.live.ts
import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { anthropicClassifier, configFromEnv, moderateAd } from "../../functions/create-ad/moderation.ts";

const apiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
// Same defaults as supabase/functions/.env.example unless overridden.
const config = configFromEnv((k) =>
  Deno.env.get(k) ?? ({ MODERATION_MODEL_FAST: "claude-haiku-5-5", MODERATION_MODEL_DEEP: "claude-sonnet-5-5" } as Record<string, string>)[k]
)!;

Deno.test({
  name: "a normal ad is classified low by the fast model",
  ignore: !apiKey,
  async fn() {
    const result = await moderateAd(
      {
        title: "آيفون 13 مستعمل بحالة ممتازة",
        description: "ذاكرة 128 جيجا، البطارية 89%، مع العلبة والشاحن. المعاينة في مدينة نصر.",
        price: 18000,
        category: "موبايلات",
      },
      anthropicClassifier(apiKey),
      config,
    );
    console.log(result);
    assertEquals(result.error, null, "no API, model-name or parsing error");
    assertEquals(result.riskLevel, "low");
    assertEquals(result.layer, 2);
    assertEquals(result.model, config.fastModel);
  },
});

Deno.test({
  name: "an obvious scam that passes the keyword filter is flagged and goes to the deep model",
  ignore: !apiKey,
  async fn() {
    const result = await moderateAd(
      {
        title: "فرصة عمل من البيت بدخل 30 ألف شهرياً",
        description: "حوّل 500 جنيه رسوم تسجيل على فودافون كاش وهتبدأ تستلم أرباحك من تاني يوم. العدد محدود.",
        price: 500,
        category: "وظائف",
      },
      anthropicClassifier(apiKey),
      config,
    );
    console.log(result);
    assertEquals(result.error, null, "no API, model-name or parsing error");
    assert(result.riskLevel === "medium" || result.riskLevel === "high", `got ${result.riskLevel}`);
    assertEquals(result.layer, 3);
    assertEquals(result.model, config.deepModel);
  },
});
