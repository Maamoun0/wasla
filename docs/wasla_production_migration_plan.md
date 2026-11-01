# Wasla Production Migration Plan

Production will be a **new** Supabase project created at launch. The two existing projects are for development only.

## 1. Database

The schema lives only in `supabase/migrations/` (starting with `0000_baseline.sql`), including reference data (governorates, cities, districts, categories and their dynamic fields, subscription plans, payment packages, app configs).

> ⚠️ Never run the legacy scripts in `backend/database/` or `database/` against any live project. `wasla-schema.sql` starts with `DROP SCHEMA public CASCADE`.

Verify locally first:

```bash
npx supabase@2.120.0 start
npx supabase@2.120.0 db reset
npx supabase@2.120.0 test db
```

Then link and push to the new project:

```bash
npx supabase@2.120.0 link --project-ref <PROD_REF>
npx supabase@2.120.0 db push
```

## 2. Edge Functions

Deploy with `supabase functions deploy <name> --project-ref <PROD_REF>`:

- `create-ad`
- `submit-kyc-request`
- `create-payment`
- `payment-webhook`
- `dispatch-notifications`
- `purge-deleted-accounts`
- `purge-kyc-documents`
- `send-sms-hook` (with `--no-verify-jwt`; see §4)
- `health` (with `--no-verify-jwt`): point an uptime monitor at `https://<PROD_REF>.supabase.co/functions/v1/health` (200 = database and Storage answer, 503 otherwise).

## 3. Secrets

Edge Function secrets (`supabase secrets set ...`):

- `PAYMOB_API_KEY`, `PAYMOB_INTEGRATION_ID`, `PAYMOB_IFRAME_ID`, `PAYMOB_HMAC_SECRET`
- `FIREBASE_SERVICE_ACCOUNT`: the Firebase service-account JSON, used by `dispatch-notifications` for FCM HTTP v1
- `ANTHROPIC_API_KEY`, `MODERATION_MODEL_FAST`, `MODERATION_MODEL_DEEP` (AI ad review inside `create-ad`; see `supabase/functions/.env.example`)
- `KYC_NATIONAL_ID_HMAC_SECRET`: at least 32 random characters (`openssl rand -hex 32`). `submit-kyc-request` refuses every request without it. Generate it once for production and never reuse the dev value. **Do not rotate it casually:** requests hashed with the old secret no longer match new ones, so the same national ID could then be verified on a second account. If it must change (leak), run the rotation as a planned job and accept that duplicate detection covers only requests made after the change.

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided to Edge Functions by the platform.

Vault secrets for the notification dispatcher cron job. Run these in the SQL editor of the new project:

```sql
select vault.create_secret('https://<PROD_REF>.supabase.co', 'project_url');
select vault.create_secret('<service_role key>', 'service_role_key');
```

Until both secrets exist, the `dispatch-notifications`, `purge-deleted-accounts` and `purge-kyc-documents` cron ticks do nothing: notifications stay queued in `notifications_outbox`, due account deletions stay pending, and identity documents are not deleted on schedule.

## 3.1 Storage image transformation

The app loads photos through `/storage/v1/render/image` (resized, compressed, WebP when supported: NFR-1.2). On hosted Supabase this is **Image Transformations, a Pro-plan feature billed per origin image**; enable it on the production project. Without it the render URLs fail and photos do not load.

**Decision (2026-11-01): the Pro plan is approved** for the production project, for Image Transformations.

## 4. Auth

- Enable TOTP MFA (Authentication → Multi-Factor). It is mandatory for admin-panel staff and enforced server-side at `aal2`.
- **Phone OTP limits** (Authentication → Rate Limits and Authentication → Providers → Phone). These are the only server-side OTP controls; the app's countdown just mirrors them. Use the same values as `supabase/config.toml`:
  - one SMS per number every 60 s (`max_frequency`);
  - code length 6, expiry 300 s;
  - SMS sent per hour for the project: 30 to start, raised with real traffic, since it caps SMS-pumping cost;
  - sign-in/sign-up requests per 5 minutes per IP: 30;
  - token verifications per 5 minutes per IP: 30.

  Enabling CAPTCHA protection (hCaptcha or Turnstile) for phone sign-in is recommended before launch.
- **SMS delivery goes through the Send SMS Hook**, not a built-in provider:
  - Deploy `send-sms-hook` with `--no-verify-jwt`.
  - In Authentication → Hooks → Send SMS, choose HTTPS with `https://<PROD_REF>.supabase.co/functions/v1/send-sms-hook`, generate the secret, and set it as the `SEND_SMS_HOOK_SECRETS` function secret.
  - Set `SMS_PROVIDER` and that provider's credentials. Twilio is only the test provider; the production provider is a new file in `send-sms-hook/providers/`.
  - The Phone provider must stay enabled (Authentication → Providers → Phone). With the hook on, Auth does not use the built-in provider.
  - The limits above still apply: Auth checks them before calling the hook.
  - If the hook or the provider fails, Auth returns an error and no code is stored or logged.
- Never configure `test_otp` numbers or placeholder SMS credentials on a hosted project; those in `config.toml` are for local development only.
- Create the first admin with email and password, then set `public.users.user_type = 'admin'` with the service role. That user enrolls TOTP on first login.

## 5. Data retention

When an account is purged 30 days after a deletion request, its payment transactions are kept, anonymised: no `user_id`, no ad reference, and metadata reduced to non-personal gateway fields. Proposed retention is 5 years, to be confirmed by legal counsel. Automatic removal after that period is not implemented yet. See `docs/wasla_security_privacy_plan.md` §6.

## 6. Flutter production config

Build with `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...` for the new project. Use the production `google-services.json` and `GoogleService-Info.plist`.

## 7. Crash reporting (Sentry)

Off until a DSN is set, in each of the three places:

| Where | Setting |
|---|---|
| Flutter app | `--dart-define=SENTRY_DSN=...` (optional `SENTRY_ENVIRONMENT`) |
| Admin panel | `SENTRY_DSN` (server) and `NEXT_PUBLIC_SENTRY_DSN` (browser), optional `NEXT_PUBLIC_SENTRY_ENVIRONMENT` |
| Edge Functions | `supabase secrets set SENTRY_DSN=...` (optional `SENTRY_ENVIRONMENT`) |

All three send no default PII, and strip phone numbers, emails and tokens before sending (`beforeSend`). Choose the Sentry data region and retention before launch; both are listed as open in `docs/legal/DATA_INVENTORY.md`. Product analytics (PostHog) is deferred.
