# kaosFWD Booster - Version Final
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()

# Percorsi file dati
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$GuiPath = Join-Path $ScriptDir "gui.xaml"
$ExclusionsFile = Join-Path $ScriptDir "exclusions.json"
$ClosedAppsFile = Join-Path $ScriptDir "closed_apps.json"

# Verifica file GUI
if (-not (Test-Path $GuiPath)) {
    [System.Windows.MessageBox]::Show("File GUI non trovato: $GuiPath", "Errore avvio", "OK", "Error")
    Write-Host "Errore: File GUI non trovato. Premi un tasto per uscire..."
    Read-Host "Premi INVIO per uscire"
    exit
}

# Crea file exclusions se non esiste
if (-not (Test-Path $ExclusionsFile)) {
    $defaultExclusions = @("explorer", "powershell", "cmd", "winlogon", "csrss", "wininit", "services", "lsass", "dwm")
    $defaultExclusions | ConvertTo-Json | Out-File $ExclusionsFile -Encoding UTF8
}

# Crea file closed_apps se non esiste o è vuoto
if (-not (Test-Path $ClosedAppsFile)) {
    @() | ConvertTo-Json | Out-File $ClosedAppsFile -Encoding UTF8
} elseif ((Get-Content $ClosedAppsFile -Raw -ErrorAction SilentlyContinue).Trim() -eq "") {
    @() | ConvertTo-Json | Out-File $ClosedAppsFile -Encoding UTF8
}

# Variabili globali per i controlli
$global:LogBox = $null

# Funzioni helper
function Write-Log {
    param([string]$message)
    if ($global:LogBox) {
        $timestamp = Get-Date -Format "HH:mm:ss"
        $global:LogBox.AppendText("[$timestamp] $message`r`n")
        $global:LogBox.ScrollToEnd()
    }
    Write-Host $message
}

function Load-Exclusions {
    try {
        $content = Get-Content $ExclusionsFile -Raw -ErrorAction Stop
        if ($content.Trim()) {
            return ($content | ConvertFrom-Json)
        }
    } catch {
        Write-Log "Errore caricamento esclusioni: $($_.Exception.Message)"
    }
    return @("explorer", "powershell", "cmd", "winlogon", "csrss", "wininit", "services", "lsass", "dwm")
}

function Save-Exclusions {
    param($list)
    try {
        $list | ConvertTo-Json | Out-File $ExclusionsFile -Encoding UTF8
        Write-Log "Esclusioni salvate"
    } catch {
        Write-Log "Errore salvataggio esclusioni: $($_.Exception.Message)"
    }
}

# Funzione InputBox
function Show-InputBox {
    param([string]$Title, [string]$Prompt)
    return [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, $Title)
}

# Funzione per eseguire Boost
function Invoke-Boost {
    Write-Log "🚀 Avvio modalità Boost..."
    
    $Exclusions = Load-Exclusions
    # Processi di sistema critici che non devono mai essere chiusi
    $CriticalProcesses = @(
        "System", "Registry", "Idle", "winlogon", "csrss", "wininit", 
        "services", "lsass", "dwm", "audiodg", "conhost", "smss",
        "fontdrvhost", "WUDFHost", "svchost", "powershell_ise"
    )
    
    $ClosedList = @()
    $CurrentPID = $PID
    
    $ProcessesToClose = Get-Process | Where-Object { 
        -not ($Exclusions -contains $_.ProcessName) -and 
        -not ($CriticalProcesses -contains $_.ProcessName) -and
        $_.Id -ne $CurrentPID
    }
    
    foreach ($proc in $ProcessesToClose) {
        try {
            $path = $null
            $windowTitle = ""
            
            # Tenta di ottenere il percorso del processo
            try { 
                $path = $proc.Path 
                $windowTitle = $proc.MainWindowTitle
            } catch { }
            
            # Tenta chiusura gentile prima
            $closed = $false
            if ($proc.CloseMainWindow()) {
                Start-Sleep -Milliseconds 500
                if ($proc.HasExited) {
                    $closed = $true
                }
            }
            
            if (-not $closed) {
                $proc.Kill()
                Start-Sleep -Milliseconds 100
            }
            
            $ClosedList += @{
                Name = $proc.ProcessName
                Path = $path
                WindowTitle = $windowTitle
                Id = $proc.Id
            }
            
            Write-Log "✅ Chiuso: $($proc.ProcessName)"
            
        } catch {
            Write-Log "❌ Errore chiudendo $($proc.ProcessName): $($_.Exception.Message)"
        }
    }
    
    # Salva la lista delle app chiuse
    try {
        $ClosedList | ConvertTo-Json | Out-File $ClosedAppsFile -Encoding UTF8
        Write-Log "🎯 Modalità Boost attivata! Chiusi $($ClosedList.Count) processi"
    } catch {
        Write-Log "❌ Errore salvando lista app chiuse: $($_.Exception.Message)"
    }
    
    # Ottimizzazioni aggiuntive
    try {
        [System.GC]::Collect()
        Write-Log "🧹 Memoria ottimizzata"
    } catch {
        Write-Log "⚠️ Errore durante ottimizzazioni: $($_.Exception.Message)"
    }
}

# Funzione per ripristinare app chiuse
function Restore-Apps {
    Write-Log "💻 Avvio ripristino applicazioni..."
    
    if (-not (Test-Path $ClosedAppsFile)) {
        Write-Log "ℹ️ Nessuna app da riaprire"
        return
    }
    
    try {
        $content = Get-Content $ClosedAppsFile -Raw
        if (-not $content.Trim()) {
            Write-Log "ℹ️ Lista app vuota"
            return
        }
        
        $Apps = $content | ConvertFrom-Json
        $RestoredCount = 0
        
        foreach ($app in $Apps) {
            if ($app.Path -and (Test-Path $app.Path)) {
                try {
                    Start-Process $app.Path -ErrorAction Stop
                    Write-Log "✅ Riaperto: $($app.Name)"
                    $RestoredCount++
                    Start-Sleep -Milliseconds 200
                } catch {
                    Write-Log "❌ Errore riaprendo $($app.Name): $($_.Exception.Message)"
                }
            } else {
                Write-Log "⚠️ Percorso non trovato per: $($app.Name)"
            }
        }
        
        # Pulisce il file dopo il ripristino
        @() | ConvertTo-Json | Out-File $ClosedAppsFile -Encoding UTF8
        Write-Log "🎯 Ripristino completato! Riaperti $RestoredCount processi"
        
    } catch {
        Write-Log "❌ Errore durante il ripristino: $($_.Exception.Message)"
    }
}

# Carica GUI
try {
    [xml]$XAML = Get-Content $GuiPath -Encoding UTF8
    $Reader = (New-Object System.Xml.XmlNodeReader $XAML)
    $Window = [Windows.Markup.XamlReader]::Load($Reader)
} catch {
    [System.Windows.MessageBox]::Show("Errore caricamento GUI: $($_.Exception.Message)", "Errore", "OK", "Error")
    Read-Host "Premi INVIO per uscire"
    exit
}

# Collega controlli
$BoostBtn = $Window.FindName("BoostBtn")
$RestoreBtn = $Window.FindName("RestoreBtn")
$AddBtn = $Window.FindName("AddBtn")
$RemoveBtn = $Window.FindName("RemoveBtn")
$ExclusionList = $Window.FindName("ExclusionList")
$global:LogBox = $Window.FindName("LogBox")

# Verifica che tutti i controlli siano stati trovati
if (-not $BoostBtn -or -not $RestoreBtn -or -not $AddBtn -or -not $RemoveBtn -or -not $ExclusionList -or -not $global:LogBox) {
    [System.Windows.MessageBox]::Show("Errore: Alcuni controlli GUI non sono stati trovati", "Errore", "OK", "Error")
    Read-Host "Premi INVIO per uscire"
    exit
}

# Carica lista esclusioni nella GUI
try {
    $ExclusionList.ItemsSource = Load-Exclusions
    Write-Log "🔧 kaosFWD Booster caricato correttamente"
} catch {
    Write-Log "❌ Errore caricamento esclusioni: $($_.Exception.Message)"
}

# Eventi pulsanti
$BoostBtn.Add_Click({ 
    $BoostBtn.IsEnabled = $false
    try {
        Invoke-Boost
    } finally {
        $BoostBtn.IsEnabled = $true
    }
})

$RestoreBtn.Add_Click({ 
    $RestoreBtn.IsEnabled = $false
    try {
        Restore-Apps
    } finally {
        $RestoreBtn.IsEnabled = $true
    }
})

$AddBtn.Add_Click({
    $input = Show-InputBox "Aggiungi esclusione" "Inserisci nome processo (senza .exe):"
    if ($input -and $input.Trim() -ne "") {
        $input = $input.Trim()
        $list = Load-Exclusions
        if (-not ($list -contains $input)) {
            $list += $input
            Save-Exclusions $list
            $ExclusionList.ItemsSource = $null
            $ExclusionList.ItemsSource = $list
            Write-Log "➕ Aggiunta esclusione: $input"
        } else {
            Write-Log "⚠️ Esclusione già presente: $input"
        }
    }
})

$RemoveBtn.Add_Click({
    if ($ExclusionList.SelectedItem) {
        $selectedItem = $ExclusionList.SelectedItem
        $list = Load-Exclusions | Where-Object { $_ -ne $selectedItem }
        Save-Exclusions $list
        $ExclusionList.ItemsSource = $null
        $ExclusionList.ItemsSource = $list
        Write-Log "➖ Rimossa esclusione: $selectedItem"
    } else {
        Write-Log "⚠️ Seleziona un elemento da rimuovere"
    }
})

# Gestione chiusura finestra
$Window.Add_Closing({
    Write-Log "👋 Chiusura kaosFWD Booster"
})

# Mostra finestra
try {
    Write-Log "🚀 Interfaccia pronta all'uso"
    $null = $Window.ShowDialog()
} catch {
    Write-Host "Errore visualizzazione finestra: $($_.Exception.Message)"
    Read-Host "Premi INVIO per uscire"
}