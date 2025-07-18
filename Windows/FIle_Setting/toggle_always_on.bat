@echo off
setlocal ENABLEEXTENSIONS

:: File trang thai de biet dang bat hay tat
set "stateFile=%~dp0always_on_state.txt"

:: Neu file ton tai thi dang bat -> tat
if exist "%stateFile%" (
    echo [TAT] Chuyen ve che do mac dinh: 10 phut tat man hinh, 15 phut ngu may...
    powercfg /change monitor-timeout-ac 10
    powercfg /change monitor-timeout-dc 10
    powercfg /change standby-timeout-ac 15
    powercfg /change standby-timeout-dc 15
    del "%stateFile%"
) else (
    echo [BAT] Bat che do luon sang man hinh, khong tat may...
    powercfg /change monitor-timeout-ac 0
    powercfg /change monitor-timeout-dc 0
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
    echo on > "%stateFile%"
)

echo.
echo Hoan tat. Nhan phim bat ky de thoat.
pause >nul
