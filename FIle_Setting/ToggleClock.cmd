@echo off
setlocal EnableDelayedExpansion

:: Kiem tra quyen admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Dang yeu cau quyen Administrator...
    powershell -Command "Start-Process '%~f0' -Verb runAs"
    exit /b
)
:: Kiem tra gia tri HideClock trong Registry
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideClock >nul 2>&1
if %errorlevel%==1 (
    set hideClock=0
) else (
    for /f "tokens=3" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideClock') do (
        set hideClock=%%a
    )
)

:: Dao nguoc gia tri HideClock
if "!hideClock!"=="0x1" (
    echo Dang bat lai dong ho...
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideClock /t REG_DWORD /d 0 /f
) else (
    echo Dang an dong ho...
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideClock /t REG_DWORD /d 1 /f
)

:: Khoi dong lai Explorer
echo Dang khoi dong lai Explorer...
taskkill /f /im explorer.exe >nul
start explorer.exe

echo Hoan tat.
pause
