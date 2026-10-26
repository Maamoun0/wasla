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

- `request-otp`
- `create-ad`
- `ai-content-review`
- `analyze-ad-image`
- `submit-kyc-request`
- `get-kyc-document`
- `create-payment`
- `payment-webhook`
- `dispatch-notifications`
- `purge-deleted-accounts`

## 3. Secrets

Edge Function secrets (`supabase secrets set ...`):

- `PAYMOB_API_KEY`, `PAYMOB_INTEGRATION_ID`, `PAYMOB_IFRAME_ID`, `PAYMOB_HMAC_SECRET`
- `FIREBASE_SERVICE_ACCOUNT`: the Firebase service-account JSON, used by `dispatch-notifications` for FCM HTTP v1
- `ANTHROPIC_API_KEY`

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided to Edge Functions by the platform.

Vault secrets for the notification dispatcher cron job. Run these in the SQL editor of the new project:

```sql
select vault.create_secret('https://<PROD_REF>.supabase.co', 'project_url');
select vault.create_secret('<service_role key>', 'service_role_key');
```

Until both secrets exist, the `dispatch-notifications` and `purge-deleted-accounts` cron ticks do nothing: notifications stay queued in `notifications_outbox`, and due account deletions stay pending.

## 4. Auth

- Enable TOTP MFA (Authentication → Multi-Factor). It is mandatory for admin-panel staff and enforced server-side at `aal2`.
- Create the first admin with email and password, then set `public.users.user_type = 'admin'` with the service role. That user enrolls TOTP on first login.

## 5. Data retention

When an account is purged 30 days after a deletion request, its payment transactions are kept, anonymised: no `user_id`, no ad reference, and metadata reduced to non-personal gateway fields. Proposed retention is 5 years, to be confirmed by legal counsel. Automatic removal after that period is not implemented yet. See `docs/wasla_security_privacy_plan.md` §6.

## 6. Flutter production config

Build with `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...` for the new project. Use the production `google-services.json` and `GoogleService-Info.plist`.
