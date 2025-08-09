param()

# Controllo privilegi amministratore
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltinRole] "Administrator"
)) {
    Write-Host "🔐 Richiedendo privilegi amministratore..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Configurazione
$AppName = "kaosFWD-Booster"
$AppVersion = "v2.0"
$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$TargetDir = Join-Path $env:ProgramData $AppName

# Percorso Desktop (gestisce OneDrive)
$DesktopPath = [Environment]::GetFolderPath("Desktop")
if ($DesktopPath -match "OneDrive") {
    $DesktopPath = "$env:UserProfile\Desktop"
}

$ShortcutPath = Join-Path $DesktopPath "$AppName.lnk"

# Banner di installazione
Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                      ║" -ForegroundColor Cyan  
Write-Host "║              🚀 kaosFWD Booster $AppVersion              ║" -ForegroundColor Cyan
Write-Host "║                                                      ║" -ForegroundColor Cyan
Write-Host "║           Gaming Performance Optimizer              ║" -ForegroundColor Cyan
Write-Host "║                                                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔧 Avvio procedura di installazione..." -ForegroundColor Green
Write-Host ""

# Verifica file necessari
$RequiredFiles = @("gui.xaml", "kaosFWD-Booster.ps1", "launcher.bat")
$MissingFiles = @()

foreach ($file in $RequiredFiles) {
    $filePath = Join-Path $SourceDir $file
    if (-not (Test-Path $filePath)) {
        $MissingFiles += $file
    }
}

if ($MissingFiles.Count -gt 0) {
    Write-Host "❌ ERRORE: File mancanti!" -ForegroundColor Red
    Write-Host "File mancanti: $($MissingFiles -join ', ')" -ForegroundColor Red
    Write-Host ""
    Read-Host "Premi INVIO per uscire"
    exit 1
}

Write-Host "✅ Verifica file completata - Tutti i file necessari sono presenti" -ForegroundColor Green

# Backup versione precedente se esiste
if (Test-Path $TargetDir) {
    Write-Host "🔄 Rilevata installazione precedente..." -ForegroundColor Yellow
    
    $BackupDir = "$TargetDir.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    try {
        Move-Item $TargetDir $BackupDir -Force
        Write-Host "💾 Backup creato: $BackupDir" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Impossibile creare backup, rimozione diretta..." -ForegroundColor Yellow
        Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Creazione directory di destinazione
Write-Host "📁 Creazione directory di installazione..." -ForegroundColor Cyan
try {
    New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null
    Write-Host "✅ Directory creata: $TargetDir" -ForegroundColor Green
} catch {
    Write-Host "❌ ERRORE: Impossibile creare la directory di destinazione" -ForegroundColor Red
    Write-Host "Errore: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Premi INVIO per uscire"
    exit 1
}

# Copia dei file
Write-Host "📋 Copia dei file dell'applicazione..." -ForegroundColor Cyan
try {
    $FilesToCopy = Get-ChildItem $SourceDir -File | Where-Object { 
        $_.Name -notlike "install*" -and 
        $_.Name -notlike "uninstall*" -and
        $_.Name -ne "README.md"
    }
    
    foreach ($file in $FilesToCopy) {
        Copy-Item $file.FullName $TargetDir -Force
        Write-Host "  ✓ $($file.Name)" -ForegroundColor Gray
    }
    
    Write-Host "✅ Copia file completata" -ForegroundColor Green
} catch {
    Write-Host "❌ ERRORE durante la copia dei file" -ForegroundColor Red
    Write-Host "Errore: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Premi INVIO per uscire"
    exit 1
}

# Verifica/Creazione launcher migliorato
$LauncherFile = Join-Path $TargetDir "launcher.bat"
$LauncherContent = @"
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
"@

Write-Host "🔧 Creazione launcher ottimizzato..." -ForegroundColor Cyan
try {
    $LauncherContent | Out-File $LauncherFile -Encoding ASCII -Force
    Write-Host "✅ Launcher creato con gestione errori avanzata" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Errore nella creazione del launcher: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Creazione collegamento sul Desktop
Write-Host "🔗 Creazione collegamento sul Desktop..." -ForegroundColor Cyan
try {
    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
    }
    
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $LauncherFile
    $Shortcut.WorkingDirectory = $TargetDir
    $Shortcut.WindowStyle = 1
    $Shortcut.IconLocation = "powershell.exe,0"
    $Shortcut.Description = "kaosFWD Gaming Booster $AppVersion - Ottimizzatore performance gaming"
    $Shortcut.Save()
    
    Write-Host "✅ Collegamento creato: $ShortcutPath" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Attenzione: Errore durante la creazione del collegamento" -ForegroundColor Yellow
    Write-Host "Errore: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "💡 Puoi eseguire manualmente: $LauncherFile" -ForegroundColor Cyan
}

# Configurazione permessi (opzionale)
Write-Host "🔐 Configurazione permessi..." -ForegroundColor Cyan
try {
    $acl = Get-Acl $TargetDir
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
        "FullControl",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
    )
    $acl.SetAccessRule($accessRule)
    Set-Acl $TargetDir $acl
    Write-Host "✅ Permessi configurati correttamente" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Avviso: Impossibile configurare i permessi avanzati" -ForegroundColor Yellow
}

# Pulizia file temporanei
Write-Host "🧹 Pulizia file temporanei..." -ForegroundColor Cyan
try {
    # Rimuovi eventuali file .tmp o di backup vecchi
    Get-ChildItem "$env:ProgramData\kaosFWD-Booster.backup.*" -ErrorAction SilentlyContinue | 
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-7) } | 
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "✅ Pulizia completata" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Pulizia parziale completata" -ForegroundColor Yellow
}

# Test di funzionamento base
Write-Host "🧪 Test configurazione..." -ForegroundColor Cyan
try {
    $GuiFile = Join-Path $TargetDir "gui.xaml"
    $MainScript = Join-Path $TargetDir "kaosFWD-Booster.ps1"
    
    if ((Test-Path $GuiFile) -and (Test-Path $MainScript) -and (Test-Path $LauncherFile)) {
        Write-Host "✅ Tutti i componenti principali sono presenti" -ForegroundColor Green
    } else {
        throw "Componenti mancanti dopo l'installazione"
    }
} catch {
    Write-Host "❌ ATTENZIONE: Test di configurazione fallito" -ForegroundColor Red
    Write-Host "L'installazione potrebbe non essere completa" -ForegroundColor Red
}

# Sommario finale
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                      ║" -ForegroundColor Green
Write-Host "║          🎉 INSTALLAZIONE COMPLETATA! 🎉            ║" -ForegroundColor Green
Write-Host "║                                                      ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "📋 DETTAGLI INSTALLAZIONE:" -ForegroundColor Cyan
Write-Host "  📁 Directory: $TargetDir" -ForegroundColor Gray
Write-Host "  🔗 Collegamento: $ShortcutPath" -ForegroundColor Gray
Write-Host "  🚀 Launcher: $LauncherFile" -ForegroundColor Gray
Write-Host ""

Write-Host "🎮 COME UTILIZZARE:" -ForegroundColor Yellow
Write-Host "  1️⃣ Fai doppio click sull'icona del Desktop" -ForegroundColor Gray
Write-Host "  2️⃣ Usa 'BOOST GAMING' prima di giocare" -ForegroundColor Gray
Write-Host "  3️⃣ Usa 'RIPRISTINA TUTTO' dopo il gaming" -ForegroundColor Gray
Write-Host ""

Write-Host "💡 FEATURES v2.0:" -ForegroundColor Magenta
Write-Host "  • Design moderno stile Windows 11" -ForegroundColor Gray
Write-Host "  • Interfaccia senza terminale visibile" -ForegroundColor Gray
Write-Host "  • Gestione errori avanzata" -ForegroundColor Gray  
Write-Host "  • Feedback visivo migliorato" -ForegroundColor Gray
Write-Host "  • Statistiche dettagliate" -ForegroundColor Gray
Write-Host ""

# Opzione per avvio immediato
$StartNow = Read-Host "Vuoi avviare kaosFWD Booster ora? (s/N)"
if ($StartNow -eq "s" -or $StartNow -eq "S" -or $StartNow -eq "si" -or $StartNow -eq "Si") {
    Write-Host ""
    Write-Host "🚀 Avvio kaosFWD Booster..." -ForegroundColor Green
    Start-Sleep -Seconds 1
    
    try {
        Start-Process $LauncherFile
        Write-Host "✅ Booster avviato con successo!" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Errore nell'avvio automatico. Usa il collegamento sul Desktop." -ForegroundColor Yellow
    }
} else {
    Write-Host "👍 Puoi avviare il booster in qualsiasi momento dal collegamento sul Desktop!" -ForegroundColor Green
}

Write-Host ""
Write-Host "🙏 Grazie per aver scelto kaosFWD Booster!" -ForegroundColor Cyan
Write-Host "⭐ Lascia una recensione se ti piace!" -ForegroundColor Cyan

Start-Sleep -Seconds 3