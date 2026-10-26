// Minimal Paymob Accept client: auth token -> order -> payment key.
import type { BillingProfile } from "./handler.ts";

const BASE = "https://accept.paymob.com/api";
const TIMEOUT_MS = 15000;

export interface PaymobConfig {
  apiKey: string;
  integrationId: number;
  iframeId: number;
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`Paymob ${path} returned ${res.status}`);
  return await res.json() as T;
}

// Paymob requires every billing field; "NA" is its documented placeholder
// for values the merchant does not collect.
function billingData(b: BillingProfile) {
  const parts = b.fullName.trim().split(/\s+/).filter(Boolean);
  return {
    first_name: parts[0] ?? "NA",
    last_name: parts.slice(1).join(" ") || "NA",
    email: b.email || "NA",
    phone_number: b.phone || "NA",
    apartment: "NA",
    floor: "NA",
    street: "NA",
    building: "NA",
    shipping_method: "NA",
    postal_code: "NA",
    city: "NA",
    state: "NA",
    country: "EG",
  };
}

export async function createPaymobPayment(
  cfg: PaymobConfig,
  args: { amountCents: number; merchantOrderId: string; billing: BillingProfile },
): Promise<{ orderId: string; iframeUrl: string }> {
  const { token } = await post<{ token?: string }>("/auth/tokens", { api_key: cfg.apiKey });
  if (!token) throw new Error("Paymob auth returned no token");

  const order = await post<{ id?: number }>("/ecommerce/orders", {
    auth_token: token,
    delivery_needed: false,
    amount_cents: args.amountCents,
    currency: "EGP",
    merchant_order_id: args.merchantOrderId,
    items: [],
  });
  if (!order.id) throw new Error("Paymob order returned no id");

  const key = await post<{ token?: string }>("/acceptance/payment_keys", {
    auth_token: token,
    amount_cents: args.amountCents,
    expiration: 3600,
    order_id: order.id,
    billing_data: billingData(args.billing),
    currency: "EGP",
    integration_id: cfg.integrationId,
  });
  if (!key.token) throw new Error("Paymob payment key returned no token");

  return {
    orderId: String(order.id),
    iframeUrl: `https://accept.paymob.com/api/acceptance/iframes/${cfg.iframeId}?payment_token=${key.token}`,
  };
}
