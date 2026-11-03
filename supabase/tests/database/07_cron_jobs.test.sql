-- Every scheduled job must run without error (pg_cron only logs failures,
-- so a broken job fails silently every time it fires).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(15);

INSERT INTO auth.users (id, email, phone, raw_user_meta_data, aud, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'a@test.local', '+201000000001', '{}', 'authenticated', 'authenticated');

INSERT INTO public.transactions (id, user_id, type, amount, payment_method, payment_gateway, status, created_at) VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'ad_boost', 60, 'card', 'paymob', 'pending', now() - interval '3 hours'),
  ('bbbbbbbb-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'ad_boost', 60, 'card', 'paymob', 'pending', now() - interval '10 minutes'),
  ('bbbbbbbb-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'ad_boost', 60, 'card', 'paymob', 'completed', now() - interval '3 hours');

SELECT is((SELECT count(*)::int FROM cron.job), 11, 'eleven scheduled jobs');
SELECT lives_ok((SELECT command FROM cron.job WHERE jobname = 'recompute-trust-scores'), 'recompute-trust-scores runs');
SELECT lives_ok((SELECT command FROM cron.job WHERE jobname = 'cleanup-ad-views'), 'cleanup-ad-views runs');

SELECT lives_ok((SELECT command FROM cron.job WHERE jobname = 'expire-ads'), 'expire-ads runs');
SELECT lives_ok((SELECT command FROM cron.job WHERE jobname = 'expire-boosts'), 'expire-boosts runs');
SELECT lives_ok((SELECT command FROM cron.job WHERE jobname = 'expire-urgent'), 'expire-urgent runs');
SELECT lives_ok((SELECT command FROM cron.job WHERE jobname = 'expire-otps'), 'expire-otps runs');
SELECT lives_ok((SELECT command FROM cron.job WHERE jobname = 'cleanup-sessions'), 'cleanup-sessions runs');
SELECT lives_ok((SELECT command FROM cron.job WHERE jobname = 'dispatch-notifications'), 'dispatch-notifications tick runs');
SELECT lives_ok((SELECT command FROM cron.job WHERE jobname = 'cleanup-stale-transactions'), 'cleanup-stale-transactions runs');
SELECT lives_ok((SELECT command FROM cron.job WHERE jobname = 'purge-deleted-accounts'), 'purge-deleted-accounts tick runs');
SELECT lives_ok((SELECT command FROM cron.job WHERE jobname = 'purge-kyc-documents'), 'purge-kyc-documents tick runs');

SELECT is((SELECT status::text FROM public.transactions WHERE id = 'bbbbbbbb-0000-0000-0000-000000000001'), 'failed',
  'a pending payment older than 2 hours is closed as failed');
SELECT is((SELECT metadata ->> 'failure_reason' FROM public.transactions WHERE id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'expired_unpaid', 'and records why');
SELECT is((SELECT array_agg(status::text ORDER BY id) FROM public.transactions WHERE id IN
            ('bbbbbbbb-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000003')),
  ARRAY['pending', 'completed'], 'recent pending and finished payments are untouched');

SELECT * FROM finish();
ROLLBACK;
