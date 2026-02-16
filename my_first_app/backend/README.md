# ECD FastAPI Backend

This backend loads your trained `.pkl` model and serves:

- `POST /auth/login`
- `POST /screening/submit`
- `POST /referral/create`
- `GET /health`

## 1) Setup

From project root:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

## 2) Model files

Model files are expected at:

`backend/model_assets/model/trained_models`

If you keep them elsewhere, set:

```powershell
$env:ECD_MODEL_DIR="C:\path\to\trained_models"
```

## 3) Run API

```powershell
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Health check:

`http://127.0.0.1:8000/health`

## 4) Flutter app config

In Flutter constants set base URL:

`http://127.0.0.1:8000`

Now flow works:

`login -> screening -> AI risk -> referral`
