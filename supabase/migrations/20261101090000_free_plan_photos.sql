-- Decision (2026-11-01): the free plan allows 8 photos per ad, as FR-3.1
-- states ("حتى 8 صور"); premium (12) and business (20) are unchanged.
UPDATE public.subscription_plans SET max_images_per_ad = 8 WHERE name = 'free';
