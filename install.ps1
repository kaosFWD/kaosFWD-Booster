param()

# Richiedi privilegi admin se non già admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltinRole] "Administrator"
)) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$AppName = "kaosFWD-Booster"
$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$TargetDir = Join-Path $env:ProgramData $AppName

# Percorso Desktop corretto (gestisce anche OneDrive)
$DesktopPath = [Environment]::GetFolderPath("Desktop")
if ($DesktopPath -match "OneDrive") {
    $DesktopPath = "$env:UserProfile\Desktop"
}

$ShortcutPath = Join-Path $DesktopPath "$AppName.lnk"

Write-Host "🚀 Installazione di $AppName in corso..."

# Rimuovi vecchia versione
if (Test-Path $TargetDir) {
    Remove-Item $TargetDir -Recurse -Force
}

# Copia tutti i file nella cartella di destinazione
Copy-Item $SourceDir $TargetDir -Recurse -Force

# Controlla se esiste launcher.bat, altrimenti crealo
$LauncherFile = Join-Path $TargetDir "launcher.bat"
if (-not (Test-Path $LauncherFile)) {
    @"
@echo off
set SCRIPT_DIR=%~dp0
powershell -NoExit -ExecutionPolicy Bypass -File "%SCRIPT_DIR%kaosFWD-Booster.ps1"
"@ | Out-File $LauncherFile -Encoding ASCII
}

# Crea collegamento sul Desktop che punta a launcher.bat
try {
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $LauncherFile
    $Shortcut.WorkingDirectory = $TargetDir
    $Shortcut.WindowStyle = 1
    $Shortcut.IconLocation = "powershell.exe,0"
    $Shortcut.Save()
    Write-Host "✅ Collegamento creato: $ShortcutPath"
} catch {
    Write-Host "❌ Errore durante la creazione del collegamento: $($_.Exception.Message)"
}

Write-Host "✅ Installazione completata!"
Start-Sleep -Seconds 2
