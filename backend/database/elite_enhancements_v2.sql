-- 🏆 Wasla Elite Enhancements - Part 1: Trust Score & Market Insights

-- 1. Trust Score 2.0 Calculation Function
CREATE OR REPLACE FUNCTION public.calculate_user_trust_score(p_user_id UUID)
RETURNS DECIMAL AS $$
DECLARE
    v_score DECIMAL := 0;
    v_kyc_bonus INT := 0;
    v_review_avg DECIMAL := 0;
    v_review_count INT := 0;
    v_ad_count INT := 0;
    v_social_count INT := 0;
BEGIN
    -- A. KYC Bonus (20 points)
    SELECT CASE WHEN is_id_verified THEN 20 ELSE 0 END INTO v_kyc_bonus
    FROM public.users WHERE id = p_user_id;
    v_score := v_score + v_kyc_bonus;

    -- B. Reviews Impact (Max 50 points)
    SELECT COALESCE(AVG(rating), 0), COUNT(*) INTO v_review_avg, v_review_count
    FROM public.reviews WHERE reviewed_user_id = p_user_id AND status = 'active';
    
    -- Formula: (Avg Rating / 5) * 50, but weighted by count (need at least 3 reviews for full weight)
    IF v_review_count > 0 THEN
        v_score := v_score + (v_review_avg / 5.0) * LEAST(v_review_count * 10, 50);
    END IF;

    -- C. Social/Activity Impact (Max 30 points)
    SELECT COUNT(*) INTO v_social_count FROM public.user_auth_providers WHERE user_id = p_user_id;
    v_score := v_score + LEAST(v_social_count * 10, 20);
    
    SELECT COUNT(*) INTO v_ad_count FROM public.ads WHERE user_id = p_user_id AND status = 'active';
    v_score := v_score + LEAST(v_ad_count * 2, 10);

    RETURN LEAST(v_score, 100);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update trust_score in users table automatically
CREATE OR REPLACE FUNCTION public.refresh_user_trust_score()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.users 
    SET trust_score = public.calculate_user_trust_score(
        CASE 
            WHEN TG_TABLE_NAME = 'reviews' THEN NEW.reviewed_user_id
            WHEN TG_TABLE_NAME = 'user_verifications' THEN NEW.user_id
            ELSE NEW.user_id
        END
    )
    WHERE id = (CASE 
                    WHEN TG_TABLE_NAME = 'reviews' THEN NEW.reviewed_user_id 
                    ELSE NEW.user_id 
                END);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
DROP TRIGGER IF EXISTS tr_refresh_trust_on_review ON public.reviews;
CREATE TRIGGER tr_refresh_trust_on_review
AFTER INSERT OR UPDATE ON public.reviews
FOR EACH ROW EXECUTE FUNCTION public.refresh_user_trust_score();

-- 2. Market Price Insights Function
CREATE OR REPLACE FUNCTION public.get_market_price_stats(
    p_category_id INT,
    p_city_id INT DEFAULT NULL
)
RETURNS TABLE (
    avg_price DECIMAL,
    min_price DECIMAL,
    max_price DECIMAL,
    ad_count INT,
    price_label TEXT -- 'fair', 'low', 'high' helper
) AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT 
            AVG(price)::DECIMAL as avg_p,
            MIN(price)::DECIMAL as min_p,
            MAX(price)::DECIMAL as max_p,
            COUNT(*)::INT as cnt
        FROM public.ads
        WHERE category_id = p_category_id
          AND (p_city_id IS NULL OR city_id = p_city_id)
          AND status = 'active'
          AND price > 0
    )
    SELECT 
        avg_p,
        min_p,
        max_p,
        cnt,
        'Based on ' || cnt || ' similar items in your area'
    FROM stats;
END;
$$ LANGUAGE plpgsql STABLE;
