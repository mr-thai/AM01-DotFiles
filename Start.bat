@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Main.ps1"
endlocal
pause
