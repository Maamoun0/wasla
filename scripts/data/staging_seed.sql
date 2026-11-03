-- Realistic test data for STAGING only: ~300 users, ~3000 ads, contacts,
-- reviews and reports. Every row is marked is_seed; remove it all with
--   select public.delete_seed_data();
-- Run:
--   npx -y supabase@2.120.0 db query --linked -f scripts/data/staging_seed.sql
-- Seeded random (setseed): two runs give the same mix, counts within a few rows.
-- Refuses to run twice: delete the old seed first.
--
-- Built in on purpose, for docs/ALGORITHMS.md to find:
--   * 12 "farm" accounts made within minutes of each other that post the same
--     ad text over and over at a too-good price (fake-account and duplicate
--     detection);
--   * ~2% of prices off by a factor (a missing or extra zero) (price outliers);
--   * a few sellers with many 5-star reviews from accounts with no other activity.

DO $seed$
DECLARE
  first_names text[] := ARRAY['أحمد','محمد','محمود','مصطفى','عمر','يوسف','كريم','حسن','علي','إبراهيم','خالد','طارق','سامح','هاني','وليد',
                              'سارة','منى','مريم','نورا','هبة','دينا','رانيا','ياسمين','آية','شيماء','فاطمة','أمل','ريهام','نهى','إيمان'];
  last_names  text[] := ARRAY['عبد الله','السيد','حسين','فؤاد','الشريف','منصور','سليمان','عبد الرحمن','فتحي','صبري','جمال','نصر','رشاد','عادل','زكي'];
  conditions  text[] := ARRAY['حالة ممتازة','زي الجديد','استعمال خفيف','بحالة كويسة','جديد متبرشم'];
  reject_why  text[] := ARRAY['الصور مش واضحة','السعر مش منطقي','الإعلان مكرر','بيانات تواصل في الوصف','القسم غلط'];
  comments    text[] := ARRAY['تعامل محترم جداً','البائع صادق والحاجة زي الصور','اتأخر في الرد شوية','كويس بس السعر كان أعلى من المتفق','ممتاز وأنصح بالتعامل معاه','مش زي الوصف للأسف','رد بسرعة واتفقنا'];
  v_city record;
  v_user uuid;
  v_cat record;
  v_users uuid[] := '{}';
  v_farm uuid[] := '{}';
  v_ad uuid;
  v_ring uuid;
  v_status ad_status_enum;
  v_created timestamptz;
  v_price numeric;
  v_title text;
  v_desc text;
  i int;
  n int;
BEGIN
  IF EXISTS (SELECT 1 FROM public.users WHERE is_seed) THEN
    RAISE EXCEPTION 'seed data already present: run select public.delete_seed_data(); first';
  END IF;
  PERFORM setseed(0.42);

  -- ── Users ─────────────────────────────────────────────────────────
  FOR i IN 1..300 LOOP
    v_user := gen_random_uuid();
    INSERT INTO auth.users (id, instance_id, aud, role, phone, phone_confirmed_at, raw_user_meta_data, created_at, updated_at)
    VALUES (v_user, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            '2015' || lpad(i::text, 8, '0'), now(),
            jsonb_build_object('full_name', first_names[1 + floor(random() * 30)::int] || ' ' || last_names[1 + floor(random() * 15)::int]),
            now() - (random() * 365 || ' days')::interval, now());
    v_users := v_users || v_user;
  END LOOP;

  -- The farm: 12 accounts within ten minutes, three days ago.
  FOR i IN 1..12 LOOP
    v_user := gen_random_uuid();
    INSERT INTO auth.users (id, instance_id, aud, role, phone, phone_confirmed_at, raw_user_meta_data, created_at, updated_at)
    VALUES (v_user, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            '2016' || lpad(i::text, 8, '0'), now(), jsonb_build_object('full_name', 'عروض ' || i),
            now() - interval '3 days' + (i || ' minutes')::interval, now());
    v_farm := v_farm || v_user;
  END LOOP;

  UPDATE public.users u SET
    is_seed = true,
    status = 'active',
    is_phone_verified = true,
    is_id_verified = random() < 0.2,
    user_type = CASE WHEN random() < 0.1 THEN 'business'::user_type_enum ELSE 'regular'::user_type_enum END,
    city_id = (SELECT id FROM public.cities ORDER BY random() LIMIT 1),
    created_at = a.created_at,
    last_active_at = now() - (random() * 30 || ' days')::interval
  FROM auth.users a
  WHERE a.id = u.id AND u.id = ANY (v_users || v_farm);
  UPDATE public.users SET is_id_verified = false, user_type = 'regular' WHERE id = ANY (v_farm);

  -- ── Ads ───────────────────────────────────────────────────────────
  FOR i IN 1..2900 LOOP
    SELECT c.id, c.name_ar, p.name_ar AS parent INTO v_cat
      FROM public.categories c JOIN public.categories p ON p.id = c.parent_id
      WHERE c.is_active ORDER BY random() LIMIT 1;
    SELECT id, latitude, longitude, name_ar INTO v_city FROM public.cities ORDER BY random() LIMIT 1;

    v_price := CASE v_cat.parent
      WHEN 'عقارات' THEN CASE WHEN v_cat.name_ar LIKE '%للإيجار%' THEN round((2000 + random() * 18000) / 100) * 100
                              ELSE round((400000 + random() * 4600000) / 1000) * 1000 END
      WHEN 'سيارات' THEN CASE v_cat.name_ar WHEN 'سيارات' THEN round((150000 + random() * 1350000) / 1000) * 1000
                                            WHEN 'تكاتك' THEN round((40000 + random() * 60000) / 500) * 500
                                            ELSE round((20000 + random() * 280000) / 500) * 500 END
      WHEN 'وظائف'  THEN round((4000 + random() * 21000) / 100) * 100
      WHEN 'خدمات'  THEN round((100 + random() * 1900) / 10) * 10
      ELSE round((150 + random() * 24850) / 10) * 10 END;
    -- A missing or extra zero, as people really type it.
    IF random() < 0.02 THEN v_price := CASE WHEN random() < 0.5 THEN v_price * 10 ELSE round(v_price / 10) END; END IF;

    v_title := v_cat.name_ar || ' - ' || conditions[1 + floor(random() * 5)::int] || ' - ' || v_city.name_ar;
    v_desc := 'إعلان ' || v_cat.name_ar || ' في ' || v_city.name_ar || '. ' || conditions[1 + floor(random() * 5)::int]
              || '. للتواصل من خلال التطبيق. رقم الإعلان ' || i || '.';

    v_created := now() - (random() * 60 || ' days')::interval;
    v_status := (ARRAY['active','active','active','active','active','active','pending','pending','expired','expired','expired','rejected']::ad_status_enum[])[1 + floor(random() * 12)::int];

    INSERT INTO public.ads (user_id, category_id, title, description, price, price_type, city_id,
                            latitude, longitude, status, rejection_reason, is_featured, is_urgent,
                            views_count, contacts_count, created_at, published_at, expires_at, is_seed)
    VALUES (v_users[1 + floor(random() * 300)::int], v_cat.id, left(v_title, 120), v_desc, v_price,
            CASE WHEN v_cat.parent = 'خدمات' AND random() < 0.4 THEN 'negotiable'::price_type_enum ELSE 'fixed'::price_type_enum END,
            v_city.id,
            v_city.latitude + (random() - 0.5) * 0.04, v_city.longitude + (random() - 0.5) * 0.04,
            v_status,
            CASE WHEN v_status = 'rejected' THEN reject_why[1 + floor(random() * 5)::int] END,
            v_status = 'active' AND random() < 0.05,
            v_status = 'active' AND random() < 0.05,
            floor(power(random(), 3) * 2000)::int, 0,
            v_created,
            CASE WHEN v_status IN ('active', 'expired') THEN v_created + interval '2 hours' END,
            CASE WHEN v_status = 'expired' THEN now() - (random() * 20 || ' days')::interval
                 ELSE v_created + interval '2 hours' + interval '30 days' END,
            true);
  END LOOP;

  -- The farm's ads: the same text, copied, at a too-good price.
  FOR i IN 1..100 LOOP
    SELECT id, latitude, longitude, name_ar INTO v_city FROM public.cities ORDER BY random() LIMIT 1;
    INSERT INTO public.ads (user_id, category_id, title, description, price, city_id, latitude, longitude,
                            status, created_at, published_at, expires_at, is_seed)
    VALUES (v_farm[1 + (i % 12)], 29, 'عربية بسعر لقطة للبيع فوراً',
            'عربية بحالة ممتازة بسعر لقطة، المالك مسافر. كلمني واتساب على طول قبل ما تتباع.',
            25000 + floor(random() * 10000), v_city.id, v_city.latitude, v_city.longitude,
            CASE WHEN random() < 0.7 THEN 'active'::ad_status_enum ELSE 'pending'::ad_status_enum END,
            now() - interval '3 days' + (i * 20 || ' minutes')::interval,
            now() - interval '3 days' + (i * 20 + 30 || ' minutes')::interval,
            now() + interval '27 days', true);
  END LOOP;

  -- ── Contacts (calls/WhatsApp) on active ads, last 25 days ──────────
  INSERT INTO public.contact_logs (ad_id, user_id, contact_type, created_at, is_seed)
  SELECT a.id, v_users[1 + floor(random() * 300)::int],
         (ARRAY['phone','whatsapp']::contact_type_enum[])[1 + floor(random() * 2)::int],
         now() - (random() * 25 || ' days')::interval, true
  FROM public.ads a, generate_series(1, 3) g
  WHERE a.is_seed AND a.status = 'active' AND random() < 0.6;
  DELETE FROM public.contact_logs c USING public.ads a
   WHERE c.is_seed AND c.ad_id = a.id AND c.user_id = a.user_id;  -- nobody contacts themself
  UPDATE public.ads a SET contacts_count = s.n
    FROM (SELECT ad_id, count(*) n FROM public.contact_logs WHERE is_seed GROUP BY ad_id) s
   WHERE a.id = s.ad_id;

  -- ── Reviews: about a third of contacts, at most one per buyer/seller ──
  INSERT INTO public.reviews (reviewer_id, reviewed_user_id, ad_id, rating, comment, created_at, is_seed)
  SELECT DISTINCT ON (c.user_id, a.user_id)
         c.user_id, a.user_id, a.id,
         (ARRAY[5,5,5,4,4,4,3,2,1])[1 + floor(random() * 9)::int],
         comments[1 + floor(random() * 7)::int],
         c.created_at + interval '1 day', true
  FROM public.contact_logs c JOIN public.ads a ON a.id = c.ad_id
  WHERE c.is_seed AND random() < 0.33
  ORDER BY c.user_id, a.user_id, c.created_at;

  -- Review rings: five sellers each praised by ten throwaway accounts.
  FOR n IN 1..5 LOOP
    v_user := v_users[n * 7];
    SELECT id INTO v_ad FROM public.ads WHERE user_id = v_user AND status = 'active' LIMIT 1;
    CONTINUE WHEN v_ad IS NULL;
    FOR i IN 1..10 LOOP
      INSERT INTO auth.users (id, instance_id, aud, role, phone, phone_confirmed_at, raw_user_meta_data, created_at, updated_at)
      VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
              '2017' || lpad((n * 100 + i)::text, 8, '0'), now(), jsonb_build_object('full_name', 'مستخدم ' || (n * 100 + i)),
              now() - interval '2 days', now())
      RETURNING id INTO v_ring;
      UPDATE public.users SET is_seed = true, status = 'active', created_at = now() - interval '2 days' WHERE id = v_ring;
      INSERT INTO public.contact_logs (ad_id, user_id, contact_type, created_at, is_seed)
      VALUES (v_ad, v_ring, 'whatsapp', now() - interval '1 day', true);
      INSERT INTO public.reviews (reviewer_id, reviewed_user_id, ad_id, rating, comment, created_at, is_seed)
      VALUES (v_ring, v_user, v_ad, 5, 'ممتاز', now() - interval '20 hours', true);
    END LOOP;
  END LOOP;

  -- ── Reports: ~150 ordinary, and the farm's ads reported often ──────
  INSERT INTO public.reports (reporter_id, target_type, target_id, reason, description, status, created_at, is_seed)
  SELECT v_users[1 + floor(random() * 300)::int], 'ad', a.id,
         (ARRAY['spam','fraud','inappropriate','wrong_category','duplicate']::report_reason_enum[])[1 + floor(random() * 5)::int],
         NULL,
         (ARRAY['pending','pending','reviewed','dismissed']::report_status_enum[])[1 + floor(random() * 4)::int],
         now() - (random() * 20 || ' days')::interval, true
  FROM public.ads a
  WHERE a.is_seed AND a.status = 'active' AND random() < 0.07;
  INSERT INTO public.reports (reporter_id, target_type, target_id, reason, description, created_at, is_seed)
  SELECT v_users[1 + floor(random() * 300)::int], 'ad', a.id, 'fraud', 'السعر مش منطقي وطلب عربون', now() - interval '1 day', true
  FROM public.ads a
  WHERE a.is_seed AND a.title = 'عربية بسعر لقطة للبيع فوراً' AND random() < 0.4;
END
$seed$;

SELECT
  (SELECT count(*) FROM public.users WHERE is_seed) AS users,
  (SELECT count(*) FROM public.ads WHERE is_seed) AS ads,
  (SELECT count(*) FROM public.contact_logs WHERE is_seed) AS contacts,
  (SELECT count(*) FROM public.reviews WHERE is_seed) AS reviews,
  (SELECT count(*) FROM public.reports WHERE is_seed) AS reports;
