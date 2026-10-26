-- ================================================================
-- N12: reviewers could update any column of their own reviews. An
-- unfiltered UPDATE also reached reviews a moderator had hidden (only the
-- UPDATE policy applies when no column is read), so a reviewer could
-- restore a hidden review, move a review onto another seller (bypassing
-- the contact-eligibility check), backdate it or detach it from its ad.
-- Now reviewers may edit only rating and comment, and only while the
-- review is active. Status and the rest are for staff (service role).
-- ================================================================

REVOKE UPDATE ON public.reviews FROM anon, authenticated;
GRANT UPDATE (rating, comment) ON public.reviews TO authenticated;

DROP POLICY IF EXISTS "reviews_update_own" ON public.reviews;
CREATE POLICY "reviews_update_own" ON public.reviews FOR UPDATE TO authenticated
  USING (reviewer_id = auth.uid() AND status = 'active')
  WITH CHECK (reviewer_id = auth.uid() AND status = 'active');
