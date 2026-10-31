-- N25 (approved 2026-11-01): the seed had 29 of 58 cities twice (same
-- governorate, same name), so every city list showed them twice.
--  * Each duplicate group keeps its smallest id; every reference (ads,
--    users, saved_searches, districts) is moved to it, then the extra rows
--    are deleted. Missing coordinates are taken from a duplicate.
--  * Districts that end up twice under one city are merged the same way.
--  * Unique indexes on (governorate, normalised name) and (city, normalised
--    name) stop it from happening again. Normalised = Arabic letter forms
--    unified, diacritics removed, spaces collapsed (normalize_arabic).
-- The full official seed of all markaz/cities is NOT in this migration: no
-- machine-readable official list could be obtained (see AUDIT_REPORT §21).

CREATE OR REPLACE FUNCTION public.place_name_key(p_name text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = public, pg_temp
AS $$
  SELECT public.normalize_arabic(btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g')));
$$;

-- ── Cities ───────────────────────────────────────────────────────
CREATE TEMP TABLE city_map ON COMMIT DROP AS
SELECT id AS dup_id, keep_id FROM (
  SELECT id, min(id) OVER (PARTITION BY governorate_id, public.place_name_key(name_ar)) AS keep_id
  FROM public.cities
) c WHERE id <> keep_id;

UPDATE public.cities k SET
  latitude  = coalesce(k.latitude,  d.latitude),
  longitude = coalesce(k.longitude, d.longitude),
  is_active = k.is_active OR d.is_active
FROM city_map m JOIN public.cities d ON d.id = m.dup_id
WHERE k.id = m.keep_id;

UPDATE public.ads            t SET city_id = m.keep_id FROM city_map m WHERE t.city_id = m.dup_id;
UPDATE public.users          t SET city_id = m.keep_id FROM city_map m WHERE t.city_id = m.dup_id;
UPDATE public.saved_searches t SET city_id = m.keep_id FROM city_map m WHERE t.city_id = m.dup_id;
UPDATE public.districts      t SET city_id = m.keep_id FROM city_map m WHERE t.city_id = m.dup_id;
DELETE FROM public.cities c USING city_map m WHERE c.id = m.dup_id;

-- ── Districts (including those the city merge brought together) ──
CREATE TEMP TABLE district_map ON COMMIT DROP AS
SELECT id AS dup_id, keep_id FROM (
  SELECT id, min(id) OVER (PARTITION BY city_id, public.place_name_key(name_ar)) AS keep_id
  FROM public.districts
) d WHERE id <> keep_id;

UPDATE public.ads t SET district_id = m.keep_id FROM district_map m WHERE t.district_id = m.dup_id;
UPDATE public.saved_searches t
SET filters = jsonb_set(t.filters, '{district_id}', to_jsonb(m.keep_id))
FROM district_map m WHERE (t.filters ->> 'district_id')::integer = m.dup_id;
DELETE FROM public.districts d USING district_map m WHERE d.id = m.dup_id;

CREATE UNIQUE INDEX IF NOT EXISTS uq_cities_governorate_name
  ON public.cities (governorate_id, public.place_name_key(name_ar));
CREATE UNIQUE INDEX IF NOT EXISTS uq_districts_city_name
  ON public.districts (city_id, public.place_name_key(name_ar));
