@echo off
REM Start Problem B Backend Server
setlocal
cd /d "%~dp0backend"
echo Starting backend on http://127.0.0.1:8001...
where python >nul 2>nul
if %errorlevel%==0 (
  python -m uvicorn app.main:app --host 127.0.0.1 --port 8001 --reload
) else (
  py -3 -m uvicorn app.main:app --host 127.0.0.1 --port 8001 --reload
)
pause
