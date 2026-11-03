-- Review rings (docs/ALGORITHMS.md §2, §9). On the seed data five sellers were
-- each praised by ten accounts two days old with no ads, whose only contact
-- came hours before the review; one of them ranked first in trust.
--
-- Every review gets suspicion reasons, each worth points (app_configs):
--   mutual        2  the reviewed user also reviewed the reviewer
--   cluster       2  ≥ review_cluster_min reviewers of this seller, all new when
--                    they reviewed, joined within review_cluster_window_hours of each other
--   new_account   1  the reviewer joined < review_new_account_days before the review
--   no_activity   1  the reviewer has no ads and no contacts except to this seller
--   thin_contact  1  no contact with this seller ≥ review_min_contact_hours
--                    before the review (the eligibility check only needs one
--                    within 30 days)
-- At review_suspicion_threshold points (default 2) the review is flagged:
-- its weight drops to review_suspicious_weight (0.2) in the trust score, and
-- it appears in suspicious_reviews() for the admin panel. Nothing is hidden
-- automatically: a person decides.

INSERT INTO public.app_configs (key, value, description) VALUES
  ('review_suspicion_threshold', '2', 'Reviews: suspicion points at which a review is flagged and down-weighted'),
  ('review_suspicious_weight', '0.2', 'Reviews: weight of a flagged review in the trust score (0..1)'),
  ('review_new_account_days', '7', 'Reviews: a reviewer younger than this many days counts as new'),
  ('review_cluster_window_hours', '24', 'Reviews: reviewers of one seller who joined within this window form a cluster'),
  ('review_cluster_min', '3', 'Reviews: reviewers needed in that window to count as a cluster'),
  ('review_min_contact_hours', '12', 'Reviews: a contact must precede the review by this many hours to count as real')
ON CONFLICT (key) DO NOTHING;

ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS weight numeric(3,2) NOT NULL DEFAULT 1 CHECK (weight >= 0 AND weight <= 1),
  ADD COLUMN IF NOT EXISTS suspicion_reasons text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS flagged_at timestamptz;
-- Clients never set these (reviews' column grants list writable columns).
REVOKE INSERT (weight, suspicion_reasons, flagged_at), UPDATE (weight, suspicion_reasons, flagged_at)
  ON public.reviews FROM anon, authenticated;

CREATE INDEX IF NOT EXISTS reviews_flagged_idx ON public.reviews (flagged_at) WHERE flagged_at IS NOT NULL;

-- Reasons for one review, from current data.
CREATE OR REPLACE FUNCTION public.review_suspicion_reasons(p_review_id uuid)
RETURNS text[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  WITH r AS (
    SELECT rv.*, u.created_at AS reviewer_joined
    FROM public.reviews rv JOIN public.users u ON u.id = rv.reviewer_id
    WHERE rv.id = p_review_id
  ), cfg AS (
    SELECT public.config_numeric('review_new_account_days', 7) AS new_days,
           public.config_numeric('review_cluster_window_hours', 24) AS window_h,
           public.config_numeric('review_cluster_min', 3) AS cluster_min,
           public.config_numeric('review_min_contact_hours', 12) AS contact_h
  )
  SELECT array_remove(ARRAY[
    CASE WHEN EXISTS (SELECT 1 FROM public.reviews o
                      WHERE o.reviewer_id = r.reviewed_user_id AND o.reviewed_user_id = r.reviewer_id)
         THEN 'mutual' END,
    -- Only new reviewers form a cluster: accounts made together long ago are not a ring.
    CASE WHEN r.created_at - r.reviewer_joined < make_interval(days => cfg.new_days::int)
          AND (SELECT count(DISTINCT o.reviewer_id) FROM public.reviews o JOIN public.users ou ON ou.id = o.reviewer_id
               WHERE o.reviewed_user_id = r.reviewed_user_id
                 AND o.created_at - ou.created_at < make_interval(days => cfg.new_days::int)
                 AND abs(extract(epoch FROM ou.created_at - r.reviewer_joined)) <= cfg.window_h * 3600) >= cfg.cluster_min
         THEN 'cluster' END,
    CASE WHEN r.created_at - r.reviewer_joined < make_interval(days => cfg.new_days::int)
         THEN 'new_account' END,
    CASE WHEN NOT EXISTS (SELECT 1 FROM public.ads a WHERE a.user_id = r.reviewer_id)
          AND NOT EXISTS (SELECT 1 FROM public.contact_logs c JOIN public.ads a ON a.id = c.ad_id
                          WHERE c.user_id = r.reviewer_id AND a.user_id <> r.reviewed_user_id)
         THEN 'no_activity' END,
    CASE WHEN NOT EXISTS (SELECT 1 FROM public.contact_logs c JOIN public.ads a ON a.id = c.ad_id
                          WHERE c.user_id = r.reviewer_id AND a.user_id = r.reviewed_user_id
                            AND c.created_at <= r.created_at - make_interval(hours => cfg.contact_h::int))
         THEN 'thin_contact' END
  ], NULL)
  FROM r, cfg;
$$;

CREATE OR REPLACE FUNCTION public.review_suspicion_points(p_reasons text[])
RETURNS int LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(sum(CASE x WHEN 'mutual' THEN 2 WHEN 'cluster' THEN 2 ELSE 1 END), 0)::int FROM unnest(p_reasons) x;
$$;

-- Rescore every review of a seller (a new review can complete a cluster, so
-- earlier ones change too), and the reviews they wrote (mutual pairs).
CREATE OR REPLACE FUNCTION public.rescore_seller_reviews(p_seller_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_threshold int := public.config_numeric('review_suspicion_threshold', 2);
  v_weight numeric := least(greatest(public.config_numeric('review_suspicious_weight', 0.2), 0), 1);
  rec record;
  v_reasons text[];
  v_flag boolean;
BEGIN
  FOR rec IN SELECT id, flagged_at FROM public.reviews
             WHERE reviewed_user_id = p_seller_id OR reviewer_id = p_seller_id LOOP
    v_reasons := public.review_suspicion_reasons(rec.id);
    v_flag := public.review_suspicion_points(v_reasons) >= v_threshold;
    UPDATE public.reviews SET
      suspicion_reasons = v_reasons,
      weight = CASE WHEN v_flag THEN v_weight ELSE 1 END,
      flagged_at = CASE WHEN v_flag THEN coalesce(rec.flagged_at, now()) END
    WHERE id = rec.id
      AND (suspicion_reasons IS DISTINCT FROM v_reasons
           OR weight IS DISTINCT FROM (CASE WHEN v_flag THEN v_weight ELSE 1 END)
           OR (flagged_at IS NULL) = v_flag);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.reviews_rescore_after_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM public.rescore_seller_reviews(NEW.reviewed_user_id);
  RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trg_reviews_rescore ON public.reviews;
CREATE TRIGGER trg_reviews_rescore AFTER INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.reviews_rescore_after_insert();

-- Trust uses the weights: R = (C·m + Σ w·rating) / (C + Σ w), count term min(Σ w, 20).
CREATE OR REPLACE FUNCTION public.compute_trust_score(p_user_id uuid)
RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  WITH u AS (
    SELECT is_id_verified, created_at FROM public.users WHERE id = p_user_id
  ), r AS (
    SELECT coalesce(sum(weight * rating), 0)::numeric AS total, coalesce(sum(weight), 0)::numeric AS n, count(*) AS raw_n
    FROM public.reviews WHERE reviewed_user_id = p_user_id AND status = 'active'
  ), p AS (
    SELECT least(greatest(public.config_numeric('trust_prior_mean', 3.5), 1), 5) AS m,
           greatest(public.config_numeric('trust_prior_weight', 5), 0) AS c
  )
  SELECT round(least(
           CASE WHEN u.is_id_verified THEN 30 ELSE 0 END
           -- No reviews, no rating points (the prior alone would hand every new
           -- account 28 points and let it past min_trust_score_to_post).
           + 40 * (CASE WHEN r.raw_n = 0 OR p.c + r.n = 0 THEN 0 ELSE (p.c * p.m + r.total) / (p.c + r.n) END) / 5
           + least(r.n, 20)
           + least(floor(extract(epoch FROM now() - u.created_at) / 2592000)::int, 10),
         100), 2)
  FROM u, r, p;
$$;

-- The admin panel's queue (service role only, like the other moderation functions).
CREATE OR REPLACE FUNCTION public.suspicious_reviews()
RETURNS TABLE (review_id uuid, flagged_at timestamptz, reasons text[], weight numeric, rating smallint, comment text,
               reviewer_id uuid, reviewer_name text, reviewer_joined timestamptz,
               seller_id uuid, seller_name text, seller_trust numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT r.id, r.flagged_at, r.suspicion_reasons, r.weight, r.rating, r.comment,
         rv.id, rv.full_name, rv.created_at, s.id, s.full_name, s.trust_score
  FROM public.reviews r
  JOIN public.users rv ON rv.id = r.reviewer_id
  JOIN public.users s ON s.id = r.reviewed_user_id
  WHERE r.flagged_at IS NOT NULL AND r.status = 'active'
  ORDER BY r.flagged_at DESC;
$$;

REVOKE ALL ON FUNCTION public.review_suspicion_reasons(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rescore_seller_reviews(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.suspicious_reviews() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reviews_rescore_after_insert() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.review_suspicion_reasons(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.rescore_seller_reviews(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.suspicious_reviews() TO service_role;

-- Existing reviews, then everyone's trust.
SELECT public.rescore_seller_reviews(id) FROM public.users WHERE id IN (SELECT reviewed_user_id FROM public.reviews);
UPDATE public.users SET trust_score = public.compute_trust_score(id) WHERE deleted_at IS NULL;
