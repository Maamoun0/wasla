-- N14: the national ID is no longer stored. submit-kyc-request keeps only the
-- last 4 digits (shown to moderators next to the card images) and
-- HMAC-SHA256(normalized ID, KYC_NATIONAL_ID_HMAC_SECRET), which detects the
-- same ID on another account. A plain hash would not do: a 14-digit ID with a
-- known structure (century, birth date, governorate) is cheap to brute-force.
-- The secret exists only in the Edge Function secrets, never in the database
-- or the repository. Rotating it breaks duplicate detection against requests
-- hashed with the old secret (see docs/wasla_security_privacy_plan.md §4).
--
-- No real data exists yet, so the plaintext column is dropped outright.

ALTER TABLE public.user_verifications DROP COLUMN IF EXISTS national_id;

ALTER TABLE public.user_verifications
  ADD COLUMN national_id_last4 text
    CONSTRAINT user_verifications_national_id_last4_format CHECK (national_id_last4 ~ '^[0-9]{4}$'),
  ADD COLUMN national_id_hmac text
    CONSTRAINT user_verifications_national_id_hmac_format CHECK (national_id_hmac ~ '^[0-9a-f]{64}$'),
  ADD CONSTRAINT user_verifications_national_id_pair
    CHECK ((national_id_last4 IS NULL) = (national_id_hmac IS NULL));

-- One live claim per ID: a pending or approved request blocks the same ID on
-- any other account. Rejected and expired requests do not, so the user can
-- resubmit after a rejection, and a request rejected as someone else's card
-- does not lock the real owner out.
CREATE UNIQUE INDEX user_verifications_national_id_hmac_live
  ON public.user_verifications (national_id_hmac)
  WHERE status IN ('pending', 'approved') AND national_id_hmac IS NOT NULL;

-- Clients read their own requests (status screen) but never the HMAC or the
-- OTP code hash: column-level SELECT instead of the table-wide grant.
REVOKE SELECT ON public.user_verifications FROM anon, authenticated;
GRANT SELECT (id, user_id, type, status, document_url, document_back_url, selfie_url, attempts,
              expires_at, verified_at, created_at, decided_at, documents_deleted_at, national_id_last4)
  ON public.user_verifications TO authenticated;
