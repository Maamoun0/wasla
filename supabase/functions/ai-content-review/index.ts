import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const BANNED_PATTERNS = [
  // أسلحة
  /سلاح|مسدس|بندقية|ذخيرة|متفجر/i,
  // مخدرات
  /مخدر|حشيش|بانجو|كوكايين|هيروين/i,
  // نصب صريح
  /ربح سريع|مليون في أسبوع|استثمار مضمون 100%/i,
  // وثائق مزوّرة
  /شهادة مزور|رخصة مزور|جواز مزور/i,
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { title, description, price, category } = await req.json();
    const fullText = `${title ?? ""} ${description ?? ""}`;

    // الطبقة 1: RegEx (محلي، بلا استدعاء خارجي)
    for (const pattern of BANNED_PATTERNS) {
      if (pattern.test(fullText)) {
        return new Response(
          JSON.stringify({
            ai_risk_level: 'high',
            ai_review_notes: 'محتوى مخالف صريح — كلمات محظورة',
            ai_layer_used: 1
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!anthropicKey) {
      return new Response(
        JSON.stringify({ 
          ai_risk_level: "medium", 
          ai_review_notes: "مفتاح مراجعة المحتوى غير متوفر، تم التقييم كمتوسط للمراجعة البشرية.",
          ai_layer_used: 0 
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const buildPrompt = (t: string, d: string, p: any, c: string) => `
أنت مراجع محتوى ذكي ومحترف لمنصة إعلانات مبوبة في مصر تُدعى "وصلة".
قم بمراجعة الإعلان التالي بعناية لتحديد مستوى الخطورة (ai_risk_level).

تفاصيل الإعلان:
- العنوان: ${t ?? "غير محدد"}
- الوصف: ${d ?? "غير محدد"}
- السعر: ${p ?? "غير محدد"} ج.م
- القسم: ${c ?? "غير محدد"}

القيم المتاحة لـ risk_level:
- "low": الإعلان آمن ومستوفٍ للشروط.
- "medium": شكوك بسيطة، سعر شاذ، أو يحتاج مراجعة بشرية.
- "high": مخالف صريح (نصب، أسلحة، مخدرات، سلع غير قانونية).

أرجع الإجابة بتنسيق JSON فقط:
{
  "risk_level": "low" | "medium" | "high",
  "notes": "سبب التقييم باختصار باللغة العربية"
}`;

    const callClaude = async (model: string, prompt: string) => {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": anthropicKey,
          "anthropic-version": "2023-06-01",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model: model,
          max_tokens: 200,
          messages: [{ role: "user", content: prompt }],
        }),
      });

      if (!response.ok) throw new Error(`Anthropic API returned status ${response.status}`);
      const data = await response.json();
      const text = data.content?.[0]?.text?.trim() ?? "";
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) throw new Error("Failed to parse valid JSON structure from Claude response.");
      return JSON.parse(jsonMatch[0]);
    };

    try {
      // الطبقة 2: Haiku (سريع ورخيص)
      const haikuResult = await callClaude("claude-3-5-haiku-20241022", buildPrompt(title, description, price, category));
      
      if (haikuResult.risk_level === 'low') {
        return new Response(
          JSON.stringify({ 
            ai_risk_level: 'low', 
            ai_review_notes: haikuResult.notes, 
            ai_layer_used: 2 
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // الطبقة 3: Sonnet (للحالات المشكوك فيها أو التقييمات المتوسطة/العالية من هايكو)
      const sonnetResult = await callClaude("claude-3-5-sonnet-20241022", buildPrompt(title, description, price, category));
      
      return new Response(
        JSON.stringify({ 
          ai_risk_level: sonnetResult.risk_level, 
          ai_review_notes: sonnetResult.notes, 
          ai_layer_used: 3 
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );

    } catch (apiErr) {
      console.error("Claude API call failed:", apiErr);
      return new Response(
        JSON.stringify({ 
          ai_risk_level: "medium", 
          ai_review_notes: "فشلت المراجعة التلقائية بسبب عطل فني، تم التقييم كمتوسط افتراضياً.",
          ai_layer_used: 0 
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

  } catch (error: any) {
    return new Response(
      JSON.stringify({ 
        ai_risk_level: "medium", 
        ai_review_notes: `حدث خطأ داخلي: ${error.message}` 
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
