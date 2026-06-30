
INSERT INTO category_fields (category_id, field_name, label_ar, field_type, is_required, sort_order, options)
VALUES 
(2, 'job_type', 'نوع الوظيفة', 'select', true, 1, '["دوام كامل", "دوام جزئي", "فريلانس", "تدريب"]'::jsonb),
(2, 'experience_required', 'الخبرة المطلوبة', 'select', false, 2, '["بدون خبرة", "أقل من سنة", "1-3 سنوات", "3-5 سنوات", "أكثر من 5 سنوات"]'::jsonb)
ON CONFLICT DO NOTHING;


INSERT INTO category_fields (category_id, field_name, label_ar, field_type, is_required, sort_order, options)
VALUES 
(3, 'property_type', 'نوع العقار', 'select', true, 1, '["شقة", "فيلا", "دوبلكس", "محل تجاري", "مكتب", "أرض", "أخرى"]'::jsonb),
(3, 'area_sqm', 'المساحة (متر مربع)', 'number', true, 2, null),
(3, 'rooms', 'عدد الغرف', 'select', false, 3, '["استوديو", "1", "2", "3", "4", "5+"]'::jsonb),
(3, 'furnished', 'مفروشة', 'boolean', false, 4, null)
ON CONFLICT DO NOTHING;


INSERT INTO category_fields (category_id, field_name, label_ar, field_type, is_required, sort_order, options)
VALUES 
(4, 'brand', 'الماركة', 'select', true, 1, '["تويوتا", "هيونداي", "كيا", "نيسان", "شيفروليه", "فيات", "بيجو", "رينو", "أخرى"]'::jsonb),
(4, 'year', 'سنة الصنع', 'number', true, 2, null),
(4, 'mileage', 'عداد الكيلومترات', 'number', false, 3, null),
(4, 'condition', 'حالة السيارة', 'select', true, 4, '["ممتاز", "جيد جداً", "جيد", "يحتاج صيانة"]'::jsonb)
ON CONFLICT DO NOTHING;
