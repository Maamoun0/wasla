import os
import requests
import json

URL = "https://fgvjjtbtlzjpzaqypzmz.supabase.co/rest/v1"
ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "<YOUR_ANON_KEY>")

headers = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {ANON_KEY}",
    "Content-Profile": "public",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

res = requests.get(f"{URL}/categories?select=id,name_ar,level", headers=headers)
categories = res.json()

payloads = []
for c in categories:
    name = c['name_ar']
    cid = c['id']
    lvl = c['level']
    
    if name == 'سباكة' and lvl == 2:
        payloads.extend([
            {"category_id": cid, "field_name": "service_type", "label_ar": "نوع الخدمة", "field_type": "select", "is_required": True, "sort_order": 1, "options": ["تركيب", "صيانة", "كشف تسربات", "تسليك بالوعة", "أخرى"]},
            {"category_id": cid, "field_name": "experience_years", "label_ar": "سنوات الخبرة", "field_type": "number", "is_required": False, "sort_order": 2, "options": None}
        ])
    elif name == 'كهرباء' and lvl == 2:
        payloads.append(
            {"category_id": cid, "field_name": "service_type", "label_ar": "نوع الخدمة", "field_type": "select", "is_required": True, "sort_order": 1, "options": ["تركيب لوحة كهرباء", "صيانة", "تمديد أسلاك", "إصلاح عطل", "أخرى"]}
        )
    elif name == 'سيارات' and lvl == 1:
        payloads.extend([
            {"category_id": cid, "field_name": "brand", "label_ar": "الماركة", "field_type": "select", "is_required": True, "sort_order": 1, "options": ["تويوتا", "هيونداي", "كيا", "نيسان", "شيفروليه", "فيات", "بيجو", "رينو", "أخرى"]},
            {"category_id": cid, "field_name": "year", "label_ar": "سنة الصنع", "field_type": "number", "is_required": True, "sort_order": 2, "options": None},
            {"category_id": cid, "field_name": "mileage", "label_ar": "عداد الكيلومترات", "field_type": "number", "is_required": False, "sort_order": 3, "options": None},
            {"category_id": cid, "field_name": "condition", "label_ar": "حالة السيارة", "field_type": "select", "is_required": True, "sort_order": 4, "options": ["ممتاز", "جيد جداً", "جيد", "يحتاج صيانة"]}
        ])
    elif name == 'عقارات' and lvl == 1:
        payloads.extend([
            {"category_id": cid, "field_name": "property_type", "label_ar": "نوع العقار", "field_type": "select", "is_required": True, "sort_order": 1, "options": ["شقة", "فيلا", "دوبلكس", "محل تجاري", "مكتب", "أرض", "أخرى"]},
            {"category_id": cid, "field_name": "area_sqm", "label_ar": "المساحة (متر مربع)", "field_type": "number", "is_required": True, "sort_order": 2, "options": None},
            {"category_id": cid, "field_name": "rooms", "label_ar": "عدد الغرف", "field_type": "select", "is_required": False, "sort_order": 3, "options": ["استوديو", "1", "2", "3", "4", "5+"]},
            {"category_id": cid, "field_name": "furnished", "label_ar": "مفروشة", "field_type": "boolean", "is_required": False, "sort_order": 4, "options": None}
        ])
    elif name == 'إلكترونيات' and lvl == 1:
        payloads.extend([
            {"category_id": cid, "field_name": "device_type", "label_ar": "نوع الجهاز", "field_type": "select", "is_required": True, "sort_order": 1, "options": ["موبايل", "لابتوب", "تابلت", "شاشة", "طابعة", "كاميرا", "أخرى"]},
            {"category_id": cid, "field_name": "condition", "label_ar": "الحالة", "field_type": "select", "is_required": True, "sort_order": 2, "options": ["جديد", "مستعمل - ممتاز", "مستعمل - جيد", "يحتاج إصلاح"]}
        ])
    elif name == 'وظائف' and lvl == 1:
        payloads.extend([
            {"category_id": cid, "field_name": "experience_required", "label_ar": "الخبرة المطلوبة", "field_type": "select", "is_required": False, "sort_order": 2, "options": ["بدون خبرة", "أقل من سنة", "1-3 سنوات", "3-5 سنوات", "أكثر من 5 سنوات"]}
        ])

count = 0
for p in payloads:
    res = requests.post(f"{URL}/category_fields", headers=headers, json=p)
    if res.status_code == 201:
        count += 1
    else:
        print("ERROR:", res.status_code, res.text)

print(f"Successfully inserted {count} fields.")
