param()

# Richiedi privilegi admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$AppName = "kaosFWD-Booster"
$TargetDir = Join-Path $env:ProgramData $AppName
$ShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "$AppName.lnk"

Write-Host "🗑 Disinstallazione di $AppName..."

# Elimina cartella
if (Test-Path $TargetDir) {
    Remove-Item $TargetDir -Recurse -Force
}

# Elimina collegamento
if (Test-Path $ShortcutPath) {
    Remove-Item $ShortcutPath -Force
}

Write-Host "✅ Disinstallazione completata!"
Start-Sleep -Seconds 2
