-- ================================================================
-- Ad search. The app never sent the search text, the unused
-- advanced_search_ads queried a 'simple' tsvector with the 'arabic'
-- config (so stems never matched), and normalize_arabic was never
-- created (syntax error in enhancements_v1).
--   * normalize_arabic(): أ/إ/آ/ٱ -> ا, ة -> ه, ى -> ي, diacritics and
--     tatweel removed, lower-cased.
--   * search_vector is built from normalised title/description.
--   * search_ads(): every word must match as a prefix of a word in the ad
--     (typing "كورو" finds "كورولا"), or the query must be close to the
--     title by trigram similarity (common misspellings); plus the feed
--     filters. A main category includes its subcategories. Featured
--     first, then relevance, then newest.
-- ================================================================

CREATE OR REPLACE FUNCTION public.normalize_arabic(p_text text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = public, pg_temp
AS $$
  SELECT lower(translate(coalesce(p_text, ''),
                         'أإآٱةىًٌٍَُِّْـ',
                         'ااااهي'));
$$;

CREATE OR REPLACE FUNCTION public.update_ad_search_vector()
RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('simple', public.normalize_arabic(NEW.title)), 'A') ||
    setweight(to_tsvector('simple', public.normalize_arabic(NEW.description)), 'B');
  RETURN NEW;
END;
$$;

UPDATE public.ads SET search_vector =
  setweight(to_tsvector('simple', public.normalize_arabic(title)), 'A') ||
  setweight(to_tsvector('simple', public.normalize_arabic(description)), 'B');

CREATE INDEX IF NOT EXISTS idx_ads_title_trgm ON public.ads
  USING gin (public.normalize_arabic(title) public.gin_trgm_ops);

DROP FUNCTION IF EXISTS public.advanced_search_ads(text, integer, integer, numeric, numeric, integer, integer);

CREATE OR REPLACE FUNCTION public.search_ads(
  p_query         text DEFAULT NULL,
  p_category_id   integer DEFAULT NULL,
  p_city_id       integer DEFAULT NULL,
  p_ad_type       public.ad_type_enum DEFAULT NULL,
  p_min_price     numeric DEFAULT NULL,
  p_max_price     numeric DEFAULT NULL,
  p_featured_only boolean DEFAULT false,
  p_limit         integer DEFAULT 20,
  p_offset        integer DEFAULT 0
)
RETURNS SETOF public.ads
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_temp
AS $$
  WITH q AS (
    SELECT public.normalize_arabic(btrim(coalesce(p_query, ''))) AS text
  ), terms AS (
    -- Each word becomes a prefix term; characters with meaning in tsquery are dropped.
    SELECT string_agg(quote_literal(w) || ':*', ' & ') AS tsq
    FROM q, regexp_split_to_table(regexp_replace(q.text, '[''\\:&|!()<>*]', ' ', 'g'), '\s+') AS w
    WHERE w <> ''
  )
  SELECT a.*
  FROM public.ads a, q, terms
  WHERE a.status = 'active' AND a.deleted_at IS NULL
    AND (q.text = ''
         OR a.search_vector @@ to_tsquery('simple', terms.tsq)
         OR public.word_similarity(q.text, public.normalize_arabic(a.title)) >= 0.5)
    AND (p_category_id IS NULL OR a.category_id = p_category_id
         OR a.category_id IN (SELECT c.id FROM public.categories c WHERE c.parent_id = p_category_id))
    AND (p_city_id IS NULL OR a.city_id = p_city_id)
    AND (p_ad_type IS NULL OR a.ad_type = p_ad_type)
    AND (p_min_price IS NULL OR a.price >= p_min_price)
    AND (p_max_price IS NULL OR a.price <= p_max_price)
    AND (NOT p_featured_only OR a.is_featured)
  ORDER BY a.is_featured DESC,
           CASE WHEN q.text = '' THEN 0
                ELSE ts_rank(a.search_vector, to_tsquery('simple', terms.tsq))
                     + public.word_similarity(q.text, public.normalize_arabic(a.title)) END DESC,
           a.created_at DESC
  LIMIT least(greatest(p_limit, 1), 100)
  OFFSET greatest(p_offset, 0);
$$;

REVOKE ALL ON FUNCTION public.search_ads(text, integer, integer, public.ad_type_enum, numeric, numeric, boolean, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_ads(text, integer, integer, public.ad_type_enum, numeric, numeric, boolean, integer, integer)
  TO anon, authenticated, service_role;
