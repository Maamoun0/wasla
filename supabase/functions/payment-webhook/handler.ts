// Paymob "transaction processed" callback.
// Verifies the HMAC, then hands the result to fulfill_payment(), which
// checks the paid amount and activates the purchase atomically.

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export type FulfilResult =
  | "completed"
  | "failed"
  | "amount_mismatch"
  | "already_processed"
  | "not_found";

export interface StoredTransaction {
  id: string;
  user_id: string;
}

export interface WebhookDeps {
  hmacSecret: string;
  findTransactionByOrderId(orderId: string): Promise<StoredTransaction | null>;
  fulfil(args: {
    transactionId: string;
    success: boolean;
    amountCents: number;
    currency: string;
    gatewayData: Record<string, unknown>;
  }): Promise<FulfilResult>;
  onCompleted?(tx: StoredTransaction, ipAddress: string): Promise<void>;
}

type PaymobObj = Record<string, unknown> & {
  order?: { id?: unknown } | unknown;
  source_data?: { pan?: unknown; sub_type?: unknown; type?: unknown };
};

// Field order defined by Paymob for the processed-callback HMAC
// (docs/wasla_paymob_hmac_reference.md).
export function paymobHmacMessage(obj: PaymobObj): string {
  const order = obj.order as { id?: unknown } | unknown;
  const orderId = order !== null && typeof order === "object" ? (order as { id?: unknown }).id : order;
  const values = [
    obj.amount_cents,
    obj.created_at,
    obj.currency,
    obj.error_occured,
    obj.has_parent_transaction,
    obj.id,
    obj.integration_id,
    obj.is_3d_secure,
    obj.is_auth,
    obj.is_capture,
    obj.is_refunded,
    obj.is_standalone_payment,
    obj.is_voided,
    orderId,
    obj.owner,
    obj.pending,
    obj.source_data?.pan ?? "",
    obj.source_data?.sub_type ?? "",
    obj.source_data?.type ?? "",
    obj.success,
  ];
  return values.map((v) => String(v)).join("");
}

export async function computePaymobHmac(secret: string, obj: PaymobObj): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(paymobHmacMessage(obj)));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export async function handleWebhook(req: Request, deps: WebhookDeps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method Not Allowed" }, 405);

  const receivedHmac = (new URL(req.url).searchParams.get("hmac") ?? "").toLowerCase();
  if (!receivedHmac) return json({ error: "توقيع HMAC مفقود" }, 401);

  let body: { obj?: PaymobObj };
  try {
    body = await req.json();
  } catch {
    return json({ error: "محتوى الطلب غير صالح" }, 400);
  }
  const obj = body?.obj;
  if (!obj || typeof obj !== "object") return json({ error: "محتوى الطلب غير صالح" }, 400);

  const expected = await computePaymobHmac(deps.hmacSecret, obj);
  if (!timingSafeEqual(expected, receivedHmac)) {
    console.warn("payment-webhook: HMAC verification failed");
    return json({ error: "توقيع HMAC غير صحيح" }, 401);
  }

  const order = obj.order as { id?: unknown } | unknown;
  const orderId = String(order !== null && typeof order === "object" ? (order as { id?: unknown }).id : order);
  const tx = await deps.findTransactionByOrderId(orderId);
  if (!tx) {
    console.warn(`payment-webhook: no transaction for order ${orderId}`);
    return json({ error: "المعاملة غير مسجلة بالنظام" }, 404);
  }

  const result = await deps.fulfil({
    transactionId: tx.id,
    success: obj.success === true && obj.pending === false,
    amountCents: Number(obj.amount_cents),
    currency: String(obj.currency ?? ""),
    gatewayData: {
      id: obj.id,
      order_id: orderId,
      amount_cents: obj.amount_cents,
      currency: obj.currency,
      success: obj.success,
      pending: obj.pending,
      source_type: obj.source_data?.type ?? null,
      created_at: obj.created_at,
    },
  });

  console.info(`payment-webhook: transaction ${tx.id} -> ${result}`);
  if (result === "amount_mismatch") {
    console.error(`payment-webhook: amount/currency mismatch on transaction ${tx.id}`);
  }
  if (result === "completed" && deps.onCompleted) {
    const ip = req.headers.get("x-real-ip") ?? req.headers.get("x-forwarded-for") ?? "unknown";
    await deps.onCompleted(tx, ip);
  }

  // 200 for every terminal outcome so Paymob does not keep retrying.
  return json({ success: true, result }, 200);
}
