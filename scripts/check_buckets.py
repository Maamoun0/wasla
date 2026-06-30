import os
import requests

URL = "https://fgvjjtbtlzjpzaqypzmz.supabase.co/storage/v1"
ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "<YOUR_ANON_KEY>")

headers = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {ANON_KEY}",
}

res = requests.get(f"{URL}/bucket", headers=headers)
print(res.status_code, res.text)
