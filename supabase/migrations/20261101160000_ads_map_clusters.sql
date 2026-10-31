-- 🟡13 (FR-2.4): ads on a map, clustered on the server.
-- ads_map_clusters groups the visible ads inside the map's bounds into grid
-- cells sized by the zoom level (smaller cells as the user zooms in). A cell
-- with one ad returns that ad (id, title, price) so the app can open it.
-- Same visibility and filters as search_ads (query with synonyms, category
-- including its subcategories, type, price); an ad without its own
-- coordinates is placed at its city's centre. At most 500 cells per call.

CREATE OR REPLACE FUNCTION public.ads_map_clusters(
  p_min_lat     double precision,
  p_min_lng     double precision,
  p_max_lat     double precision,
  p_max_lng     double precision,
  p_zoom        integer,
  p_query       text DEFAULT NULL,
  p_category_id integer DEFAULT NULL,
  p_ad_type     public.ad_type_enum DEFAULT NULL,
  p_min_price   numeric DEFAULT NULL,
  p_max_price   numeric DEFAULT NULL
)
RETURNS TABLE (lat double precision, lng double precision, ad_count integer, ad_id uuid, title text, price numeric)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_temp
AS $$
  WITH params AS (
    SELECT ST_MakeEnvelope(greatest(least(p_min_lng, p_max_lng), -180), greatest(least(p_min_lat, p_max_lat), -90),
                           least(greatest(p_min_lng, p_max_lng), 180), least(greatest(p_min_lat, p_max_lat), 90), 4326) AS box,
           -- About 4 cells across a 256px tile at this zoom.
           360.0 / power(2, least(greatest(coalesce(p_zoom, 6), 3), 20)) / 4 AS cell,
           public.search_tsquery_text(public.normalize_arabic(btrim(coalesce(p_query, '')))) AS tsq
  ), pts AS (
    SELECT a.id, a.title, a.price,
           coalesce(a.location_point::geometry,
                    CASE WHEN c.latitude IS NOT NULL AND c.longitude IS NOT NULL
                         THEN ST_SetSRID(ST_MakePoint(c.longitude, c.latitude), 4326) END) AS g
    FROM public.ads a
    LEFT JOIN public.cities c ON c.id = a.city_id
    CROSS JOIN params
    WHERE a.status = 'active' AND a.deleted_at IS NULL AND NOT coalesce(a.is_hidden, false)
      AND (params.tsq IS NULL OR a.search_vector @@ to_tsquery('simple', params.tsq))
      AND (p_category_id IS NULL OR a.category_id = p_category_id
           OR a.category_id IN (SELECT id FROM public.categories WHERE parent_id = p_category_id))
      AND (p_ad_type IS NULL OR a.ad_type = p_ad_type)
      AND (p_min_price IS NULL OR a.price >= p_min_price)
      AND (p_max_price IS NULL OR a.price <= p_max_price)
  )
  SELECT ST_Y(ST_Centroid(ST_Collect(pts.g))), ST_X(ST_Centroid(ST_Collect(pts.g))), count(*)::integer,
         CASE WHEN count(*) = 1 THEN min(pts.id::text)::uuid END,
         CASE WHEN count(*) = 1 THEN min(pts.title)::text END,
         CASE WHEN count(*) = 1 THEN min(pts.price) END
  FROM pts CROSS JOIN params
  WHERE pts.g IS NOT NULL AND ST_Intersects(pts.g, params.box)
  GROUP BY ST_SnapToGrid(pts.g, params.cell)
  ORDER BY count(*) DESC
  LIMIT 500;
$$;

REVOKE ALL ON FUNCTION public.ads_map_clusters(double precision, double precision, double precision, double precision, integer,
  text, integer, public.ad_type_enum, numeric, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ads_map_clusters(double precision, double precision, double precision, double precision, integer,
  text, integer, public.ad_type_enum, numeric, numeric) TO anon, authenticated, service_role;
