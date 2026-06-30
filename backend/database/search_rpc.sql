-- 🟢 Wasla Enhancements - Part 2: Advanced Search RPC

-- This function performs an advanced search with ranking and normalization.
-- It uses the search_vector created in Part 1.

CREATE OR REPLACE FUNCTION public.advanced_search_ads(
    p_query TEXT,
    p_category_id INT DEFAULT NULL,
    p_city_id INT DEFAULT NULL,
    p_min_price DECIMAL DEFAULT NULL,
    p_max_price DECIMAL DEFAULT NULL,
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    description TEXT,
    price DECIMAL,
    price_type price_type_enum,
    city_name_ar TEXT,
    category_name_ar TEXT,
    primary_image_url TEXT,
    blurhash TEXT,
    rank REAL,
    created_at TIMESTAMPTZ
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.title,
        a.description,
        a.price,
        a.price_type,
        ci.name_ar as city_name_ar,
        ca.name_ar as category_name_ar,
        m.url as primary_image_url,
        m.blurhash,
        ts_rank(a.search_vector, plainto_tsquery('arabic', p_query)) as rank,
        a.created_at
    FROM 
        public.ads a
    LEFT JOIN public.cities ci ON a.city_id = ci.id
    LEFT JOIN public.categories ca ON a.category_id = ca.id
    LEFT JOIN public.ad_media m ON a.id = m.ad_id AND m.is_primary = TRUE
    WHERE 
        (p_query IS NULL OR p_query = '' OR a.search_vector @@ plainto_tsquery('arabic', p_query))
        AND (p_category_id IS NULL OR a.category_id = p_category_id)
        AND (p_city_id IS NULL OR a.city_id = p_city_id)
        AND (p_min_price IS NULL OR a.price >= p_min_price)
        AND (p_max_price IS NULL OR a.price <= p_max_price)
        AND a.status = 'active'
    ORDER BY 
        rank DESC, 
        a.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;
