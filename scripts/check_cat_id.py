import os
import requests
import json

URL = "https://fgvjjtbtlzjpzaqypzmz.supabase.co/rest/v1"
ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "<YOUR_ANON_KEY>")
headers = {"apikey": ANON_KEY, "Authorization": f"Bearer {ANON_KEY}"}

res = requests.get(f"{URL}/categories?select=id&limit=1", headers=headers)
print(res.json())
