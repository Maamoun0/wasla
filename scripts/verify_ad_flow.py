import os
import requests
import json
import uuid
import time
import sys
import codecs

sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())

URL = "https://bizikadaucsyevdoagmm.supabase.co"
ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpemlrYWRhdWNzeWV2ZG9hZ21tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2MDUwNTUsImV4cCI6MjA5OTE4MTA1NX0.f-0cxoeh_h9r3PkJ1D_C0q7-JTFXg50zzrmY6enZG3Q")

print("1. Creating test user...")
email = f"test_publisher_{int(time.time())}@gmail.com"
pwd = "testpassword123"

auth_res = requests.post(
    f"{URL}/auth/v1/signup",
    headers={"apikey": ANON_KEY},
    json={"email": email, "password": pwd}
)
auth_data = auth_res.json()
token = auth_data.get("access_token")

if not token:
    print("Signup didn't return token. Attempting login...")
    auth_res = requests.post(
        f"{URL}/auth/v1/token?grant_type=password", 
        headers={"apikey": ANON_KEY}, 
        json={"email": email, "password": pwd}
    )
    auth_data = auth_res.json()
    token = auth_data.get("access_token")

if not token:
    print("FAILED TO GET TOKEN:", auth_data)
    sys.exit(1)

print(f"User authenticated successfully! Token preview: {token[:20]}...")

print("2. Fetching required references (category, city)...")
res_cats = requests.get(f"{URL}/rest/v1/categories?select=id,name_ar&level=eq.1&limit=1", headers={"apikey": ANON_KEY})
cat_id = res_cats.json()[0]['id']

res_cities = requests.get(f"{URL}/rest/v1/cities?select=id&limit=1", headers={"apikey": ANON_KEY})
city_id = res_cities.json()[0]['id']

print("3. Invoking 'create-ad' edge function...")
edge_url = f"{URL}/functions/v1/create-ad"
temp_id = str(uuid.uuid4())

payload = {
    "temp_draft_id": temp_id,
    "category_id": cat_id,
    "title": "إعلان تجريبي من التيست الأوتوماتيكي",
    "description": "هذا الإعلان تم إنشاؤه بواسطة سكريبت البايثون لاختبار دورة نشر الإعلانات الكاملة والتأكد من أنها تعمل بكفاءة.",
    "ad_type": "offering",
    "price": 1500,
    "price_type": "fixed",
    "city_id": city_id,
    "images": [
        {"url": "https://picsum.photos/400/300", "is_primary": True, "sort_order": 0}
    ],
    "dynamic_fields": {
        "condition": "جديد"
    }
}

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

func_res = requests.post(edge_url, headers=headers, json=payload)
print("Response Status:", func_res.status_code)
print("Response Body:", func_res.text)

if func_res.status_code != 200:
    print("Edge function failed!")
    sys.exit(1)

func_data = func_res.json()
ad_id = func_data.get("ad_id")
if not ad_id:
    print("No ad_id returned in success response!")
    sys.exit(1)

print(f"4. Verifying ad {ad_id} in active feed...")
time.sleep(1) # wait for the transaction to fully commit
ads_res = requests.get(
    f"{URL}/rest/v1/ads?select=id,title,status&id=eq.{ad_id}", 
    headers={
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}"
    }
)

print("DB Check Status:", ads_res.status_code)
print("DB Check Result:", ads_res.json())

if ads_res.status_code == 200 and len(ads_res.json()) > 0:
    print("SUCCESS! The ad was created and exists in the database.")
else:
    print("FAILURE: Ad not found in database or not active.")
