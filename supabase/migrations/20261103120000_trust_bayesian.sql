-- Trust score with a Bayesian average of ratings (docs/ALGORITHMS.md §2).
-- On the seed data one 5-star review (41) outscored six reviews averaging 4
-- (38): the plain average gives the first review its full 40 points.
--
--   R     = (C·m + Σ ratings) / (C + n), and 0 while there are no reviews
--   trust = 30·[ID verified] + 40·R/5 + min(n, 20) + min(account age in months, 10)
--
-- The prior (both in app_configs):
--   m = trust_prior_mean   = 3.5  slightly below the seed's mean rating (3.74):
--       an unknown seller is assumed a little below average until reviews
--       show otherwise.
--   C = trust_prior_weight = 5    reviews' worth of prior. Above the median
--       reviews per seller (3), so most sellers' own average counts for half
--       or less until they have five reviews. Weight 0 is the plain average.

INSERT INTO public.app_configs (key, value, description) VALUES
  ('trust_prior_mean', '3.5', 'Trust score: prior mean rating (m) of the Bayesian average'),
  ('trust_prior_weight', '5', 'Trust score: prior weight (C, in reviews) of the Bayesian average; 0 = plain average')
ON CONFLICT (key) DO NOTHING;

-- The score for one user, from current data and settings.
CREATE OR REPLACE FUNCTION public.compute_trust_score(p_user_id uuid)
RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  WITH u AS (
    SELECT is_id_verified, created_at FROM public.users WHERE id = p_user_id
  ), r AS (
    SELECT coalesce(sum(rating), 0)::numeric AS total, count(*)::int AS n
    FROM public.reviews WHERE reviewed_user_id = p_user_id AND status = 'active'
  ), p AS (
    SELECT least(greatest(public.config_numeric('trust_prior_mean', 3.5), 1), 5) AS m,
           greatest(public.config_numeric('trust_prior_weight', 5), 0) AS c
  )
  SELECT round(least(
           CASE WHEN u.is_id_verified THEN 30 ELSE 0 END
           -- No reviews, no rating points (the prior alone would hand every new
           -- account 28 points and let it past min_trust_score_to_post).
           + 40 * (CASE WHEN r.n = 0 THEN 0 ELSE (p.c * p.m + r.total) / (p.c + r.n) END) / 5
           + least(r.n, 20)
           + least(floor(extract(epoch FROM now() - u.created_at) / 2592000)::int, 10),
         100), 2)
  FROM u, r, p;
$$;

CREATE OR REPLACE FUNCTION public.update_trust_score()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  target_user uuid;
BEGIN
  IF TG_TABLE_NAME = 'reviews' THEN
    target_user := COALESCE(NEW.reviewed_user_id, OLD.reviewed_user_id);
    UPDATE public.users SET trust_score = public.compute_trust_score(target_user) WHERE id = target_user;
    RETURN NULL;
  END IF;

  -- users: only when ID verification changes. NEW is not written yet, so
  -- score it with the new flag.
  IF NEW.is_id_verified IS NOT DISTINCT FROM OLD.is_id_verified THEN
    RETURN NEW;
  END IF;
  NEW.trust_score := public.compute_trust_score(NEW.id)
                     + CASE WHEN NEW.is_id_verified THEN 30 ELSE -30 END;
  NEW.trust_score := least(greatest(NEW.trust_score, 0), 100);
  RETURN NEW;
END;
$$;

-- Recompute one user (after a settings change, or by the daily job).
CREATE OR REPLACE FUNCTION public.recompute_trust_score(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v numeric := public.compute_trust_score(p_user_id);
BEGIN
  UPDATE public.users SET trust_score = v WHERE id = p_user_id;
  RETURN v;
END;
$$;

REVOKE ALL ON FUNCTION public.compute_trust_score(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.recompute_trust_score(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.compute_trust_score(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.recompute_trust_score(uuid) TO service_role;

-- Account age keeps growing without new reviews: refresh everyone daily.
SELECT cron.schedule('recompute-trust-scores', '20 4 * * *',
  $$ UPDATE public.users SET trust_score = public.compute_trust_score(id) WHERE deleted_at IS NULL $$);

-- Existing scores under the new formula.
UPDATE public.users SET trust_score = public.compute_trust_score(id) WHERE deleted_at IS NULL;
