@echo off
title PromoLov server
echo Starting PromoLov on http://localhost:8787/
echo The console shows the Network address for other devices.
echo Close the server window to stop the site.
start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
timeout /t 6 /nobreak >nul
start "" "http://localhost:8787/"
exit
