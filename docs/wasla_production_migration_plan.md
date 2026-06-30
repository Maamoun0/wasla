# Wasla Production Migration Plan

This document outlines the steps for migrating Wasla from Staging to Production for Sprint 10.

## 1. Database Schema Execution Order
Execute the following scripts in order on the Production Supabase instance:
1. `backend/database/wasla-schema.sql` (Core tables & initial seed)
2. `backend/database/wasla-phase0-schema-additions.sql`
3. `backend/database/sprint8_setup.sql` (Activity logging)
4. `backend/database/sprint9_notifications.sql` (Push notification infra)
5. `backend/database/sprint10_security_legal.sql` (Security hardening & legal table)

## 2. Edge Functions Deployment
Deploy the following functions using `supabase functions deploy [name] --project-ref [PROD_REF]`:
- `request-otp`
- `ai-content-review`
- `create-ad`
- `submit-kyc-request`
- `create-payment`
- `payment-webhook`
- `notify-watchlist-match`
- `notify-ad-status`

## 3. Production Secrets (Supabase Vault)
The following secrets must be set in the Production project:
- `SUPABASE_URL` & `SUPABASE_SERVICE_ROLE_KEY`
- `PAYMOB_API_KEY`, `PAYMOB_IFRAME_ID`, `PAYMOB_HMAC_SECRET`
- `FIREBASE_SERVICE_ACCOUNT` (JSON for FCM)
- `POSTHOG_API_KEY`
- `SENTRY_DSN`

## 4. Flutter Production Config
1. Create branch `feature/production-config`.
2. Update `.env` with Production Supabase URL and Anon Key.
3. Verify that `google-services.json` and `GoogleService-Info.plist` correspond to the Production Firebase project.
