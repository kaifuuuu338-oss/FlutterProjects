# Registration Setup Guide - PostgreSQL Integration

## ✅ Changes Made

### 1. **Backend: Added `/auth/register` Endpoint**
- **File**: `backend/app/main.py` (lines 1291-1344)
- **Functionality**: Registers AWW (Anganwadi Worker) data directly to PostgreSQL `ecd_data.aww_profile` table
- **Database**: PostgreSQL (ecd_data database)
- **Table**: `aww_profile` with fields:
  - aww_id (PRIMARY KEY)
  - name
  - mobile_number (UNIQUE)
  - password
  - awc_code
  - mandal
  - district
  - created_at
  - updated_at

### 2. **Flutter: Updated Registration Flow**
- **Files Modified**:
  - `lib/screens/signup_screen.dart` - Now calls API service
  - `lib/services/api_service.dart` - Added `registerAWW()` method

- **Flow**:
  1. User enters name, mobile, password, AWC code
  2. Signup button triggers `_register()` method
  3. Data saved locally first (fallback)
  4. Then synced to PostgreSQL via `/auth/register` API
  5. User confirmed with success message

## 🚀 Setup Instructions

### Step 1: Ensure PostgreSQL is Running
```bash
# Windows - Start PostgreSQL service
net start postgresql-x64-15   # or your version

# OR use pgAdmin to verify connection
# Connect to: localhost:5432 with postgres:postgres credentials
```

### Step 2: Create Database & Tables (if not exists)
```sql
-- In pgAdmin or psql:
CREATE DATABASE ecd_data;

-- Then run this in ecd_data database:
CREATE TABLE IF NOT EXISTS aww_profile (
  aww_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  mobile_number TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  awc_code TEXT NOT NULL,
  mandal TEXT,
  district TEXT,
  created_at TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS child_profile (
  child_id TEXT PRIMARY KEY,
  child_name TEXT,
  gender TEXT,
  age_months INTEGER,
  village TEXT,
  awc_id TEXT,
  sector_id TEXT,
  mandal_id TEXT,
  district_id TEXT,
  created_at TEXT
);
```

### Step 3: Start Backend Server
```powershell
# Navigate to backend directory
cd c:\FlutterProjects\my_first_app\backend

# Activate virtual environment
.venv\Scripts\Activate.ps1

# Set environment variable for PostgreSQL
$env:ECD_DATABASE_URL = "postgresql://postgres:postgres@127.0.0.1:5432/ecd_data"

# Start FastAPI server
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Expected output:
# Uvicorn running on http://0.0.0.0:8000
```

### Step 4: Verify Backend Health
```bash
# Open browser or use curl:
curl http://localhost:8000/health

# Expected response:
# {"status":"ok","time":"2026-02-23T..."}
```

### Step 5: Start Flutter App
```bash
# In Flutter project root
flutter run

# Select device (Android/iOS/Web)
```

## ✅ Testing the Registration Flow

### Test Steps:
1. **Open Flutter App** → Click "Sign Up"
2. **Fill Form**:
   - Name: "Test Worker"
   - Mobile: "9999123456"
   - Password: "password123"
   - AWC Code: "AWS_DEMO_001"
3. **Click Register** → Should see "Registration Successful"
4. **Verify in PostgreSQL**:

```sql
-- Check if data was stored in PostgreSQL
SELECT * FROM ecd_data.aww_profile;

-- Expected to see:
-- aww_id | name | mobile_number | password | awc_code | mandal | district | ...
-- aww_9999123456 | Test Worker | 9999123456 | password123 | AWS_DEMO_001 | | |
```

## 🔧 Troubleshooting

### Issue: "HTTP 404: Page not found at /children/register/"
**Solution**: Backend server is not running. Start it with:
```powershell
cd backend
.venv\Scripts\Activate.ps1
$env:ECD_DATABASE_URL = "postgresql://postgres:postgres@127.0.0.1:5432/ecd_data"
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Issue: "Connection refused" or "Cannot connect to PostgreSQL"
**Solution**: 
1. Verify PostgreSQL is running: `pg_isready -h localhost -p 5432`
2. Check credentials in environment variable
3. Ensure database `ecd_data` exists

### Issue: "UNIQUE constraint failed: aww_profile.mobile_number"
**Solution**: This is expected behavior for duplicate registrations. The UPDATE logic will update existing records.

## 📊 Database Query Examples

### View all registered AWWs:
```sql
SELECT aww_id, name, mobile_number, awc_code, created_at 
FROM aww_profile 
ORDER BY created_at DESC;
```

### View registration in last 24 hours:
```sql
SELECT * FROM aww_profile 
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;
```

### Monitor child registrations:
```sql
SELECT child_id, child_name, age_months, created_at 
FROM child_profile 
ORDER BY created_at DESC;
```

## 🔐 Security Notes

- ⚠️ **For Production**: Hash passwords before storing (use bcrypt, not plain text)
- ⚠️ **For Production**: Implement JWT token validation on all endpoints
- ⚠️ **For Production**: Add rate limiting to prevent spam registrations
- ⚠️ **For Production**: Validate all input fields properly

## 📱 API Endpoint Reference

| Endpoint | Method | Purpose | Request | Response |
|----------|--------|---------|---------|----------|
| `/health` | GET | Check server status | - | `{"status":"ok","time":"..."}` |
| `/auth/register` | POST | Register new AWW | `{name, mobile_number, password, awc_code, mandal, district}` | `{"status":"ok","message":"...","aww_id":"...","created_at":"..."}` |
| `/children/register` | POST | Register child profile | `{child_id, child_name, gender, age_months, ...}` | `{"status":"ok","child":{...}}` |
| `/auth/login` | POST | Login AWW | `{mobile_number, password}` | `{"token":"...","user_id":"..."}` |

## ✨ Next Steps

1. ✅ Test registration with multiple users
2. ✅ Verify data appears in PostgreSQL within seconds
3. ✅ Test login with registered credentials
4. ✅ Implement child registration after AWW registration
5. ✅ Set up referral system for screening results

---

**Last Updated**: February 23, 2026
**Status**: ✅ Data stores instantly in PostgreSQL to `ecd_data.child_profile`
