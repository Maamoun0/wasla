-- ================================================================
-- Post Ad Wizard dynamic fields.
-- The wizard stores the subcategory id, but fields were only seeded on
-- three top-level categories, so every subcategory showed none.
--   * get_category_fields(id): the parent's shared fields followed by the
--     subcategory's own (a subcategory field overrides a parent field of
--     the same name). Used by the app and by create-ad.
--   * Fields for every subcategory, plus shared fields for Services and
--     Goods. Vehicle / real-estate parent fields that only fit some
--     subcategories (car brands, rooms) move down to those subcategories.
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_category_fields(p_category_id integer)
RETURNS SETOF public.category_fields
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_temp
AS $$
  SELECT f.*
  FROM public.categories c
  JOIN public.category_fields f
    ON f.category_id = c.id
    OR (f.category_id = c.parent_id
        AND NOT EXISTS (SELECT 1 FROM public.category_fields own
                        WHERE own.category_id = c.id AND own.field_name = f.field_name))
  WHERE c.id = p_category_id AND c.is_active
  ORDER BY (f.category_id = c.id), f.sort_order, f.id;
$$;

REVOKE ALL ON FUNCTION public.get_category_fields(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_category_fields(integer) TO anon, authenticated, service_role;

-- Parent fields being restructured (no ads exist yet, so nothing references them).
DELETE FROM public.category_fields
WHERE category_id IN (SELECT id FROM public.categories WHERE slug IN ('real-estate', 'vehicles'));

INSERT INTO public.category_fields (category_id, field_name, label_ar, field_type, is_required, is_searchable, sort_order, options)
SELECT c.id, v.field_name, v.label_ar, v.field_type::public.field_type_enum, v.is_required, v.is_searchable, v.sort_order, v.options::jsonb
FROM (VALUES
  -- ── Services (shared) ───────────────────────────────────────────
  ('services', 'service_location', 'مكان تقديم الخدمة', 'select', true,  true,  1, '["في منزل العميل", "في مقر مقدم الخدمة", "عن بُعد"]'),
  ('services', 'experience_years', 'سنوات الخبرة',      'number', false, false, 2, NULL),
  ('services', 'availability',     'مواعيد العمل',      'select', false, false, 3, '["يومياً", "أيام العمل فقط", "نهاية الأسبوع", "حسب الاتفاق"]'),
  ('plumbing',    'emergency_service', 'خدمة طوارئ 24 ساعة', 'boolean', false, true, 10, NULL),
  ('plumbing',    'work_type',   'نوع العمل',  'select', true, true, 11, '["صيانة وتصليح", "تأسيس سباكة", "تركيب أدوات صحية", "تسليك مجاري", "كشف تسريبات"]'),
  ('electrical',  'emergency_service', 'خدمة طوارئ 24 ساعة', 'boolean', false, true, 10, NULL),
  ('electrical',  'work_type',   'نوع العمل',  'select', true, true, 11, '["صيانة وتصليح", "تأسيس كهرباء", "تركيب نجف وإضاءة", "لوحات كهرباء", "تركيب كاميرات"]'),
  ('teaching',    'subject',     'المادة',     'text',   true, true, 10, NULL),
  ('teaching',    'level',       'المرحلة الدراسية', 'select', true, true, 11, '["ابتدائي", "إعدادي", "ثانوي", "جامعي", "لغات", "أخرى"]'),
  ('cleaning',    'cleaning_type', 'نوع التنظيف', 'select', true, true, 10, '["منازل", "مكاتب وشركات", "سجاد وموكيت", "مكافحة حشرات", "تنظيف بعد التشطيب"]'),
  ('carpentry',   'work_type',   'نوع العمل',  'select', true, true, 10, '["تصنيع أثاث", "صيانة وتصليح", "تركيب مطابخ", "أبواب وشبابيك"]'),
  ('painting',    'work_type',   'نوع العمل',  'select', true, true, 10, '["دهانات", "ورق حائط", "جبس بورد", "ديكورات"]'),
  ('ac-cooling',  'work_type',   'نوع العمل',  'select', true, true, 10, '["تركيب", "صيانة", "شحن فريون", "تنظيف"]'),
  ('transport',   'transport_type', 'نوع النقل', 'select', true, true, 10, '["نقل أثاث", "توصيل طلبات", "نقل ركاب", "نقل بضائع"]'),
  ('design-dev',  'skill',       'المجال',     'select', true, true, 10, '["تصميم جرافيك", "تطوير مواقع", "تطبيقات موبايل", "تسويق رقمي", "مونتاج فيديو", "أخرى"]'),
  ('healthcare',  'care_type',   'نوع الخدمة', 'select', true, true, 10, '["تمريض منزلي", "علاج طبيعي", "رعاية مسنين", "رعاية أطفال"]'),

  -- ── Jobs (shared fields job_type / experience_required already exist) ──
  ('jobs', 'education', 'المؤهل المطلوب', 'select', false, true, 3, '["بدون مؤهل", "مؤهل متوسط", "مؤهل عالٍ", "دراسات عليا"]'),
  ('admin-jobs',    'department',     'القسم',          'select', true,  true, 10, '["سكرتارية", "موارد بشرية", "محاسبة", "خدمة عملاء", "إدارة مكاتب"]'),
  ('sales-jobs',    'commission',     'عمولة على المبيعات', 'boolean', false, true, 10, NULL),
  ('sales-jobs',    'sales_channel',  'نوع المبيعات',   'select', true,  true, 11, '["مبيعات ميدانية", "مبيعات تليفونية", "مبيعات معارض", "مبيعات أونلاين"]'),
  ('tech-jobs',     'specialization', 'التخصص',         'text',   true,  true, 10, NULL),
  ('medical-jobs',  'specialization', 'التخصص',         'text',   true,  true, 10, NULL),
  ('edu-jobs',      'subject',        'المادة / المجال', 'text',  true,  true, 10, NULL),
  ('tourism-jobs',  'languages',      'اللغات المطلوبة', 'text',  false, true, 10, NULL),
  ('tourism-jobs',  'position',       'الوظيفة',        'select', true,  true, 11, '["استقبال", "خدمة غرف", "مطاعم ومشروبات", "مرشد سياحي", "حجوزات"]'),
  ('security-jobs', 'shift',          'الوردية',        'select', true,  true, 10, '["صباحي", "مسائي", "ليلي", "متغير"]'),

  -- ── Real estate ─────────────────────────────────────────────────
  ('real-estate', 'area_sqm', 'المساحة (متر مربع)', 'number', true, true, 1, NULL),
  ('apt-rent',   'rooms',        'عدد الغرف',  'select', true,  true,  10, '["استوديو", "1", "2", "3", "4", "5+"]'),
  ('apt-rent',   'bathrooms',    'عدد الحمامات', 'number', false, true, 11, NULL),
  ('apt-rent',   'floor',        'الدور',      'number', false, false, 12, NULL),
  ('apt-rent',   'furnished',    'مفروشة',     'boolean', false, true, 13, NULL),
  ('apt-rent',   'rent_period',  'مدة الإيجار', 'select', true,  true,  14, '["شهري", "سنوي", "يومي"]'),
  ('apt-sale',   'rooms',        'عدد الغرف',  'select', true,  true,  10, '["استوديو", "1", "2", "3", "4", "5+"]'),
  ('apt-sale',   'bathrooms',    'عدد الحمامات', 'number', false, true, 11, NULL),
  ('apt-sale',   'floor',        'الدور',      'number', false, false, 12, NULL),
  ('apt-sale',   'finishing',    'التشطيب',    'select', true,  true,  13, '["بدون تشطيب", "نصف تشطيب", "تشطيب كامل", "سوبر لوكس"]'),
  ('apt-sale',   'payment_method', 'طريقة الدفع', 'select', false, true, 14, '["كاش", "تقسيط", "كاش أو تقسيط"]'),
  ('rooms-rent', 'furnished',    'مفروشة',     'boolean', false, true, 10, NULL),
  ('rooms-rent', 'bathroom_type', 'الحمام',    'select', true,  true,  11, '["خاص", "مشترك"]'),
  ('rooms-rent', 'tenant_gender', 'مناسبة لـ', 'select', true,  true,  12, '["رجال", "سيدات", "بدون تفضيل"]'),
  ('villas',     'listing_purpose', 'الغرض',   'select', true,  true,  10, '["بيع", "إيجار"]'),
  ('villas',     'rooms',        'عدد الغرف',  'select', true,  true,  11, '["3", "4", "5", "6", "7+"]'),
  ('villas',     'finishing',    'التشطيب',    'select', false, true,  12, '["بدون تشطيب", "نصف تشطيب", "تشطيب كامل", "سوبر لوكس"]'),
  ('villas',     'has_garden',   'حديقة',      'boolean', false, true, 13, NULL),
  ('commercial', 'property_type', 'نوع الوحدة', 'select', true, true,  10, '["محل", "مكتب", "مخزن", "عيادة", "مصنع"]'),
  ('commercial', 'listing_purpose', 'الغرض',   'select', true,  true,  11, '["بيع", "إيجار"]'),
  ('commercial', 'finishing',    'التشطيب',    'select', false, true,  12, '["بدون تشطيب", "نصف تشطيب", "تشطيب كامل"]'),
  ('land',       'land_use',     'نوع الأرض',  'select', true,  true,  10, '["سكني", "زراعي", "تجاري", "صناعي"]'),
  ('land',       'licensed',     'مرخصة للبناء', 'boolean', false, true, 11, NULL),

  -- ── Vehicles ────────────────────────────────────────────────────
  ('vehicles', 'year',      'سنة الصنع',        'number', true,  true,  1, NULL),
  ('vehicles', 'condition', 'الحالة',           'select', true,  true,  2, '["جديد", "مستعمل - ممتاز", "مستعمل - جيد", "يحتاج صيانة"]'),
  ('vehicles', 'mileage',   'عداد الكيلومترات', 'number', false, true,  3, NULL),
  ('cars',        'brand',        'الماركة',     'select', true,  true, 10, '["تويوتا", "هيونداي", "كيا", "نيسان", "شيفروليه", "فيات", "بيجو", "رينو", "مرسيدس", "بي إم دبليو", "سكودا", "MG", "شيري", "أخرى"]'),
  ('cars',        'transmission', 'ناقل الحركة', 'select', true,  true, 11, '["أوتوماتيك", "مانيوال"]'),
  ('cars',        'fuel_type',    'نوع الوقود',  'select', false, true, 12, '["بنزين", "سولار", "غاز طبيعي", "كهرباء", "هايبرد"]'),
  ('motorcycles', 'brand',        'الماركة',     'select', true,  true, 10, '["هوندا", "ياماها", "سوزوكي", "دايون", "حوجن", "بينيلي", "أخرى"]'),
  ('motorcycles', 'engine_cc',    'سعة المحرك (سي سي)', 'number', false, true, 11, NULL),
  ('tuk-tuks',    'brand',        'الماركة',     'select', true,  true, 10, '["باجاج", "تي في إس", "أخرى"]'),
  ('tuk-tuks',    'license_status', 'الترخيص',   'select', true,  true, 11, '["مرخص", "غير مرخص"]'),
  ('trucks',      'truck_type',   'نوع المركبة', 'select', true,  true, 10, '["ربع نقل", "نصف نقل", "جامبو", "تريلا", "ميكروباص", "أخرى"]'),
  ('trucks',      'load_capacity_tons', 'الحمولة (طن)', 'number', false, true, 11, NULL),

  -- ── Goods (shared) ──────────────────────────────────────────────
  ('goods', 'condition', 'الحالة', 'select', true, true, 1, '["جديد", "مستعمل - كالجديد", "مستعمل - جيد", "مستعمل - مقبول"]'),
  ('electronics', 'device_type', 'نوع الجهاز', 'select', true,  true, 10, '["موبايل", "لابتوب", "تابلت", "تلفزيون", "كاميرا", "إكسسوارات", "أخرى"]'),
  ('electronics', 'brand',       'الماركة',    'text',   false, true, 11, NULL),
  ('furniture',   'furniture_type', 'نوع الأثاث', 'select', true, true, 10, '["غرفة نوم", "صالون وأنتريه", "سفرة", "مطبخ", "أثاث مكتبي", "أخرى"]'),
  ('furniture',   'material',    'الخامة',     'select', false, true, 11, '["خشب", "معدن", "بلاستيك", "أخرى"]'),
  ('fashion',     'item_type',   'النوع',      'select', true,  true, 10, '["ملابس رجالي", "ملابس حريمي", "ملابس أطفال", "أحذية", "حقائب", "إكسسوارات"]'),
  ('fashion',     'size',        'المقاس',     'text',   false, true, 11, NULL),
  ('appliances',  'appliance_type', 'نوع الجهاز', 'select', true, true, 10, '["ثلاجة", "غسالة", "بوتاجاز", "تكييف", "سخان", "ميكروويف", "أخرى"]'),
  ('appliances',  'brand',       'الماركة',    'text',   false, true, 11, NULL),
  ('appliances',  'warranty',    'عليه ضمان',  'boolean', false, true, 12, NULL),
  ('sports',      'item_type',   'النوع',      'select', true,  true, 10, '["أجهزة رياضية", "دراجات", "ملابس رياضية", "ألعاب", "أخرى"]'),
  ('kids',        'item_type',   'النوع',      'select', true,  true, 10, '["عربيات أطفال", "ألعاب", "ملابس", "سرير ومستلزمات نوم", "أخرى"]'),
  ('kids',        'age_range',   'العمر المناسب', 'select', false, true, 11, '["0-1 سنة", "1-3 سنوات", "3-6 سنوات", "6 سنوات فأكثر"]'),
  ('books',       'book_type',   'النوع',      'select', true,  true, 10, '["كتب دراسية", "روايات", "كتب دينية", "مستلزمات مكتبية", "أخرى"]'),
  ('books',       'language',    'اللغة',      'select', false, true, 11, '["عربي", "إنجليزي", "فرنسي", "أخرى"]')
) AS v(slug, field_name, label_ar, field_type, is_required, is_searchable, sort_order, options)
JOIN public.categories c ON c.slug = v.slug
ON CONFLICT (category_id, field_name) DO UPDATE
  SET label_ar = EXCLUDED.label_ar, field_type = EXCLUDED.field_type, is_required = EXCLUDED.is_required,
      is_searchable = EXCLUDED.is_searchable, sort_order = EXCLUDED.sort_order, options = EXCLUDED.options;
