-- 🟡1 Saved searches from the app.
--  * Keyword matching now works like search_ads: Arabic-normalised, every
--    word as a prefix (a saved "سيارة" matches an ad saying "سياره"). It was
--    a plain ILIKE on the raw phrase.
--  * The saved ad type (offering/seeking) is matched too.
--  * Saved searches are validated on write: at least one criterion (an empty
--    search would alert on every new ad), only known filter keys with valid
--    values, and at most 20 per user.
--  * Clients may only write the search itself, not last_notified_at.

CREATE OR REPLACE FUNCTION public.saved_search_tsquery(p_keywords text)
RETURNS tsquery
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = public, pg_temp
AS $$
  -- Same tokenisation as search_ads; NULL when there are no words.
  SELECT to_tsquery('simple', string_agg(quote_literal(w) || ':*', ' & '))
  FROM regexp_split_to_table(
         regexp_replace(public.normalize_arabic(btrim(coalesce(p_keywords, ''))), '[''\\:&|!()<>*]', ' ', 'g'),
         '\s+') AS w
  WHERE w <> '';
$$;

CREATE OR REPLACE FUNCTION public.enqueue_watchlist_matches(p_ad public.ads)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_parent smallint;
  r record;
BEGIN
  SELECT parent_id INTO v_parent FROM public.categories WHERE id = p_ad.category_id;

  FOR r IN
    SELECT DISTINCT ON (s.user_id) s.id, s.user_id,
           coalesce((u.notification_preferences ->> 'watchlist_matches')::boolean, true) AS wants_push
    FROM public.saved_searches s
    JOIN public.users u ON u.id = s.user_id AND u.deleted_at IS NULL
    WHERE s.is_active
      AND s.user_id <> p_ad.user_id
      AND (s.category_id IS NULL OR s.category_id IN (p_ad.category_id, v_parent))
      AND (s.city_id IS NULL OR s.city_id = p_ad.city_id)
      AND (public.saved_search_tsquery(s.keywords) IS NULL
           OR p_ad.search_vector @@ public.saved_search_tsquery(s.keywords))
      AND (NOT s.filters ? 'ad_type' OR p_ad.ad_type::text = s.filters ->> 'ad_type')
      AND (NOT s.filters ? 'min_price' OR p_ad.price >= (s.filters ->> 'min_price')::numeric)
      AND (NOT s.filters ? 'max_price' OR p_ad.price <= (s.filters ->> 'max_price')::numeric)
    ORDER BY s.user_id, s.created_at
  LOOP
    INSERT INTO public.watchlist_notifications (user_id, ad_id)
    VALUES (r.user_id, p_ad.id)
    ON CONFLICT (user_id, ad_id) DO NOTHING;
    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    UPDATE public.saved_searches SET last_notified_at = now() WHERE id = r.id;
    PERFORM public.enqueue_notification(
      r.user_id, 'saved_search_match', 'إعلان جديد يهمك! 🔔',
      format('لقينا إعلان "%s" يطابق بحثك المحفوظ.', p_ad.title),
      jsonb_build_object('type', 'watchlist_match', 'ad_id', p_ad.id),
      r.wants_push);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_saved_search()
RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp
AS $$
DECLARE
  k text;
BEGIN
  NEW.keywords := nullif(btrim(coalesce(NEW.keywords, '')), '');
  NEW.name := nullif(btrim(coalesce(NEW.name, '')), '');
  NEW.filters := coalesce(NEW.filters, '{}'::jsonb);

  IF jsonb_typeof(NEW.filters) <> 'object' THEN
    RAISE EXCEPTION 'filters must be an object' USING ERRCODE = '22023';
  END IF;
  FOR k IN SELECT jsonb_object_keys(NEW.filters) LOOP
    IF k NOT IN ('min_price', 'max_price', 'ad_type') THEN
      RAISE EXCEPTION 'unknown saved-search filter: %', k USING ERRCODE = '22023';
    END IF;
  END LOOP;
  IF (NEW.filters ? 'min_price' AND jsonb_typeof(NEW.filters -> 'min_price') <> 'number')
     OR (NEW.filters ? 'max_price' AND jsonb_typeof(NEW.filters -> 'max_price') <> 'number') THEN
    RAISE EXCEPTION 'prices must be numbers' USING ERRCODE = '22023';
  END IF;
  IF NEW.filters ? 'ad_type' AND NEW.filters ->> 'ad_type' NOT IN ('offering', 'seeking') THEN
    RAISE EXCEPTION 'invalid ad_type' USING ERRCODE = '22023';
  END IF;

  IF NEW.category_id IS NULL AND NEW.city_id IS NULL AND NEW.keywords IS NULL
     AND NOT (NEW.filters ?| ARRAY['min_price', 'max_price', 'ad_type']) THEN
    RAISE EXCEPTION 'a saved search needs at least one criterion' USING ERRCODE = '22023';
  END IF;

  IF TG_OP = 'INSERT' AND (SELECT count(*) FROM public.saved_searches WHERE user_id = NEW.user_id) >= 20 THEN
    RAISE EXCEPTION 'saved search limit reached' USING ERRCODE = 'P0001', HINT = 'saved_search_limit';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_saved_search ON public.saved_searches;
CREATE TRIGGER trg_validate_saved_search
  BEFORE INSERT OR UPDATE OF name, category_id, city_id, keywords, filters ON public.saved_searches
  FOR EACH ROW EXECUTE FUNCTION public.validate_saved_search();

REVOKE INSERT, UPDATE ON public.saved_searches FROM anon, authenticated;
GRANT INSERT (user_id, name, category_id, city_id, keywords, filters) ON public.saved_searches TO authenticated;
GRANT UPDATE (name, is_active) ON public.saved_searches TO authenticated;
