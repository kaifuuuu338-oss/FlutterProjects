Django frontend to consume existing FastAPI backend

This scaffold implements Option C: a Django website that calls your existing FastAPI endpoints (no DB changes).

Quick start (from this folder):

1. Create virtualenv and install:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

2. Copy `.env.example` to `.env` and set `FASTAPI_BASE_URL`.
3. Run Django dev server:

```bash
python manage.py runserver
```

Next steps:
- Implement `core/services.py` endpoints to match your FastAPI routes.
- Replace template placeholders with the production UI.
