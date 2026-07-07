@echo off
REM start.bat — one-command setup & start
REM Usage: start.bat           (port 8000)
REM        start.bat 8080      (custom port)

set PORT=%1
if "%PORT%"=="" set PORT=8000

REM Auto-create venv if missing
if not exist venv\Scripts\activate (
    echo Creating virtual environment...
    python -m venv venv
)

call venv\Scripts\activate

REM Auto-install if missing
if not exist venv\installed (
    echo Installing dependencies...
    pip install -r requirements.txt -q
    echo installed > venv\installed
)

echo Applying migrations...
python manage.py migrate > nul 2>&1

REM Build static files if manifest missing
if not exist staticfiles\staticfiles.json (
    echo Building static files...
    python manage.py collectstatic --no-input --quiet > nul 2>&1
)

REM Load seed data if empty
python -c "import os,sys; os.environ['DJANGO_SETTINGS_MODULE']='fitness_hub.settings'; sys.path.insert(0,'.'); import django; django.setup(); from store.models import Product; exit(0 if Product.objects.count()>0 else 1)" > nul 2>&1
if errorlevel 1 (
    echo Loading seed data (446 products)...
    python manage.py loaddata fixtures/seed_data.json --quiet > nul 2>&1
)

echo Starting server...
start /B python manage.py runserver 0.0.0.0:%PORT% > nul 2>&1
timeout /t 2 /nobreak > nul
echo.
echo   Server is ready!
echo   Open http://127.0.0.1:%PORT% or http://localhost:%PORT% in your browser
echo.
echo   To stop: taskkill /F /IM python.exe 2^>nul
echo.
