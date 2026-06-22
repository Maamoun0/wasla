-- ========================================================================================
-- WASLA SMART CLASSIFIEDS PLATFORM - DATABASE SCHEMA UPGRADE v2.1
-- Resolving Gaps, Adding Push Tokens, Blocks, Soft Delete, AI Vector and Seed Data
-- ========================================================================================

-- 1. Enable Vector Extension (for AI Recommendations/Matching)
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Add Soft Delete Column to Users and Ads
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 3. Create missing push_tokens table for FCM
CREATE TABLE IF NOT EXISTS public.push_tokens (
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform VARCHAR(20), -- 'ios', 'android', 'web'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, device_token)
);

-- RLS for push_tokens
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'push_tokens_insert') THEN
        CREATE POLICY "push_tokens_insert" ON public.push_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'push_tokens_select') THEN
        CREATE POLICY "push_tokens_select" ON public.push_tokens FOR SELECT USING (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'push_tokens_delete') THEN
        CREATE POLICY "push_tokens_delete" ON public.push_tokens FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;

-- 4. Create missing user_blocks table
CREATE TABLE IF NOT EXISTS public.user_blocks (
    blocker_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id)
);

-- RLS for user_blocks
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'user_blocks_insert') THEN
        CREATE POLICY "user_blocks_insert" ON public.user_blocks FOR INSERT WITH CHECK (auth.uid() = blocker_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'user_blocks_select') THEN
        CREATE POLICY "user_blocks_select" ON public.user_blocks FOR SELECT USING (auth.uid() = blocker_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'user_blocks_delete') THEN
        CREATE POLICY "user_blocks_delete" ON public.user_blocks FOR DELETE USING (auth.uid() = blocker_id);
    END IF;
END $$;

-- 5. Create missing ad_edit_history table
CREATE TABLE IF NOT EXISTS public.ad_edit_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ad_id UUID REFERENCES public.ads(id) ON DELETE CASCADE,
    old_title VARCHAR(255),
    old_description TEXT,
    old_price DECIMAL(12,2),
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for ad_edit_history
ALTER TABLE public.ad_edit_history ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'ad_edit_history_select') THEN
        CREATE POLICY "ad_edit_history_select" ON public.ad_edit_history FOR SELECT USING (
            EXISTS (
                SELECT 1 FROM public.ads WHERE ads.id = ad_edit_history.ad_id AND ads.user_id = auth.uid()
            )
        );
    END IF;
END $$;

-- 6. Create missing business_profiles table
CREATE TABLE IF NOT EXISTS public.business_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    company_name VARCHAR(150) NOT NULL,
    commercial_registry VARCHAR(50),
    tax_card VARCHAR(50),
    business_address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for business_profiles
ALTER TABLE public.business_profiles ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'business_profiles_select') THEN
        CREATE POLICY "business_profiles_select" ON public.business_profiles FOR SELECT USING (TRUE);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'business_profiles_insert') THEN
        CREATE POLICY "business_profiles_insert" ON public.business_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'business_profiles_update') THEN
        CREATE POLICY "business_profiles_update" ON public.business_profiles FOR UPDATE USING (auth.uid() = user_id);
    END IF;
END $$;

-- 7. Create missing app_versions table (Force Update)
CREATE TABLE IF NOT EXISTS public.app_versions (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(20) NOT NULL UNIQUE, -- 'android', 'ios'
    min_version VARCHAR(20) NOT NULL,      -- e.g. '1.0.0'
    latest_version VARCHAR(20) NOT NULL,
    force_update BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for app_versions
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'app_versions_select') THEN
        CREATE POLICY "app_versions_select" ON public.app_versions FOR SELECT USING (TRUE);
    END IF;
END $$;

-- Seed version configs
INSERT INTO public.app_versions (platform, min_version, latest_version, force_update)
VALUES 
  ('android', '1.0.0', '1.0.0', false),
  ('ios', '1.0.0', '1.0.0', false)
ON CONFLICT (platform) DO NOTHING;

-- 8. Add AI Embeddings Column to Ads table
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS embedding vector(1536);

-- 9. Seed Districts/Areas for major Cairo, Giza, and Alexandria cities
-- Cairo Cities: Nasr City (id=2), Maadi (id=3), Fifth Settlement (id=9)
-- Giza Cities: Dokki (id=16), Sheikh Zayed (id=20)
-- Alexandria Cities: Smouha (id=25)

-- Seed Nasr City (city_id=2)
INSERT INTO public.districts (city_id, name_ar, name_en) VALUES
  (2, 'المنطقة الأولى', 'First Zone'),
  (2, 'الحي السابع', 'Seventh District'),
  (2, 'الحي الثامن', 'Eighth District'),
  (2, 'زهراء مدينة نصر', 'Zahraa Nasr City'),
  (2, 'عباس العقاد', 'Abbas El Akkad St'),
  (2, 'مكرم عبيد', 'Makram Ebeid St')
ON CONFLICT DO NOTHING;

-- Seed Maadi (city_id=3)
INSERT INTO public.districts (city_id, name_ar, name_en) VALUES
  (3, 'دجلة المعادي', 'Degla Maadi'),
  (3, 'ثكنات المعادي', 'Thakanat Maadi'),
  (3, 'المعادي الجديدة', 'New Maadi'),
  (3, 'زهراء المعادي', 'Zahraa Maadi'),
  (3, 'كورنيش المعادي', 'Maadi Corniche')
ON CONFLICT DO NOTHING;

-- Seed Fifth Settlement (city_id=9)
INSERT INTO public.districts (city_id, name_ar, name_en) VALUES
  (9, 'النرجس', 'Al Narges'),
  (9, 'الياسمين', 'Al Yasmeen'),
  (9, 'البنفسج', 'Al Banafsaj'),
  (9, 'اللوتس', 'Al Lotus'),
  (9, 'المستثمرين الجنوبية', 'Southern Investors'),
  (9, 'شارع التسعين', 'El Tesseen St')
ON CONFLICT DO NOTHING;

-- Seed Dokki (city_id=16)
INSERT INTO public.districts (city_id, name_ar, name_en) VALUES
  (16, 'ميدان المساحة', 'Mesaha Square'),
  (16, 'شارع التحرير', 'Tahrir St'),
  (16, 'منطقة البحوث', 'Research Area'),
  (16, 'شارع مصدق', 'Mosaddak St'),
  (16, 'بين السرايات', 'Been El Sarayat')
ON CONFLICT DO NOTHING;

-- Seed Sheikh Zayed (city_id=20)
INSERT INTO public.districts (city_id, name_ar, name_en) VALUES
  (20, 'الحي الأول', 'First District'),
  (20, 'الحي الثاني', 'Second District'),
  (20, 'الحي الثامن', 'Eighth District'),
  (20, 'الحي السادس عشر', 'Sixteenth District'),
  (20, 'الثورة الخضراء', 'Green Revolution')
ON CONFLICT DO NOTHING;

-- Seed Smouha (city_id=25)
INSERT INTO public.districts (city_id, name_ar, name_en) VALUES
  (25, 'شارع فوزي معاذ', 'Fawzy Moaz St'),
  (25, 'شارع ألبرت الأول', 'Albert First St'),
  (25, 'منطقة فيكتوريا', 'Victoria Area'),
  (25, 'عزبة سعد', 'Ezbet Saad')
ON CONFLICT DO NOTHING;
