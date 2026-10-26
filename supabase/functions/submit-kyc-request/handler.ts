// Accepts a national-ID verification request: validates the ID, stores the
// card images in the private id-documents bucket and opens a pending
// verification for a moderator. Documents are deleted after the decision
// (purge-kyc-documents).

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export interface SubmitKycDeps {
  authenticate(token: string): Promise<string | null>;
  hasPendingRequest(userId: string): Promise<boolean>;
  uploadDocument(path: string, bytes: Uint8Array): Promise<void>;
  createVerification(row: {
    user_id: string;
    document_url: string;
    document_back_url: string;
    national_id: string;
  }): Promise<void>;
  updateFullName(userId: string, fullName: string): Promise<void>;
  now(): number;
}

// Local Egyptian National ID validation
export function validateNationalId(id: string): { isValid: boolean; error?: string } {
  if (!id) {
    return { isValid: false, error: "الرقم القومي مطلوب" };
  }
  
  const trimmed = id.trim();
  
  if (trimmed.length !== 14) {
    return { isValid: false, error: "يجب أن يتكون الرقم القومي من 14 رقماً" };
  }
  
  if (!/^\d+$/.test(trimmed)) {
    return { isValid: false, error: "يجب أن يحتوي الرقم القومي على أرقام فقط" };
  }
  
  const firstDigit = trimmed.charAt(0);
  if (firstDigit !== "2" && firstDigit !== "3") {
    return { isValid: false, error: "الرقم القومي غير صحيح (يجب أن يبدأ بـ 2 أو 3)" };
  }
  
  const yyStr = trimmed.substring(1, 3);
  const mmStr = trimmed.substring(3, 5);
  const ddStr = trimmed.substring(5, 7);
  
  const yy = parseInt(yyStr, 10);
  const mm = parseInt(mmStr, 10);
  const dd = parseInt(ddStr, 10);
  
  if (mm < 1 || mm > 12) {
    return { isValid: false, error: "صيغة التاريخ في الرقم القومي غير صحيحة (الشهر غير صالح)" };
  }
  
  if (dd < 1 || dd > 31) {
    return { isValid: false, error: "صيغة التاريخ في الرقم القومي غير صحيحة (اليوم غير صالح)" };
  }
  
  const birthYear = (firstDigit === "2" ? 1900 : 2000) + yy;
  const birthDate = new Date(birthYear, mm - 1, dd);
  
  if (
    birthDate.getFullYear() !== birthYear ||
    birthDate.getMonth() !== mm - 1 ||
    birthDate.getDate() !== dd
  ) {
    return { isValid: false, error: "تاريخ الميلاد في الرقم القومي غير صالح" };
  }
  
  if (birthDate.getTime() > Date.now()) {
    return { isValid: false, error: "تاريخ الميلاد في الرقم القومي لا يمكن أن يكون في المستقبل" };
  }
  
  return { isValid: true };
}

export function base64ToBytes(base64: string): Uint8Array {
  const clean = base64.replace(/^data:image\/[a-z]+;base64,/, "");
  const binaryString = atob(clean);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

export async function handleSubmitKyc(req: Request, deps: SubmitKycDeps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "غير مصرح بالدخول (توكن مفقود)" }, 401);
  const userId = await deps.authenticate(authHeader.substring(7));
  if (!userId) return json({ error: "جلسة العمل منتهية أو غير صالحة" }, 401);

  let body: { full_name?: unknown; national_id?: unknown; front_image?: unknown; back_image?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "محتوى الطلب غير صالح" }, 400);
  }

  const fullName = typeof body.full_name === "string" ? body.full_name.trim() : "";
  if (!fullName) return json({ error: "الاسم الكامل مطلوب" }, 400);

  const nationalId = typeof body.national_id === "string" ? body.national_id : "";
  const idValidation = validateNationalId(nationalId);
  if (!idValidation.isValid) return json({ error: idValidation.error }, 400);

  if (typeof body.front_image !== "string" || typeof body.back_image !== "string" || !body.front_image || !body.back_image) {
    return json({ error: "صور بطاقة الرقم القومي مطلوبة (الوجه والخلفية)" }, 400);
  }

  if (await deps.hasPendingRequest(userId)) return json({ error: "لديك طلب تحقق قيد المراجعة بالفعل" }, 400);

  let frontBytes: Uint8Array;
  let backBytes: Uint8Array;
  try {
    frontBytes = base64ToBytes(body.front_image);
    backBytes = base64ToBytes(body.back_image);
  } catch {
    return json({ error: "فشل فك تشفير الصور. يرجى التأكد من إرسال صيغة base64 صالحة." }, 400);
  }

  const folder = `${userId}/kyc/${deps.now()}`;
  const frontPath = `${folder}/front.jpg`;
  const backPath = `${folder}/back.jpg`;
  await deps.uploadDocument(frontPath, frontBytes);
  await deps.uploadDocument(backPath, backBytes);

  await deps.createVerification({
    user_id: userId,
    document_url: frontPath,
    document_back_url: backPath,
    national_id: nationalId.trim(),
  });
  await deps.updateFullName(userId, fullName);

  return json({ success: true, message: "تم تقديم طلب التحقق بنجاح." }, 200);
}
