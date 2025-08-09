@echo off
title kaosFWD Booster - Debug Mode
echo =========================================
echo   AVVIO IN MODALITA' DEBUG
echo =========================================
echo.

REM Avvia PowerShell con la console visibile e debug attivo
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\djkao\Documents\kaosFWD Booster\kaosFWD-Booster.ps1"

echo.
echo =========================================
echo   SCRIPT TERMINATO
echo   Premi un tasto per chiudere...
echo =========================================
pause >nul
