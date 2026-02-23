# PowerShell Profile Setup for Python
# Run this in PowerShell to load helper commands

# Create helpful function to start backend
function Start-Backend {
    Set-Location "C:\FlutterProjects\my_first_app\backend"
    Write-Host "Starting backend on http://127.0.0.1:8000..." -ForegroundColor Green
    python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
}

# Create helpful function to start flutter
function Start-Flutter {
    Set-Location "C:\FlutterProjects\my_first_app"
    Write-Host "Starting Flutter on http://localhost:5000..." -ForegroundColor Green
    flutter run -d chrome --web-hostname=localhost --web-port=5000
}

Write-Host "PowerShell setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Available commands:" -ForegroundColor Cyan
Write-Host "  Start-Backend       - Start the backend server" -ForegroundColor Yellow
Write-Host "  Start-Flutter       - Start the Flutter app" -ForegroundColor Yellow
