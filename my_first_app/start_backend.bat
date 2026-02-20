@echo off
REM Start Problem B Backend Server
cd /d "C:\manfoosah\FlutterProjects\my_first_app\backend"
echo Starting backend on http://127.0.0.1:8000...
"C:\Users\manfo\AppData\Local\Programs\Python\Python312\python.exe" -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
pause
