# Wasla Security & Webhook Manual Testing Guide / دليل اختبار الأمان والبوابات البرمجية

This guide provides step-by-step instructions for manually testing the security constraints of the **Sprint 6 Payment Webhook** using **Postman** and the **Supabase Dashboard**.

---

## 🧪 Test 1: Wrong HMAC Signature (Security Check) / اختبار HMAC غير صحيح

**Objective:** Validate that the system rejects payloads with missing or invalid signatures before processing any logic, returning `401 Unauthorized`.

### 📮 Postman Request Configuration:
* **Method:** `POST`
* **URL:** `https://[your-supabase-project].supabase.co/functions/v1/payment-webhook?hmac=INVALID_HMAC_123456`
* **Headers:**
  * `Content-Type`: `application/json`
* **JSON Body:**
```json
{
  "type": "TRANSACTION",
  "obj": {
    "id": 9999999,
    "pending": false,
    "success": true,
    "amount_cents": 6000,
    "currency": "EGP",
    "error_occured": false,
    "is_auth": false,
    "is_capture": true,
    "is_voided": false,
    "is_refunded": false,
    "is_standalone_payment": true,
    "is_3d_secure": true,
    "integration_id": 112233,
    "order": {
      "id": 8888888
    },
    "owner": 102030,
    "created_at": "2026-06-23T00:00:00.000Z",
    "source_data": {
      "pan": "xxxx-xxxx-xxxx-4242",
      "sub_type": "Visa",
      "type": "card"
    }
  }
}
```

### 🎯 Expected Result:
* **HTTP Status Code:** `401 Unauthorized`
* **Response Body:** `{"error":"توقيع HMAC غير صحيح"}`
* *Note:* If the server returns `200 OK` or `500 Internal Server Error`, the check failed.

---

## 🧪 Test 2: Webhook Idempotency (Prevent Double Activation) / اختبار تكرار طلبات التفعيل

**Objective:** Ensure that sending the same successful payment callback twice does not result in duplicate promotion records or double-crediting.

### 📮 Postman Setup:
1. First, create a pending transaction in your database (either by calling the `create-payment` function or inserting manually).
2. Calculate the valid HMAC signature for your test payload using your `PAYMOB_HMAC_SECRET`. (For sandbox testing, you can use a test secret or temporarily set it to a known test key).
3. Send the `POST` request with the correct query parameter `?hmac=[VALID_HMAC]`.

### 🎯 Step 1 Verification:
* **HTTP Status Code:** `200 OK`
* **Response Body:** `{"success":true,"message":"تم تفعيل المعاملة والترقية بنجاح"}`
* **Supabase check:** Verify that a new row has been created in the `public.ad_boosts` (or `public.user_subscriptions`) table, and the ad's `is_featured` or `is_urgent` flag is set to `true`.

### 🎯 Step 2 Verification (Double-Send):
* Send the exact same request again immediately.
* **HTTP Status Code:** `200 OK`
* **Response Body:** `{"success":true,"message":"تمت معالجة المعاملة مسبقاً"}`
* **Supabase check:** Count the rows in the `public.ad_boosts` table. **The count must remain 1.** No duplicate activation rows should be created.

---

## 🧪 Test 3: RLS Access Bypass Prevention (Client Bypass) / اختبار حماية قاعدة البيانات RLS

**Objective:** Confirm that client applications cannot bypass the payment gateway and activate boosts directly using the client `anon` key.

### 📮 Postman Configuration:
* **Method:** `POST`
* **URL:** `https://[your-supabase-project].supabase.co/rest/v1/ad_boosts`
* **Headers:**
  * `apikey`: `YOUR_SUPABASE_ANON_KEY`
  * `Authorization`: `Bearer YOUR_USER_ACCESS_TOKEN`
  * `Content-Type`: `application/json`
* **JSON Body:**
```json
{
  "ad_id": "[ANY_AD_UUID]",
  "user_id": "[USER_UUID]",
  "boost_type": "featured",
  "expires_at": "2026-07-23T00:00:00Z"
}
```

### 🎯 Expected Result:
* **HTTP Status Code:** `401 Unauthorized` / `403 Forbidden` / Insertion fails with violation constraint.
* **Explanation:** The Row Level Security (RLS) policies on `ad_boosts` restrict client insertion, allowing only the server-side `service_role` (used strictly in Deno webhooks) to insert records.
