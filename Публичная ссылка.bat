@echo off
title PromoLov - public link
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tunnel.ps1"
echo.
pause
