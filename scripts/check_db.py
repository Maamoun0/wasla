import os
import requests
import json
import sys
import codecs

sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())

URL = "https://bizikadaucsyevdoagmm.supabase.co/rest/v1"
ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpemlrYWRhdWNzeWV2ZG9hZ21tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2MDUwNTUsImV4cCI6MjA5OTE4MTA1NX0.f-0cxoeh_h9r3PkJ1D_C0q7-JTFXg50zzrmY6enZG3Q")

headers = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {ANON_KEY}",
    "Content-Profile": "public"
}

def check_categories():
    res = requests.get(f"{URL}/categories?select=*", headers=headers)
    print("CATEGORIES STATUS:", res.status_code)
    if res.status_code == 200:
        print("COUNT:", len(res.json()))
    else:
        print("ERROR:", res.text)

def check_category_fields():
    res = requests.get(f"{URL}/category_fields?select=*", headers=headers)
    print("CATEGORY_FIELDS STATUS:", res.status_code)
    if res.status_code == 200:
        print("COUNT:", len(res.json()))
    else:
        print("ERROR:", res.text)

def check_field_options():
    res = requests.get(f"{URL}/field_options?select=*", headers=headers)
    print("FIELD_OPTIONS STATUS:", res.status_code)
    if res.status_code == 200:
        print("COUNT:", len(res.json()))
    else:
        print("ERROR:", res.text)

if __name__ == "__main__":
    check_categories()
    check_category_fields()
    check_field_options()
