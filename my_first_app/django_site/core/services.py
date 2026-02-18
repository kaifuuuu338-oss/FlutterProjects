import os
import httpx

FASTAPI_BASE = os.getenv('FASTAPI_BASE_URL', 'http://127.0.0.1:8000')


async def submit_screening(payload):
    url = f"{FASTAPI_BASE}/screening/submit"
    async with httpx.AsyncClient(timeout=20.0) as client:
        r = await client.post(url, json=payload)
        r.raise_for_status()
        return r.json()


def submit_screening_sync(payload):
    url = f"{FASTAPI_BASE}/screening/submit"
    r = httpx.post(url, json=payload, timeout=20.0)
    r.raise_for_status()
    return r.json()


def fetch_monitoring_sync(role='state', location_id=''):
    url = f"{FASTAPI_BASE}/analytics/monitoring"
    r = httpx.get(url, params={'role': role, 'location_id': location_id}, timeout=20.0)
    r.raise_for_status()
    return r.json()


def fetch_impact_sync(role='state', location_id=''):
    url = f"{FASTAPI_BASE}/analytics/impact"
    r = httpx.get(url, params={'role': role, 'location_id': location_id}, timeout=20.0)
    r.raise_for_status()
    return r.json()
