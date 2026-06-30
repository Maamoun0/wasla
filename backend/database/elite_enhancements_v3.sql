-- 🌍 Wasla Elite Enhancements - Part 2: Geofencing & PostGIS Optimization

-- 1. Add geography column for high-performance spatial queries
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS location_point geography(POINT, 4326);

-- 2. Create a trigger to keep location_point in sync with latitude/longitude
CREATE OR REPLACE FUNCTION public.sync_ad_location_point()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location_point := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_sync_ad_location ON public.ads;
CREATE TRIGGER tr_sync_ad_location
BEFORE INSERT OR UPDATE OF latitude, longitude ON public.ads
FOR EACH ROW EXECUTE FUNCTION public.sync_ad_location_point();

-- 3. High-performance radial search function
CREATE OR REPLACE FUNCTION public.get_ads_near_me(
    p_lat DECIMAL,
    p_lng DECIMAL,
    p_radius_meters FLOAT DEFAULT 5000,
    p_limit INT DEFAULT 20
)
RETURNS SETOF public.ads AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.ads
    WHERE 
        status = 'active'
        AND ST_DWithin(
            location_point, 
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, 
            p_radius_meters
        )
    ORDER BY location_point <-> ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- 4. Create index for spatial queries
CREATE INDEX IF NOT EXISTS idx_ads_location_point ON public.ads USING GIST(location_point);
