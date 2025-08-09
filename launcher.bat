@echo off
cd /d "%~dp0"

:: Nasconde la finestra del terminale e avvia PowerShell in modalità nascosta
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "kaosFWD-Booster.ps1"

:: Se il processo PowerShell termina con errore, mostra il terminale per debug
if %ERRORLEVEL% neq 0 (
    echo.
    echo =========================================
    echo   ERRORE DURANTE L'AVVIO DEL BOOSTER
    echo =========================================
    echo.
    echo Si e' verificato un errore. Riprovando con terminale visibile per debug...
    echo.
    pause
    powershell.exe -ExecutionPolicy Bypass -File "kaosFWD-Booster.ps1"
    pause
)