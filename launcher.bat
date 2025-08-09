@echo off
cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -File "kaosFWD-Booster.ps1"
pause