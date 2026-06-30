import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { image_url, category_name } = await req.json();

    const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!anthropicKey) {
      throw new Error("Anthropic API key is missing");
    }

    const prompt = `
أنت خبير في تحليل الصور لمنصة إعلانات مبوبة. 
قم بتحليل الصورة المرفقة واستخرج البيانات المناسبة لقسم "${category_name || "عام"}".

المطلوب استخراج:
1. عنوان جذاب (title) باللغة العربية.
2. وصف مختصر (description) باللغة العربية.
3. تفاصيل تقنية (features) مثل الماركة، الموديل، الحالة، اللون (حسب القسم).

أرجع الإجابة بتنسيق JSON فقط باللغة العربية:
{
  "suggested_title": "...",
  "suggested_description": "...",
  "suggested_fields": {
    "brand": "...",
    "model": "...",
    "condition": "...",
    "color": "..."
  }
}`;

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: "claude-3-5-sonnet-20241022",
        max_tokens: 1000,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "text",
                text: prompt
              },
              {
                type: "image",
                source: {
                  type: "url",
                  url: image_url
                }
              }
            ]
          }
        ],
      }),
    });

    const data = await response.json();
    const text = data.content?.[0]?.text?.trim() ?? "{}";
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    
    return new Response(
      jsonMatch ? jsonMatch[0] : JSON.stringify({ error: "Failed to parse AI response" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
