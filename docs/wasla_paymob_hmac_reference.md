# Paymob Egypt HMAC Verification Reference

This document provides a technical reference for validating Paymob transaction webhooks (callbacks) in the Wasla platform. This will serve as the specifications for implementing the `payment-webhook` in Sprint 6.

---

## 1. Hashing Details
* **Algorithm:** SHA-512
* **Hashing Key:** HMAC Secret Key (provided in the Paymob Dashboard under **Settings > Account Info**).
* **Payload Source:** Incoming HTTP POST request body. Paymob passes callback fields nested within the `obj` parameter of the JSON payload.
* **Signature Location:** Appended to the callback URL as the `hmac` query parameter (e.g. `https://wasla.eg/payment/webhook?hmac=[HASH_HERE]`).

---

## 2. Order of Concatenation Fields
The signature is highly order-sensitive. Concatenate the values of the following parameters, sorted lexicographically by their keys, into a single raw string with no spaces or delimiters:

| Order | Parameter Name | Extraction Path from Webhook JSON |
|-------|----------------|----------------------------------|
| 1     | `amount_cents` | `obj.amount_cents` |
| 2     | `created_at` | `obj.created_at` |
| 3     | `currency` | `obj.currency` |
| 4     | `error_occured` | `obj.error_occured` |
| 5     | `has_parent_transaction` | `obj.has_parent_transaction` |
| 6     | `id` | `obj.id` |
| 7     | `integration_id` | `obj.integration_id` |
| 8     | `is_3d_secure` | `obj.is_3d_secure` |
| 9     | `is_auth` | `obj.is_auth` |
| 10    | `is_capture` | `obj.is_capture` |
| 11    | `is_refunded` | `obj.is_refunded` |
| 12    | `is_standalone_payment` | `obj.is_standalone_payment` |
| 13    | `is_voided` | `obj.is_voided` |
| 14    | `order` | `obj.order.id` |
| 15    | `owner` | `obj.owner` |
| 16    | `pending` | `obj.pending` |
| 17    | `source_data.pan` | `obj.source_data.pan` |
| 18    | `source_data.sub_type` | `obj.source_data.sub_type` |
| 19    | `source_data.type` | `obj.source_data.type` |
| 20    | `success` | `obj.success` |

---

## 3. Reference Verification Pseudo-code (Deno TypeScript)
```typescript
import { hmac } from "https://deno.land/x/hmac@v1.9.3/mod.ts";

function verifyPaymobSignature(payload: any, receivedHmac: string, hmacSecret: string): boolean {
  const transaction = payload.obj;
  if (!transaction) return false;

  // Retrieve values in the exact lexicographical key order
  const values = [
    transaction.amount_cents,
    transaction.created_at,
    transaction.currency,
    transaction.error_occured,
    transaction.has_parent_transaction,
    transaction.id,
    transaction.integration_id,
    transaction.is_3d_secure,
    transaction.is_auth,
    transaction.is_capture,
    transaction.is_refunded,
    transaction.is_standalone_payment,
    transaction.is_voided,
    transaction.order?.id,
    transaction.owner,
    transaction.pending,
    transaction.source_data?.pan,
    transaction.source_data?.sub_type,
    transaction.source_data?.type,
    transaction.success
  ];

  // Concatenate values into a single continuous string
  const concatenatedString = values.map(val => String(val)).join("");

  // Calculate HMAC-SHA512 signature
  const calculatedHmac = hmac("sha512", hmacSecret, concatenatedString, "utf8", "hex");

  return calculatedHmac === receivedHmac;
}
```
