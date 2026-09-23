@echo off
echo Starting Offline Photo Organizer...
echo.
echo The app will open in your browser at:
echo http://localhost:8501
echo.
echo Press Ctrl+C to stop the server.
echo.
streamlit run app.py --server.headless true
pause
