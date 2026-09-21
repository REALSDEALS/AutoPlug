rem Launcher script for reloadAudioDriver.ps1.

@echo off
rem If UAC rights are needed, then it will ask for that if UAC rights are applied fltmc will succeed and proceed with related actions:
fltmc >nul 2>&1
if errorlevel 1 (
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0reloadAudioDriver.ps1"
echo.
pause
