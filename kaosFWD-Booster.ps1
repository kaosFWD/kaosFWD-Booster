Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Carica Microsoft.VisualBasic per InputBox
try {
    Add-Type -AssemblyName Microsoft.VisualBasic
} catch {
    Write-Host "Microsoft.VisualBasic non disponibile, useremo fallback"
}

# Percorsi file
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$GuiPath = Join-Path $ScriptDir "gui.xaml"
$ExclusionsFile = Join-Path $ScriptDir "exclusions.json"
$ClosedAppsFile = Join-Path $ScriptDir "closed_apps.json"

Write-Host "=== kaosFWD Booster - Avvio ==="
Write-Host "Directory script: $ScriptDir"
Write-Host "File GUI: $GuiPath"
Write-Host "File esclusioni: $ExclusionsFile"

# Verifica GUI
if (-not (Test-Path $GuiPath)) {
    Write-Host "ERRORE: File GUI non trovato: $GuiPath"
    Read-Host "Premi INVIO per uscire"
    exit 1
}

# === INIZIALIZZAZIONE FILE ===
function Initialize-ConfigFiles {
    # Esclusioni di default (processi critici di sistema + comuni applicazioni da proteggere)
    $defaultExclusions = @(
        "explorer",      # Windows Explorer
        "powershell",    # PowerShell
        "cmd",          # Command Prompt
        "winlogon",     # Windows Logon
        "csrss",        # Client Server Runtime Process
        "wininit",      # Windows Initialization
        "services",     # Services Control Manager
        "lsass",        # Local Security Authority
        "dwm",          # Desktop Window Manager
        "audiodg",      # Windows Audio Device Graph
        "conhost",      # Console Host
        "smss",         # Session Manager
        "fontdrvhost",  # Font Driver Host
        "WUDFHost",     # Windows User-mode Driver Framework
        "svchost"       # Service Host
    )
    
    # Crea file exclusions.json se non esiste o è vuoto/corrotto
    try {
        if (-not (Test-Path $ExclusionsFile)) {
            Write-Host "Creando file exclusions.json..."
            $defaultExclusions | ConvertTo-Json -Depth 10 | Out-File $ExclusionsFile -Encoding UTF8
            Write-Host "File exclusions.json creato con $($defaultExclusions.Count) esclusioni di default"
        } else {
            # Verifica che il file sia valido
            $content = Get-Content $ExclusionsFile -Raw -Encoding UTF8
            if (-not $content -or $content.Trim() -eq "" -or $content.Trim() -eq "[]") {
                Write-Host "File exclusions.json vuoto o corrotto, ripristino..."
                $defaultExclusions | ConvertTo-Json -Depth 10 | Out-File $ExclusionsFile -Encoding UTF8
                Write-Host "File exclusions.json ripristinato"
            }
        }
    } catch {
        Write-Host "Errore nella gestione di exclusions.json: $($_.Exception.Message)"
        Write-Host "Creazione file di emergenza..."
        $defaultExclusions | ConvertTo-Json -Depth 10 | Out-File $ExclusionsFile -Encoding UTF8
    }
    
    # Crea file closed_apps.json se non esiste
    if (-not (Test-Path $ClosedAppsFile)) {
        Write-Host "Creando file closed_apps.json..."
        @() | ConvertTo-Json | Out-File $ClosedAppsFile -Encoding UTF8
        Write-Host "File closed_apps.json creato"
    }
}

# Inizializza i file di configurazione
Initialize-ConfigFiles

# Variabili globali
$global:LogBox = $null
$global:ExclusionListControl = $null
$global:Window = $null

# === FUNZIONI UTILITY ===
function Write-Log {
    param([string]$message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    
    # Scrivi sulla console
    Write-Host $logMessage
    
    # Scrivi nel log box se disponibile
    if ($global:LogBox) {
        try {
            $global:LogBox.Dispatcher.Invoke([action]{
                $global:LogBox.AppendText("$logMessage`r`n")
                $global:LogBox.ScrollToEnd()
            })
        } catch {
            # Ignora errori del dispatcher se la finestra è in chiusura
        }
    }
}

function Load-Exclusions {
    try {
        if (Test-Path $ExclusionsFile) {
            $content = Get-Content $ExclusionsFile -Raw -Encoding UTF8
            if ($content -and $content.Trim() -and $content.Trim() -ne "[]") {
                $exclusions = ($content | ConvertFrom-Json)
                
                # Converti in array se è una stringa singola
                if ($exclusions -is [string]) {
                    return @($exclusions)
                }
                
                # Filtra elementi nulli o vuoti
                $validExclusions = @($exclusions | Where-Object { $_ -and $_.ToString().Trim() -ne "" })
                
                if ($validExclusions.Count -gt 0) {
                    return $validExclusions
                }
            }
        }
    }
    catch {
        Write-Log "Errore caricamento esclusioni: $($_.Exception.Message)"
    }
    
    # Fallback: ritorna esclusioni di default e ricrea il file
    Write-Log "Usando esclusioni di default"
    Initialize-ConfigFiles
    return @("explorer", "powershell", "cmd", "winlogon", "csrss", "wininit", "services", "lsass", "dwm")
}

function Save-Exclusions {
    param([array]$exclusionList)
    try {
        # Filtra e pulisci la lista
        $cleanList = @($exclusionList | Where-Object { $_ -and $_.ToString().Trim() -ne "" } | Sort-Object -Unique)
        
        # Salva con formattazione leggibile
        $jsonContent = $cleanList | ConvertTo-Json -Depth 10
        $jsonContent | Out-File $ExclusionsFile -Encoding UTF8
        
        Write-Log "Esclusioni salvate: $($cleanList.Count) elementi"
        return $true
    }
    catch {
        Write-Log "Errore salvataggio esclusioni: $($_.Exception.Message)"
        return $false
    }
}

function Update-ExclusionsList {
    if (-not $global:ExclusionListControl) { return }
    
    try {
        $exclusions = Load-Exclusions
        $global:ExclusionListControl.Dispatcher.Invoke([action]{
            $global:ExclusionListControl.Items.Clear()
            foreach ($item in $exclusions) {
                if ($item -and $item.ToString().Trim() -ne "") {
                    $global:ExclusionListControl.Items.Add($item.ToString())
                }
            }
        })
        Write-Log "Lista esclusioni aggiornata: $($exclusions.Count) elementi"
    }
    catch {
        Write-Log "Errore aggiornamento lista esclusioni: $($_.Exception.Message)"
    }
}

function Show-CustomInputDialog {
    param([string]$Title, [string]$Prompt, [string]$DefaultValue = "")
    
    # Crea form personalizzato
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(450, 180)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.TopMost = $true
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    
    # Label
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(15, 20)
    $label.Size = New-Object System.Drawing.Size(410, 40)
    $label.Text = $Prompt
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($label)
    
    # TextBox
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(15, 65)
    $textBox.Size = New-Object System.Drawing.Size(410, 25)
    $textBox.Text = $DefaultValue
    $textBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $textBox.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
    $textBox.ForeColor = [System.Drawing.Color]::White
    $form.Controls.Add($textBox)
    
    # Pulsanti
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(270, 105)
    $okButton.Size = New-Object System.Drawing.Size(75, 30)
    $okButton.Text = "OK"
    $okButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $okButton.BackColor = [System.Drawing.Color]::FromArgb(0, 175, 80)
    $okButton.ForeColor = [System.Drawing.Color]::White
    $okButton.FlatStyle = "Flat"
    $okButton.Add_Click({
        $form.Tag = $textBox.Text
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    })
    $form.Controls.Add($okButton)
    
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(350, 105)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 30)
    $cancelButton.Text = "Annulla"
    $cancelButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $cancelButton.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $cancelButton.ForeColor = [System.Drawing.Color]::White
    $cancelButton.FlatStyle = "Flat"
    $cancelButton.Add_Click({
        $form.Tag = ""
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    })
    $form.Controls.Add($cancelButton)
    
    # Imposta focus e tasti di scelta rapida
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton
    $textBox.Select()
    
    $result = $form.ShowDialog()
    $returnValue = $form.Tag
    $form.Dispose()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $returnValue
    }
    return $null
}

function Show-ProcessSelector {
    Write-Log "Apertura selettore processi..."
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Seleziona Processo da Escludere"
    $form.Size = New-Object System.Drawing.Size(600, 500)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.TopMost = $true
    $form.FormBorderStyle = "Sizable"
    $form.MinimumSize = New-Object System.Drawing.Size(500, 400)
    
    # Label istruzioni
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(15, 15)
    $label.Size = New-Object System.Drawing.Size(560, 25)
    $label.Text = "Seleziona un processo dalla lista per aggiungerlo alle esclusioni:"
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($label)
    
    # ListView per processi
    $listView = New-Object System.Windows.Forms.ListView
    $listView.Location = New-Object System.Drawing.Point(15, 50)
    $listView.Size = New-Object System.Drawing.Size(560, 350)
    $listView.View = "Details"
    $listView.FullRowSelect = $true
    $listView.GridLines = $true
    $listView.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
    $listView.ForeColor = [System.Drawing.Color]::White
    $listView.Font = New-Object System.Drawing.Font("Consolas", 9)
    
    # Colonne
    $listView.Columns.Add("Nome Processo", 200)
    $listView.Columns.Add("PID", 80)
    $listView.Columns.Add("Descrizione", 280)
    
    # Carica processi
    try {
        $processes = Get-Process | Sort-Object ProcessName
        foreach ($proc in $processes) {
            $item = New-Object System.Windows.Forms.ListViewItem
            $item.Text = $proc.ProcessName
            $item.SubItems.Add($proc.Id.ToString())
            
            # Prova a ottenere la descrizione
            $description = ""
            try {
                if ($proc.MainModule) {
                    $description = $proc.MainModule.FileVersionInfo.FileDescription
                    if (-not $description) {
                        $description = $proc.MainModule.FileVersionInfo.ProductName
                    }
                }
                if (-not $description) {
                    $description = "N/A"
                }
            }
            catch {
                $description = "N/A"
            }
            
            $item.SubItems.Add($description)
            $listView.Items.Add($item)
        }
    }
    catch {
        Write-Log "Errore caricamento processi: $($_.Exception.Message)"
    }
    
    $form.Controls.Add($listView)
    
    # Pulsanti
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(420, 420)
    $okButton.Size = New-Object System.Drawing.Size(75, 30)
    $okButton.Text = "Seleziona"
    $okButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $okButton.BackColor = [System.Drawing.Color]::FromArgb(0, 175, 80)
    $okButton.ForeColor = [System.Drawing.Color]::White
    $okButton.FlatStyle = "Flat"
    $okButton.Add_Click({
        if ($listView.SelectedItems.Count -gt 0) {
            $form.Tag = $listView.SelectedItems[0].Text
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        } else {
            [System.Windows.Forms.MessageBox]::Show("Seleziona un processo dalla lista", "Attenzione", "OK", "Warning")
        }
    })
    $form.Controls.Add($okButton)
    
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(500, 420)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 30)
    $cancelButton.Text = "Annulla"
    $cancelButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $cancelButton.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $cancelButton.ForeColor = [System.Drawing.Color]::White
    $cancelButton.FlatStyle = "Flat"
    $cancelButton.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    })
    $form.Controls.Add($cancelButton)
    
    # Doppio click per selezionare
    $listView.Add_DoubleClick({
        if ($listView.SelectedItems.Count -gt 0) {
            $form.Tag = $listView.SelectedItems[0].Text
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        }
    })
    
    $result = $form.ShowDialog()
    $selectedProcess = $form.Tag
    $form.Dispose()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $selectedProcess) {
        Write-Log "Processo selezionato: $selectedProcess"
        return $selectedProcess
    }
    return $null
}

# === FUNZIONI PRINCIPALI ===
function Invoke-Boost {
    Write-Log "=== AVVIO MODALITA' GAMING BOOST ==="
    
    try {
        $exclusions = Load-Exclusions
        Write-Log "Caricate $($exclusions.Count) esclusioni"
        
        # Processi critici aggiuntivi (oltre a quelli nell'exclusions.json)
        $criticalProcesses = @(
            "System", "Registry", "Idle", "kaosFWD-Booster"
        )
        
        # Combina esclusioni
        $allExclusions = $exclusions + $criticalProcesses | Sort-Object -Unique
        Write-Log "Esclusioni totali: $($allExclusions.Count)"
        
        $closedApps = @()
        $currentPID = $PID
        
        # Ottieni lista processi da chiudere
        $processesToClose = Get-Process | Where-Object {
            $_.Id -ne $currentPID -and
            -not ($allExclusions -contains $_.ProcessName) -and
            $_.ProcessName -ne ""
        }
        
        Write-Log "Trovati $($processesToClose.Count) processi da chiudere"
        
        $successCount = 0
        $failCount = 0
        
        foreach ($proc in $processesToClose) {
            try {
                $procPath = $null
                try {
                    $procPath = $proc.Path
                } catch {
                    # Alcuni processi non hanno path accessibile
                }
                
                $procName = $proc.ProcessName
                
                # Tentativo di chiusura gentile
                $closed = $false
                if ($proc.MainWindowHandle -ne 0) {
                    try {
                        if ($proc.CloseMainWindow()) {
                            Start-Sleep -Milliseconds 200
                            if ($proc.HasExited) {
                                $closed = $true
                            }
                        }
                    } catch { }
                }
                
                # Forzatura se necessario
                if (-not $closed) {
                    try {
                        $proc.Kill()
                        $closed = $true
                    } catch { }
                }
                
                if ($closed) {
                    $closedApps += @{
                        Name = $procName
                        Path = $procPath
                        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                    Write-Log "Chiuso: $procName"
                    $successCount++
                } else {
                    Write-Log "Non chiuso: $procName"
                    $failCount++
                }
            }
            catch {
                Write-Log "Errore con $($proc.ProcessName): $($_.Exception.Message)"
                $failCount++
            }
        }
        
        # Salva lista app chiuse
        try {
            $closedApps | ConvertTo-Json -Depth 10 | Out-File $ClosedAppsFile -Encoding UTF8
        } catch {
            Write-Log "Errore salvataggio app chiuse: $($_.Exception.Message)"
        }
        
        # Ottimizzazione memoria
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        Write-Log "=== BOOST COMPLETATO ==="
        Write-Log "Successi: $successCount | Fallimenti: $failCount"
        Write-Log "Sistema ottimizzato per il gaming!"
        
    } catch {
        Write-Log "ERRORE durante il boost: $($_.Exception.Message)"
    }
}

function Restore-Apps {
    Write-Log "=== AVVIO RIPRISTINO APPLICAZIONI ==="
    
    try {
        if (-not (Test-Path $ClosedAppsFile)) {
            Write-Log "Nessun file di ripristino trovato"
            return
        }
        
        $content = Get-Content $ClosedAppsFile -Raw -Encoding UTF8
        if (-not $content -or $content.Trim() -eq "" -or $content.Trim() -eq "[]") {
            Write-Log "Nessuna applicazione da ripristinare"
            return
        }
        
        $appsToRestore = $content | ConvertFrom-Json
        if (-not $appsToRestore -or $appsToRestore.Count -eq 0) {
            Write-Log "Lista ripristino vuota"
            return
        }
        
        Write-Log "Trovate $($appsToRestore.Count) applicazioni da ripristinare"
        
        $restoredCount = 0
        $failedCount = 0
        
        foreach ($app in $appsToRestore) {
            try {
                if ($app.Path -and (Test-Path $app.Path)) {
                    Start-Process $app.Path -ErrorAction Stop
                    Write-Log "Riaperto: $($app.Name)"
                    $restoredCount++
                    Start-Sleep -Milliseconds 250
                } else {
                    Write-Log "Path non trovato per: $($app.Name)"
                    $failedCount++
                }
            }
            catch {
                Write-Log "Errore riaprendo $($app.Name): $($_.Exception.Message)"
                $failedCount++
            }
        }
        
        # Pulisci file ripristino
        @() | ConvertTo-Json | Out-File $ClosedAppsFile -Encoding UTF8
        
        Write-Log "=== RIPRISTINO COMPLETATO ==="
        Write-Log "Riaperte: $restoredCount | Fallite: $failedCount"
        
    } catch {
        Write-Log "ERRORE durante il ripristino: $($_.Exception.Message)"
    }
}

# === CARICAMENTO GUI ===
Write-Host "Caricamento interfaccia grafica..."

try {
    [xml]$xaml = Get-Content $GuiPath -Encoding UTF8
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $global:Window = [Windows.Markup.XamlReader]::Load($reader)
    Write-Host "GUI caricata con successo"
} catch {
    Write-Host "ERRORE caricamento GUI: $($_.Exception.Message)"
    Read-Host "Premi INVIO per uscire"
    exit 1
}

# === COLLEGAMENTO CONTROLLI ===
try {
    $boostBtn = $global:Window.FindName("BoostBtn")
    $restoreBtn = $global:Window.FindName("RestoreBtn")
    $addBtn = $global:Window.FindName("AddBtn")
    $removeBtn = $global:Window.FindName("RemoveBtn")
    $global:ExclusionListControl = $global:Window.FindName("ExclusionList")
    $global:LogBox = $global:Window.FindName("LogBox")
    
    # Verifica controlli critici
    $missingControls = @()
    if (-not $boostBtn) { $missingControls += "BoostBtn" }
    if (-not $restoreBtn) { $missingControls += "RestoreBtn" }
    if (-not $addBtn) { $missingControls += "AddBtn" }
    if (-not $removeBtn) { $missingControls += "RemoveBtn" }
    if (-not $global:ExclusionListControl) { $missingControls += "ExclusionList" }
    if (-not $global:LogBox) { $missingControls += "LogBox" }
    
    if ($missingControls.Count -gt 0) {
        throw "Controlli GUI mancanti: $($missingControls -join ', ')"
    }
    
    Write-Host "Tutti i controlli GUI collegati correttamente"
    
} catch {
    Write-Host "ERRORE collegamento controlli: $($_.Exception.Message)"
    Read-Host "Premi INVIO per uscire"
    exit 1
}

# === SETUP INIZIALE ===
Update-ExclusionsList
Write-Log "kaosFWD Gaming Booster - PRONTO!"
Write-Log "Controlli disponibili:"
Write-Log "   BOOST GAMING - Chiude processi non essenziali"
Write-Log "   RIPRISTINA TUTTO - Riapre le app chiuse"
Write-Log "   Aggiungi - Aggiunge esclusioni"
Write-Log "   Rimuovi - Rimuove esclusioni selezionate"

# === EVENTI ===

# Pulsante BOOST
$boostBtn.Add_Click({
    Write-Log "Pulsante BOOST premuto"
    $boostBtn.IsEnabled = $false
    $restoreBtn.IsEnabled = $false
    
    try {
        Invoke-Boost
    } finally {
        $boostBtn.IsEnabled = $true
        $restoreBtn.IsEnabled = $true
    }
})

# Pulsante RIPRISTINA
$restoreBtn.Add_Click({
    Write-Log "Pulsante RIPRISTINA premuto"
    $restoreBtn.IsEnabled = $false
    $boostBtn.IsEnabled = $false
    
    try {
        Restore-Apps
    } finally {
        $restoreBtn.IsEnabled = $true
        $boostBtn.IsEnabled = $true
    }
})

# Pulsante AGGIUNGI ESCLUSIONE
$addBtn.Add_Click({
    Write-Log "Pulsante AGGIUNGI ESCLUSIONE premuto"
    
    try {
        $choice = [System.Windows.MessageBox]::Show(
            "Come vuoi aggiungere l'esclusione?`n`n• SI' = Inserisci manualmente il nome`n• NO = Seleziona da processi in esecuzione`n• ANNULLA = Torna indietro",
            "Metodo di Aggiunta Esclusione",
            "YesNoCancel",
            "Question"
        )
        
        $newExclusion = $null
        
        switch ($choice) {
            "Yes" {
                Write-Log "Modalita' inserimento manuale"
                $newExclusion = Show-CustomInputDialog "Aggiungi Esclusione" "Inserisci il nome del processo (senza .exe):"
            }
            "No" {
                Write-Log "Modalita' selezione da processi"
                $newExclusion = Show-ProcessSelector
            }
            "Cancel" {
                Write-Log "Operazione annullata"
                return
            }
        }
        
        if ($newExclusion -and $newExclusion.Trim() -ne "") {
            $newExclusion = $newExclusion.Trim().ToLower()
            
            $currentExclusions = Load-Exclusions
            
            if ($currentExclusions -contains $newExclusion) {
                Write-Log "Esclusione gia' presente: '$newExclusion'"
                [System.Windows.MessageBox]::Show(
                    "L'esclusione '$newExclusion' e' gia' presente nella lista.",
                    "Esclusione Duplicata",
                    "OK",
                    "Information"
                )
            } else {
                $currentExclusions += $newExclusion
                
                if (Save-Exclusions $currentExclusions) {
                    Update-ExclusionsList
                    Write-Log "Esclusione aggiunta con successo: '$newExclusion'"
                    [System.Windows.MessageBox]::Show(
                        "Esclusione '$newExclusion' aggiunta con successo!`nOra questo processo sara' protetto durante il boost.",
                        "Esclusione Aggiunta",
                        "OK",
                        "Information"
                    )
                } else {
                    Write-Log "Errore durante il salvataggio"
                    [System.Windows.MessageBox]::Show(
                        "Errore durante il salvataggio dell'esclusione.",
                        "Errore",
                        "OK",
                        "Error"
                    )
                }
            }
        } else {
            Write-Log "Nessun input fornito"
        }
        
    } catch {
        Write-Log "Errore nell'aggiunta dell'esclusione: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show(
            "Errore durante l'aggiunta dell'esclusione:`n$($_.Exception.Message)",
            "Errore",
            "OK",
            "Error"
        )
    }
})

# Pulsante RIMUOVI ESCLUSIONE
$removeBtn.Add_Click({
    Write-Log "Pulsante RIMUOVI ESCLUSIONE premuto"
    
    try {
        if ($global:ExclusionListControl.SelectedItem) {
            $selectedItem = $global:ExclusionListControl.SelectedItem.ToString()
            Write-Log "Selezionato per rimozione: '$selectedItem'"
            
            # Verifica se è un'esclusione critica
            $criticalExclusions = @("explorer", "winlogon", "csrss", "wininit", "services", "lsass", "dwm")
            
            if ($criticalExclusions -contains $selectedItem.ToLower()) {
                $warningResult = [System.Windows.MessageBox]::Show(
                    "ATTENZIONE: '$selectedItem' e' un processo critico di sistema!`n`nRimuoverlo dalle esclusioni potrebbe causare instabilita' del sistema durante il boost.`n`nSei VERAMENTE sicuro di voler procedere?",
                    "Rimozione Processo Critico",
                    "YesNo",
                    "Warning"
                )
                
                if ($warningResult -eq "No") {
                    Write-Log "Rimozione processo critico annullata dall'utente"
                    return
                }
            }
            
            # Conferma rimozione normale
            $confirmResult = [System.Windows.MessageBox]::Show(
                "Sei sicuro di voler rimuovere l'esclusione '$selectedItem'?`n`nDopo la rimozione, questo processo potra' essere chiuso durante il boost.",
                "Conferma Rimozione",
                "YesNo",
                "Question"
            )
            
            if ($confirmResult -eq "Yes") {
                $currentExclusions = Load-Exclusions | Where-Object { $_ -ne $selectedItem }
                
                if (Save-Exclusions $currentExclusions) {
                    Update-ExclusionsList
                    Write-Log "Esclusione rimossa con successo: '$selectedItem'"
                    [System.Windows.MessageBox]::Show(
                        "Esclusione '$selectedItem' rimossa con successo!`nOra questo processo potra' essere chiuso durante il boost.",
                        "Esclusione Rimossa",
                        "OK",
                        "Information"
                    )
                } else {
                    Write-Log "Errore durante il salvataggio"
                    [System.Windows.MessageBox]::Show(
                        "Errore durante il salvataggio delle modifiche.",
                        "Errore",
                        "OK",
                        "Error"
                    )
                }
            } else {
                Write-Log "Rimozione annullata dall'utente"
            }
        } else {
            Write-Log "Nessun elemento selezionato per la rimozione"
            [System.Windows.MessageBox]::Show(
                "Seleziona un'esclusione dalla lista prima di rimuoverla.`n`nClicca su un elemento nella lista 'PROCESSI PROTETTI' e poi premi 'Rimuovi'.",
                "Nessuna Selezione",
                "OK",
                "Information"
            )
        }
        
    } catch {
        Write-Log "Errore nella rimozione dell'esclusione: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show(
            "Errore durante la rimozione dell'esclusione:`n$($_.Exception.Message)",
            "Errore",
            "OK",
            "Error"
        )
    }
})

# Evento chiusura finestra
$global:Window.Add_Closing({
    Write-Log "Chiusura kaosFWD Gaming Booster"
    Write-Log "Grazie per aver usato il booster!"
})

# Evento doppio click sulla lista esclusioni (per info)
$global:ExclusionListControl.Add_MouseDoubleClick({
    if ($global:ExclusionListControl.SelectedItem) {
        $selectedProcess = $global:ExclusionListControl.SelectedItem.ToString()
        
        # Cerca informazioni sul processo se in esecuzione
        $processInfo = Get-Process -Name $selectedProcess -ErrorAction SilentlyContinue
        
        $infoText = "Informazioni processo: '$selectedProcess'`n`n"
        
        if ($processInfo) {
            $infoText += "Stato: In esecuzione`n"
            $infoText += "PID: $($processInfo[0].Id)`n"
            
            try {
                if ($processInfo[0].Path) {
                    $infoText += "Percorso: $($processInfo[0].Path)`n"
                }
                if ($processInfo[0].MainModule.FileVersionInfo.FileDescription) {
                    $infoText += "Descrizione: $($processInfo[0].MainModule.FileVersionInfo.FileDescription)`n"
                }
            } catch {
                $infoText += "Informazioni aggiuntive non disponibili`n"
            }
        } else {
            $infoText += "Stato: Non in esecuzione`n"
        }
        
        $infoText += "`nQuesto processo e' protetto e NON verra' chiuso durante il boost."
        
        [System.Windows.MessageBox]::Show(
            $infoText,
            "Informazioni Esclusione",
            "OK",
            "Information"
        )
    }
})

# === AVVIO APPLICAZIONE ===
try {
    Write-Host "Avvio interfaccia principale..."
    Write-Log "=== INTERFACCIA PRONTA ALL'USO ==="
    Write-Log "Tutte le funzionalita' sono attive"
    Write-Log "SUGGERIMENTO: Fai doppio click su un'esclusione per vedere le info"
    
    # Mostra finestra
    $result = $global:Window.ShowDialog()
    
} catch {
    Write-Host "ERRORE CRITICO: $($_.Exception.Message)"
    Write-Log "Errore fatale nell'interfaccia: $($_.Exception.Message)"
    
    [System.Windows.MessageBox]::Show(
        "Errore critico nell'interfaccia:`n$($_.Exception.Message)`n`nL'applicazione verra' chiusa.",
        "Errore Fatale",
        "OK",
        "Error"
    )
} finally {
    Write-Host "kaosFWD Gaming Booster terminato"
    Write-Host "Grazie per aver utilizzato il booster!"
}