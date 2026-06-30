import os
import requests
import json
import sys
import codecs

sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())

URL = "https://fgvjjtbtlzjpzaqypzmz.supabase.co/rest/v1"
ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "<YOUR_ANON_KEY>")

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
