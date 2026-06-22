import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { title, description, price, category } = await req.json();

    // Standard local check first to catch obvious issues and serve as a fallback
    let fallbackRiskLevel = "low";
    let fallbackReviewNotes = "تمت المراجعة التلقائية بنجاح، المحتوى يبدو آمناً وموافق للشروط.";
    const checkedContent = `${title ?? ""} ${description ?? ""}`.toLowerCase();
    
    // Prohibited keywords scanner
    const prohibitedWords = ["سلاح", "مخدرات", "نصب", "احتيال", "ممنوعات", "دولار", "سوق سوداء"];
    const foundKeywords = prohibitedWords.filter(word => checkedContent.includes(word));
    
    if (foundKeywords.length > 0) {
      fallbackRiskLevel = "high";
      fallbackReviewNotes = `تم تعليق الإعلان تلقائياً لاشتباهه في محتوى محظور: (${foundKeywords.join(", ")}).`;
    }

    // Price anomaly check
    if (price !== undefined && price !== null) {
      const priceNum = Number(price);
      if (priceNum <= 0) {
        fallbackRiskLevel = "high";
        fallbackReviewNotes = "سعر غير صالح: يجب أن يكون السعر أكبر من صفر.";
      }
    }

    const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!anthropicKey) {
      console.warn("ANTHROPIC_API_KEY is not set. Using local rule-based evaluation.");
      const risk = fallbackRiskLevel === "high" ? "high" : "medium";
      const notes = fallbackRiskLevel === "high" 
        ? fallbackReviewNotes 
        : "مفتاح مراجعة المحتوى غير متوفر، تم التقييم كمتوسط للمراجعة البشرية.";
      return new Response(
        JSON.stringify({ ai_risk_level: risk, ai_review_notes: notes }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Prompt for Claude
    const prompt = `أنت مراجع محتوى ذكي ومحترف لمنصة إعلانات مبوبة في مصر تُدعى "وصلة".
قم بمراجعة الإعلان التالي بعناية فائقة لتحديد ما إذا كان يحتوي على أي مخالفات لشروط النشر.

تفاصيل الإعلان:
- العنوان: ${title ?? "غير محدد"}
- الوصف: ${description ?? "غير محدد"}
- السعر: ${price ?? "غير محدد"} ج.م
- القسم: ${category ?? "غير محدد"}

القواعد والمعايير:
1. يمنع منعاً باتاً نشر إعلانات لبيع أو ترويج الأسلحة، المخدرات، الأدوية الطبية، الخدمات الجنسية أو غير اللائقة، معاملات النصب والاحتيال، العملات الأجنبية في السوق السوداء (مثل تداول الدولار خارج البنوك)، أو أي سلع غير قانونية.
2. تتبع الأسعار الشاذة أو غير المنطقية، مثل عرض هاتف آيفون حديث بـ 1 جنيه، أو سيارة بـ 10 جنيهات، أو أسعار ضخمة خيالية لا تتناسب مع السلعة، فهذا مؤشر قوي على الاحتيال أو التضليل.
3. تفحص نصوص النصب والاحتيال مثل إعلانات "الربح السريع"، "العمل من المنزل بدون خبرة برواتب خيالية"، أو طلب دفع رسوم قبل التوظيف.

يجب أن تقوم بتقييم هذا الإعلان وتحديد مستوى الخطورة (ai_risk_level) بإحدى القيم التالية فقط:
- "low": إذا كان الإعلان آمناً ومستوفياً لكافة الشروط بنسبة 100%.
- "medium": إذا كان هناك شك بسيط، أو سعر شاذ غير مؤكد، أو حاجة لمراجعة بشرية للتأكد.
- "high": إذا كان الإعلان يخالف الشروط بوضوح وصراحة ويجب تعليقه فوراً.

أرجع الإجابة فقط بتنسيق JSON صالح ومباشر دون أي مقدمات أو نصوص أخرى بالصيغة التالية تماماً:
{
  "ai_risk_level": "low" | "medium" | "high",
  "ai_review_notes": "تفصيل موجز لسبب التقييم باللغة العربية"
}`;

    // Call Anthropic API with 10 seconds timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);

    try {
      const anthropicResponse = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": anthropicKey,
          "anthropic-version": "2023-06-01",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model: "claude-3-5-haiku-20241022",
          max_tokens: 200,
          messages: [{ role: "user", content: prompt }],
        }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!anthropicResponse.ok) {
        throw new Error(`Anthropic API returned status ${anthropicResponse.status}`);
      }

      const resultJson = await anthropicResponse.json();
      const text = resultJson.content?.[0]?.text?.trim() ?? "";
      
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        const aiRiskLevel = parsed.ai_risk_level;
        const aiReviewNotes = parsed.ai_review_notes;
        
        if (["low", "medium", "high"].includes(aiRiskLevel)) {
          if (fallbackRiskLevel === "high" && aiRiskLevel !== "high") {
            return new Response(
              JSON.stringify({ 
                ai_risk_level: "high", 
                ai_review_notes: `${fallbackReviewNotes} (مراجعة إضافية: ${aiReviewNotes})` 
              }),
              { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          }

          return new Response(
            JSON.stringify({ ai_risk_level: aiRiskLevel, ai_review_notes: aiReviewNotes }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }
      throw new Error("Failed to parse valid JSON structure from Claude response.");

    } catch (apiErr) {
      console.error("Claude API call failed or timed out:", apiErr);
      const finalRisk = fallbackRiskLevel === "high" ? "high" : "medium";
      const finalNotes = fallbackRiskLevel === "high" 
        ? fallbackReviewNotes 
        : "فشلت المراجعة التلقائية المعمقة للذكاء الاصطناعي بسبب عطل مؤقت، تم تعيين الخطورة افتراضياً كمتوسطة.";
      return new Response(
        JSON.stringify({ ai_risk_level: finalRisk, ai_review_notes: finalNotes }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

  } catch (error: any) {
    return new Response(
      JSON.stringify({ 
        ai_risk_level: "medium", 
        ai_review_notes: `حدث خطأ أثناء معالجة الطلب: ${error.message ?? error}` 
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
