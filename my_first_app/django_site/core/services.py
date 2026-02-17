import os
import httpx

FASTAPI_BASE = os.getenv('FASTAPI_BASE_URL', 'http://localhost:5000')

async def fetch_children():
    url = f"{FASTAPI_BASE}/children"
    async with httpx.AsyncClient() as client:
        r = await client.get(url)
        r.raise_for_status()
        return r.json()

async def submit_screening(payload):
    url = f"{FASTAPI_BASE}/screenings"
    async with httpx.AsyncClient() as client:
        r = await client.post(url, json=payload)
        r.raise_for_status()
        return r.json()

# Synchronous helpers (for simple pages)
def fetch_children_sync():
    url = f"{FASTAPI_BASE}/children"
    r = httpx.get(url)
    r.raise_for_status()
    return r.json()

def submit_screening_sync(payload):
    url = f"{FASTAPI_BASE}/screenings"
    r = httpx.post(url, json=payload)
    r.raise_for_status()
    return r.json()
