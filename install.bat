@echo off
echo ============================================
echo   Offline Photo Organizer - Setup
echo ============================================
echo.

echo [1/2] Installing dependencies...
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo [2/2] Setting up models...
python setup.py
if %errorlevel% neq 0 (
    echo WARNING: Some models may not have downloaded
)

echo.
echo ============================================
echo   Setup Complete!
echo ============================================
echo.
echo To start the app, run:
echo   streamlit run app.py
echo.
echo Or double-click: run_app.bat
echo.
pause
