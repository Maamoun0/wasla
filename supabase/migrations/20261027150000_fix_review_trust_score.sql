-- ================================================================
-- Reviews could not be written: a second trust-score trigger
-- (tr_refresh_trust_on_review -> refresh_user_trust_score) read
-- NEW.user_id, which reviews does not have, so every insert failed.
-- It also applied a different formula from the one the app documents.
-- update_trust_score (trg_trust_score) stays the single source (fixed below):
--   30 if verified + 40 x avg/5 + min(reviews, 20) + min(months, 10).
-- ================================================================

DROP TRIGGER IF EXISTS tr_refresh_trust_on_review ON public.reviews;
DROP FUNCTION IF EXISTS public.refresh_user_trust_score();
DROP FUNCTION IF EXISTS public.calculate_user_trust_score(uuid);

-- On users (BEFORE UPDATE OF is_id_verified) the function read the stored,
-- old is_id_verified, so verification never added its 30 points.
CREATE OR REPLACE FUNCTION public.update_trust_score()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  target_user    uuid;
  v_is_verified  boolean;
  v_created_at   timestamptz;
  v_avg_rating   numeric;
  v_review_count int;
  v_months_old   int;
  v_score        numeric;
BEGIN
  IF TG_TABLE_NAME = 'reviews' THEN
    target_user := COALESCE(NEW.reviewed_user_id, OLD.reviewed_user_id);
    SELECT is_id_verified, created_at INTO v_is_verified, v_created_at FROM public.users WHERE id = target_user;
  ELSE
    target_user := NEW.id;
    IF NEW.is_id_verified IS NOT DISTINCT FROM OLD.is_id_verified THEN
      RETURN NEW;
    END IF;
    v_is_verified := NEW.is_id_verified;
    v_created_at := NEW.created_at;
  END IF;

  SELECT COALESCE(AVG(rating)::numeric, 0), COUNT(*)::int INTO v_avg_rating, v_review_count
  FROM public.reviews WHERE reviewed_user_id = target_user AND status = 'active';

  v_months_old := LEAST(floor(EXTRACT(epoch FROM (now() - v_created_at)) / 2592000)::int, 10);

  v_score := CASE WHEN v_is_verified THEN 30 ELSE 0 END
           + (v_avg_rating / 5.0) * 40.0
           + LEAST(v_review_count, 20)
           + v_months_old;

  IF TG_TABLE_NAME = 'users' THEN
    NEW.trust_score := ROUND(v_score, 2);
    RETURN NEW;
  END IF;

  UPDATE public.users SET trust_score = ROUND(v_score, 2) WHERE id = target_user;
  RETURN NULL;
END;
$$;

-- Eligibility must see every contact / booking, not just the caller's rows,
-- so it no longer depends on who is asking.
ALTER FUNCTION public.validate_review_eligibility() SECURITY DEFINER;
ALTER FUNCTION public.validate_review_eligibility() SET search_path = public, pg_temp;
