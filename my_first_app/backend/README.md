# ECD FastAPI Backend

This backend serves:

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

## 2) PostgreSQL configuration

Create a PostgreSQL database (example: `ecd_data`) and set one of:

```powershell
$env:ECD_DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:5432/ecd_data"
```

or

```powershell
$env:DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:5432/ecd_data"
```

If neither is set, backend defaults to:

`postgresql://postgres:postgres@127.0.0.1:5432/ecd_data`

## 3) Model files

Model files are expected at:

`backend/model_assets/model/trained_models`

If you keep them elsewhere, set:

```powershell
$env:ECD_MODEL_DIR="C:\path\to\trained_models"
```

## 4) Run API

```powershell
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Health check:

`http://127.0.0.1:8000/health`

## 5) Flutter app config

Set base URL to:

`http://127.0.0.1:8000`
