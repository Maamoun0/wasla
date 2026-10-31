-- 🟡11 (FR-2.2): search understands synonyms.
--  * search_synonyms: groups of interchangeable words or phrases (stored
--    Arabic-normalised). A search word matches any member of its group, as
--    a prefix; a phrase ("لاب توب") must appear in order.
--  * search_ads and saved-search alerts use the same expansion, so an
--    alert matches what the search shows.
--  * The seed below is a starter list of common marketplace terms; it is
--    data, extended with plain INSERTs (no code change).

CREATE TABLE IF NOT EXISTS public.search_synonyms (
  group_id integer NOT NULL,
  term     text    NOT NULL CHECK (btrim(term) <> ''),
  CONSTRAINT search_synonyms_term_key UNIQUE (term)
);
ALTER TABLE public.search_synonyms ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.search_synonyms FROM anon, authenticated;

-- Terms are stored normalised so lookups match how ads are indexed.
CREATE OR REPLACE FUNCTION public.normalize_synonym_term()
RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.term := public.place_name_key(NEW.term);
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_normalize_synonym_term
  BEFORE INSERT OR UPDATE OF term ON public.search_synonyms
  FOR EACH ROW EXECUTE FUNCTION public.normalize_synonym_term();

INSERT INTO public.search_synonyms (group_id, term) VALUES
  (1, 'سيارة'),
  (1, 'سياره'),
  (1, 'عربية'),
  (1, 'عربيه'),
  (1, 'عربة'),
  (2, 'موبايل'),
  (2, 'موبيل'),
  (2, 'جوال'),
  (2, 'تليفون'),
  (2, 'هاتف'),
  (2, 'محمول'),
  (3, 'لابتوب'),
  (3, 'لاب توب'),
  (3, 'لاب'),
  (3, 'نوت بوك'),
  (4, 'شقة'),
  (4, 'شقه'),
  (5, 'ثلاجة'),
  (5, 'تلاجة'),
  (5, 'تلاجه'),
  (5, 'ثلاجه'),
  (6, 'غسالة'),
  (6, 'غساله'),
  (7, 'تكييف'),
  (7, 'تكيف'),
  (7, 'مكيف'),
  (8, 'تلفزيون'),
  (8, 'تليفزيون'),
  (8, 'تلفاز'),
  (8, 'شاشة'),
  (9, 'موتوسيكل'),
  (9, 'موتسيكل'),
  (9, 'دراجة نارية'),
  (9, 'مكنة'),
  (10, 'عجلة'),
  (10, 'دراجة'),
  (10, 'بسكلتة'),
  (11, 'كنبة'),
  (11, 'كنبه'),
  (11, 'أريكة'),
  (12, 'سباك'),
  (12, 'سباكة'),
  (13, 'كهربائي'),
  (13, 'كهربائى'),
  (13, 'كهربا'),
  (14, 'نقاش'),
  (14, 'دهان'),
  (14, 'محارة'),
  (15, 'نجار'),
  (15, 'نجارة')
ON CONFLICT (term) DO NOTHING;

-- tsquery text for one already-normalised word: the word and every synonym
-- in its group, each as a prefix (phrases joined with <->).
CREATE OR REPLACE FUNCTION public.search_word_alternatives(p_word text)
RETURNS text
LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT '(' || string_agg(DISTINCT alt, ' | ') || ')'
  FROM (
    SELECT quote_literal(p_word) || ':*' AS alt
    UNION ALL
    SELECT (SELECT string_agg(quote_literal(part) || ':*', ' <-> ')
            FROM regexp_split_to_table(s.term, '\s+') AS part WHERE part <> '')
    FROM public.search_synonyms s
    WHERE s.group_id IN (SELECT group_id FROM public.search_synonyms WHERE term = p_word)
  ) alts
  WHERE alt IS NOT NULL;
$$;

-- tsquery text for a normalised query: every word (or a synonym) must match.
CREATE OR REPLACE FUNCTION public.search_tsquery_text(p_text text)
RETURNS text
LANGUAGE sql STABLE PARALLEL SAFE SET search_path = public, pg_temp
AS $$
  SELECT string_agg(public.search_word_alternatives(w), ' & ')
  FROM regexp_split_to_table(regexp_replace(coalesce(p_text, ''), '[''\\:&|!()<>*]', ' ', 'g'), '\s+') AS w
  WHERE w <> '';
$$;

CREATE OR REPLACE FUNCTION public.search_ads(
  p_query         text DEFAULT NULL,
  p_category_id   integer DEFAULT NULL,
  p_city_id       integer DEFAULT NULL,
  p_ad_type       public.ad_type_enum DEFAULT NULL,
  p_min_price     numeric DEFAULT NULL,
  p_max_price     numeric DEFAULT NULL,
  p_featured_only boolean DEFAULT false,
  p_district_id   integer DEFAULT NULL,
  p_posted_within_days integer DEFAULT NULL,
  p_near_lat      numeric DEFAULT NULL,
  p_near_lng      numeric DEFAULT NULL,
  p_radius_km     numeric DEFAULT NULL,
  p_limit         integer DEFAULT 20,
  p_offset        integer DEFAULT 0
)
RETURNS SETOF public.ads
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_temp
AS $$
  WITH q AS (
    SELECT public.normalize_arabic(btrim(coalesce(p_query, ''))) AS text
  ), here AS (
    -- The caller's position (used for this query only, never stored).
    SELECT CASE WHEN p_near_lat BETWEEN -90 AND 90 AND p_near_lng BETWEEN -180 AND 180
                THEN ST_SetSRID(ST_MakePoint(p_near_lng, p_near_lat), 4326)::geography END AS point
  ), terms AS (
    -- Every word must match, as a prefix, or as one of its synonyms.
    SELECT public.search_tsquery_text(q.text) AS tsq FROM q
  )
  SELECT a.*
  FROM public.ads a
  CROSS JOIN q CROSS JOIN terms CROSS JOIN here
  -- An ad without its own coordinates is placed at its city's centre.
  LEFT JOIN public.cities c ON c.id = a.city_id
  CROSS JOIN LATERAL (
    SELECT coalesce(a.location_point,
                    CASE WHEN c.latitude IS NOT NULL AND c.longitude IS NOT NULL
                         THEN ST_SetSRID(ST_MakePoint(c.longitude, c.latitude), 4326)::geography END) AS point
  ) ad_loc
  WHERE a.status = 'active' AND a.deleted_at IS NULL AND NOT coalesce(a.is_hidden, false)
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
    AND (p_district_id IS NULL OR a.district_id = p_district_id)
    AND (here.point IS NULL OR p_radius_km IS NULL
         OR ST_DWithin(ad_loc.point, here.point, least(greatest(p_radius_km, 1), 500) * 1000))
    -- Posting date = publication (approval) time; 1..365 days.
    AND (p_posted_within_days IS NULL
         OR coalesce(a.published_at, a.created_at) >= now() - make_interval(days => least(greatest(p_posted_within_days, 1), 365)))
  ORDER BY a.is_featured DESC,
           -- "Near me": closest first (ads with no known place last).
           CASE WHEN here.point IS NULL THEN 0 ELSE coalesce(ST_Distance(ad_loc.point, here.point), 'Infinity') END,
           CASE WHEN q.text = '' THEN 0
                ELSE ts_rank(a.search_vector, to_tsquery('simple', terms.tsq))
                     + public.word_similarity(q.text, public.normalize_arabic(a.title)) END DESC,
           a.created_at DESC
  LIMIT least(greatest(p_limit, 1), 100)
  OFFSET greatest(p_offset, 0);
$$;

CREATE OR REPLACE FUNCTION public.saved_search_tsquery(p_keywords text)
RETURNS tsquery
LANGUAGE sql STABLE PARALLEL SAFE SET search_path = public, pg_temp
AS $$
  -- Same expansion as search_ads (synonyms included); NULL when there are no words.
  SELECT CASE WHEN public.search_tsquery_text(public.normalize_arabic(btrim(coalesce(p_keywords, '')))) IS NULL THEN NULL
              ELSE to_tsquery('simple', public.search_tsquery_text(public.normalize_arabic(btrim(coalesce(p_keywords, ''))))) END;
$$;

REVOKE ALL ON FUNCTION public.normalize_synonym_term() FROM PUBLIC, anon, authenticated;
