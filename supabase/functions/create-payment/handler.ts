// Starts a Paymob payment for a server-priced package.
// The client sends only { package_id, ad_id?, payment_method? };
// the amount always comes from payment_packages.

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export const PAYMENT_METHODS = ["card", "fawry", "instapay", "vodafone_cash"] as const;
type PaymentMethod = typeof PAYMENT_METHODS[number];

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface PaymentPackage {
  id: string;
  kind: "ad_boost" | "subscription" | "credit_purchase";
  price_egp: number;
  boost_type: "featured" | "urgent" | "bump" | null;
}

export interface BillingProfile {
  fullName: string;
  email: string | null;
  phone: string | null;
}

export interface NewTransaction {
  user_id: string;
  type: PaymentPackage["kind"];
  package_id: string;
  reference_id: string | null;
  reference_type: string | null;
  amount: number;
  currency: "EGP";
  payment_method: PaymentMethod;
  payment_gateway: "paymob";
  status: "pending";
}

export interface CreatePaymentDeps {
  authenticate(token: string): Promise<string | null>;
  getActivePackage(id: string): Promise<PaymentPackage | null>;
  getAd(id: string): Promise<{ user_id: string; status: string } | null>;
  hasActiveBoost(adId: string, boostType: string): Promise<boolean>;
  getBillingProfile(userId: string): Promise<BillingProfile>;
  insertTransaction(tx: NewTransaction): Promise<string>;
  createPaymobPayment(args: {
    amountCents: number;
    merchantOrderId: string;
    billing: BillingProfile;
  }): Promise<{ orderId: string; iframeUrl: string }>;
  attachGatewayOrder(transactionId: string, orderId: string): Promise<void>;
  markFailed(transactionId: string, reason: string): Promise<void>;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export async function handleCreatePayment(req: Request, deps: CreatePaymentDeps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "طريقة الطلب غير مدعومة" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "غير مصرح بالدخول (توكن مفقود)" }, 401);
  const userId = await deps.authenticate(authHeader.substring(7));
  if (!userId) return json({ error: "جلسة العمل منتهية أو غير صالحة" }, 401);

  let body: { package_id?: unknown; ad_id?: unknown; payment_method?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "محتوى الطلب غير صالح" }, 400);
  }

  const packageId = typeof body.package_id === "string" ? body.package_id : "";
  if (!packageId) return json({ error: "الباقة المطلوبة غير محددة (package_id)" }, 400);

  const method = (body.payment_method ?? "card") as PaymentMethod;
  if (!PAYMENT_METHODS.includes(method)) return json({ error: "طريقة الدفع المحددة غير مدعومة" }, 400);

  const pkg = await deps.getActivePackage(packageId);
  if (!pkg) return json({ error: "الباقة المحددة غير متاحة" }, 400);

  let referenceId: string | null = null;
  if (pkg.kind === "ad_boost") {
    const adId = typeof body.ad_id === "string" ? body.ad_id : "";
    if (!UUID_RE.test(adId)) return json({ error: "رقم تعريف الإعلان مطلوب للترقية" }, 400);

    const ad = await deps.getAd(adId);
    if (!ad) return json({ error: "الإعلان المحدد غير موجود" }, 400);
    if (ad.user_id !== userId) return json({ error: "غير مصرح لك بترقية هذا الإعلان (أنت لا تملكه)" }, 403);
    if (ad.status !== "active") return json({ error: "لا يمكن ترقية إعلان غير نشط" }, 400);
    if (pkg.boost_type !== "bump" && await deps.hasActiveBoost(adId, pkg.boost_type!)) {
      return json({ error: "هذا الإعلان لديه ترقية نشطة من نفس النوع بالفعل" }, 409);
    }
    referenceId = adId;
  }

  const transactionId = await deps.insertTransaction({
    user_id: userId,
    type: pkg.kind,
    package_id: pkg.id,
    reference_id: referenceId,
    reference_type: referenceId ? "ad" : null,
    amount: Number(pkg.price_egp),
    currency: "EGP",
    payment_method: method,
    payment_gateway: "paymob",
    status: "pending",
  });

  let payment: { orderId: string; iframeUrl: string };
  try {
    payment = await deps.createPaymobPayment({
      amountCents: Math.round(Number(pkg.price_egp) * 100),
      merchantOrderId: transactionId,
      billing: await deps.getBillingProfile(userId),
    });
  } catch (err) {
    console.error("create-payment: Paymob request failed", err instanceof Error ? err.message : err);
    await deps.markFailed(transactionId, "gateway_init_failed");
    return json({ error: "تعذّر الاتصال ببوابة الدفع، حاول مرة أخرى" }, 502);
  }

  await deps.attachGatewayOrder(transactionId, payment.orderId);

  return json({
    success: true,
    transaction_id: transactionId,
    amount: Number(pkg.price_egp),
    payment_url: payment.iframeUrl,
  }, 200);
}
