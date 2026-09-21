rem Launcher script for generateBatteryReport.ps1.

@echo off
rem Running a bypass execution policy for this run only to run the script:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0generateBatteryReport.ps1"
echo.
pause
