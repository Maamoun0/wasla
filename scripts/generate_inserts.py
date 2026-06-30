import os
import requests
import json
import codecs
import sys

sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())

URL = "https://fgvjjtbtlzjpzaqypzmz.supabase.co/rest/v1"
ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "<YOUR_ANON_KEY>")

headers = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {ANON_KEY}",
    "Content-Profile": "public",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

# Fetch categories
res = requests.get(f"{URL}/categories?select=id,name_ar,level,parent_id", headers=headers)
if res.status_code != 200:
    print("Failed to get categories:", res.text)
    sys.exit(1)

categories = res.json()

insert_statements = []

for c in categories:
    name = c['name_ar']
    cid = c['id']
    lvl = c['level']
    
    # We will generate SQL inserts based on the prompt's examples
    
    if name == 'سباكة' and lvl == 2:
        insert_statements.append(f"""
INSERT INTO category_fields (category_id, field_name, label_ar, field_type, is_required, sort_order, options)
VALUES 
({cid}, 'service_type', 'نوع الخدمة', 'select', true, 1, '["تركيب", "صيانة", "كشف تسربات", "تسليك بالوعة", "أخرى"]'::jsonb),
({cid}, 'experience_years', 'سنوات الخبرة', 'number', false, 2, null)
ON CONFLICT DO NOTHING;
""")

    elif name == 'كهرباء' and lvl == 2:
        insert_statements.append(f"""
INSERT INTO category_fields (category_id, field_name, label_ar, field_type, is_required, sort_order, options)
VALUES 
({cid}, 'service_type', 'نوع الخدمة', 'select', true, 1, '["تركيب لوحة كهرباء", "صيانة", "تمديد أسلاك", "إصلاح عطل", "أخرى"]'::jsonb)
ON CONFLICT DO NOTHING;
""")
    elif name == 'سيارات' and lvl == 1:
        insert_statements.append(f"""
INSERT INTO category_fields (category_id, field_name, label_ar, field_type, is_required, sort_order, options)
VALUES 
({cid}, 'brand', 'الماركة', 'select', true, 1, '["تويوتا", "هيونداي", "كيا", "نيسان", "شيفروليه", "فيات", "بيجو", "رينو", "أخرى"]'::jsonb),
({cid}, 'year', 'سنة الصنع', 'number', true, 2, null),
({cid}, 'mileage', 'عداد الكيلومترات', 'number', false, 3, null),
({cid}, 'condition', 'حالة السيارة', 'select', true, 4, '["ممتاز", "جيد جداً", "جيد", "يحتاج صيانة"]'::jsonb)
ON CONFLICT DO NOTHING;
""")
    elif name == 'عقارات' and lvl == 1:
        insert_statements.append(f"""
INSERT INTO category_fields (category_id, field_name, label_ar, field_type, is_required, sort_order, options)
VALUES 
({cid}, 'property_type', 'نوع العقار', 'select', true, 1, '["شقة", "فيلا", "دوبلكس", "محل تجاري", "مكتب", "أرض", "أخرى"]'::jsonb),
({cid}, 'area_sqm', 'المساحة (متر مربع)', 'number', true, 2, null),
({cid}, 'rooms', 'عدد الغرف', 'select', false, 3, '["استوديو", "1", "2", "3", "4", "5+"]'::jsonb),
({cid}, 'furnished', 'مفروشة', 'boolean', false, 4, null)
ON CONFLICT DO NOTHING;
""")
    elif name == 'إلكترونيات' and lvl == 1:
        insert_statements.append(f"""
INSERT INTO category_fields (category_id, field_name, label_ar, field_type, is_required, sort_order, options)
VALUES 
({cid}, 'device_type', 'نوع الجهاز', 'select', true, 1, '["موبايل", "لابتوب", "تابلت", "شاشة", "طابعة", "كاميرا", "أخرى"]'::jsonb),
({cid}, 'condition', 'الحالة', 'select', true, 2, '["جديد", "مستعمل - ممتاز", "مستعمل - جيد", "يحتاج إصلاح"]'::jsonb)
ON CONFLICT DO NOTHING;
""")
    elif name == 'وظائف' and lvl == 1:
        insert_statements.append(f"""
INSERT INTO category_fields (category_id, field_name, label_ar, field_type, is_required, sort_order, options)
VALUES 
({cid}, 'job_type', 'نوع الوظيفة', 'select', true, 1, '["دوام كامل", "دوام جزئي", "فريلانس", "تدريب"]'::jsonb),
({cid}, 'experience_required', 'الخبرة المطلوبة', 'select', false, 2, '["بدون خبرة", "أقل من سنة", "1-3 سنوات", "3-5 سنوات", "أكثر من 5 سنوات"]'::jsonb)
ON CONFLICT DO NOTHING;
""")

with open('seed_category_fields.sql', 'w', encoding='utf-8') as f:
    f.write("\n".join(insert_statements))

print(f"Generated {len(insert_statements)} insert statements. SQL saved to seed_category_fields.sql")

# Let's see if we can insert via REST API using anonymous key (unlikely)
payloads = []
if len(insert_statements) > 0:
    for c in categories:
        name = c['name_ar']
        cid = c['id']
        lvl = c['level']
        
        if name == 'وظائف' and lvl == 1:
            payloads.append({
                "category_id": cid,
                "field_name": "job_type",
                "label_ar": "نوع الوظيفة",
                "field_type": "select",
                "is_required": True,
                "sort_order": 1,
                "options": ["دوام كامل", "دوام جزئي", "فريلانس", "تدريب"]
            })

if len(payloads) > 0:
    res = requests.post(f"{URL}/category_fields", headers=headers, json=payloads[0])
    print("TEST INSERT STATUS:", res.status_code, res.text)
