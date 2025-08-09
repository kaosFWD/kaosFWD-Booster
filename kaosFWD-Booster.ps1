# === CARICAMENTO E SETUP GUI ===
Write-Host "🎨 Caricamento interfaccia grafica moderna..."

try {
    [xml]$xaml = Get-Content $GuiPath -Encoding UTF8
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $global:Window = [Windows.Markup.XamlReader]::Load($reader)
    Write-Host "✅ GUI caricata con successo"
} catch {
    Show-Console
    Write-Host "💥 ERRORE caricamento GUI: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Premi INVIO per uscire"
    exit 1
}

# === COLLEGAMENTO CONTROLLI ===
try {
    $boostBtn = $global:Window.FindName("BoostBtn")
    $restoreBtn = $global:Window.FindName("RestoreBtn")
    $addBtn = $global:Window.FindName("AddBtn")
    $removeBtn = $global:Window.FindName("RemoveBtn")
    $closeBtn = $global:Window.FindName("CloseButton")
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
    
    Write-Host "🔗 Tutti i controlli GUI collegati correttamente"
    
} catch {
    Show-Console
    Write-Host "💥 ERRORE collegamento controlli: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Premi INVIO per uscire"
    exit 1
}

# === FUNZIONALITÀ FINESTRA PERSONALIZZATA ===
# Permetti il trascinamento della finestra
$global:Window.Add_MouseLeftButtonDown({
    $global:Window.DragMove()
})

# Pulsante chiusura personalizzato
if ($closeBtn) {
    $closeBtn.Add_Click({
        Write-Log "👋 Chiusura kaosFWD Gaming Booster v2.0"
        $global:Window.Close()
    })
}

# === SETUP INIZIALE MIGLIORATO ===
Update-ExclusionsList

# Messaggio di benvenuto con stile
Write-Log "🚀 kaosFWD Gaming Booster v2.0 - ONLINE!"
Write-Log "⭐ Nuove funzionalità disponibili:"
Write-Log "   🎯 BOOST GAMING - Chiude processi non essenziali con AI"
Write-Log "   🔄 RIPRISTINA TUTTO - Riapre le app chiuse intelligentemente"
Write-Log "   🛡️ GESTIONE ESCLUSIONI - Proteggi i tuoi processi importanti"
Write-Log "   📊 MONITORAGGIO REAL-TIME - Statistiche dettagliate"
Write-Log "💡 Suggerimento: Fai doppio click su un'esclusione per info dettagliate"

# === EVENTI MIGLIORATI ===

# Pulsante BOOST con feedback visivo
$boostBtn.Add_Click({
    Write-Log "🚀 === AVVIO SEQUENZA BOOST ==="
    
    # Disabilita pulsanti durante l'operazione
    $boostBtn.IsEnabled = $false
    $restoreBtn.IsEnabled = $false
    
    # Cambio colore pulsante per feedback
    $originalBrush = $boostBtn.Background
    $boostBtn.Background = [System.Windows.Media.Brushes]::Orange
    $boostBtn.Content = "⏳ BOOST IN CORSO..."
    
    try {
        Invoke-Boost
        $boostBtn.Content = "✅ BOOST COMPLETATO"
        $boostBtn.Background = [System.Windows.Media.Brushes]::Green
        
        # Reset dopo 3 secondi
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(3)
        $timer.Add_Tick({
            $boostBtn.Content = "🚀 BOOST GAMING"
            $boostBtn.Background = $originalBrush
            $timer.Stop()
        })
        $timer.Start()
        
    } catch {
        Write-Log "💥 Errore durante il boost: $($_.Exception.Message)"
        $boostBtn.Content = "❌ ERRORE BOOST"
        $boostBtn.Background = [System.Windows.Media.Brushes]::Red
    } finally {
        $boostBtn.IsEnabled = $true
        $restoreBtn.IsEnabled = $true
    }
})

# Pulsante RIPRISTINA con feedback visivo
$restoreBtn.Add_Click({
    Write-Log "🔄 === AVVIO SEQUENZA RIPRISTINO ==="
    
    # Disabilita pulsanti durante l'operazione
    $restoreBtn.IsEnabled = $false
    $boostBtn.IsEnabled = $false
    
    # Cambio colore per feedback
    $originalBrush = $restoreBtn.Background
    $restoreBtn.Background = [System.Windows.Media.Brushes]::Orange
    $restoreBtn.Content = "⏳ RIPRISTINO..."
    
    try {
        Restore-Apps
        $restoreBtn.Content = "✅ RIPRISTINATO"
        $restoreBtn.Background = [System.Windows.Media.Brushes]::Green
        
        # Reset dopo 3 secondi
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(3)
        $timer.Add_Tick({
            $restoreBtn.Content = "🔄 RIPRISTINA TUTTO"
            $restoreBtn.Background = $originalBrush
            $timer.Stop()
        })
        $timer.Start()
        
    } catch {
        Write-Log "💥 Errore durante il ripristino: $($_.Exception.Message)"
        $restoreBtn.Content = "❌ ERRORE"
        $restoreBtn.Background = [System.Windows.Media.Brushes]::Red
    } finally {
        $restoreBtn.IsEnabled = $true
        $boostBtn.IsEnabled = $true
    }
})

# Pulsante AGGIUNGI ESCLUSIONE (migliorato)
$addBtn.Add_Click({
    Write-Log "➕ Avvio aggiunta esclusione..."
    
    try {
        $choice = [System.Windows.MessageBox]::Show(
            "🎯 Scegli il metodo per aggiungere l'esclusione:`n`n✏️ SI = Inserisci nome manualmente`n🔍 NO = Seleziona da processi attivi`n❌ ANNULLA = Torna indietro",
            "Metodo Aggiunta Esclusione",
            "YesNoCancel",
            "Question"
        )
        
        $newExclusion = $null
        
        switch ($choice) {
            "Yes" {
                Write-Log "✏️ Modalità inserimento manuale"
                $newExclusion = Show-CustomInputDialog "Aggiungi Esclusione Manualmente" "Inserisci il nome del processo (senza .exe):`n`nEsempio: chrome, discord, spotify"
            }
            "No" {
                Write-Log "🔍 Modalità selezione da processi attivi"
                $newExclusion = Show-ProcessSelector
            }
            "Cancel" {
                Write-Log "❌ Operazione annullata dall'utente"
                return
            }
        }
        
        if ($newExclusion -and $newExclusion.Trim() -ne "") {
            $newExclusion = $newExclusion.Trim().ToLower()
            
            $currentExclusions = Load-Exclusions
            
            if ($currentExclusions -contains $newExclusion) {
                Write-Log "⚠️ Esclusione già presente: '$newExclusion'"
                [System.Windows.MessageBox]::Show(
                    "🛡️ L'esclusione '$newExclusion' è già presente nella lista.`n`nQuesto processo è già protetto durante il boost.",
                    "Esclusione Già Esistente",
                    "OK",
                    "Information"
                )
            } else {
                $currentExclusions += $newExclusion
                
                if (Save-Exclusions $currentExclusions) {
                    Update-ExclusionsList
                    Write-Log "✅ Esclusione aggiunta: '$newExclusion'"
                    [System.Windows.MessageBox]::Show(
                        "🎉 Esclusione '$newExclusion' aggiunta con successo!`n`n🛡️ Questo processo sarà ora protetto durante il boost.`n📊 Totale esclusioni: $($currentExclusions.Count)",
                        "Esclusione Aggiunta",
                        "OK",
                        "Information"
                    )
                } else {
                    Write-Log "❌ Errore durante il salvataggio"
                    [System.Windows.MessageBox]::Show(
                        "💥 Errore durante il salvataggio dell'esclusione.`n`nRiprova o controlla i permessi del file.",
                        "Errore Salvataggio",
                        "OK",
                        "Error"
                    )
                }
            }
        } else {
            Write-Log "⚠️ Nessun input fornito"
        }
        
    } catch {
        Write-Log "💥 Errore nell'aggiunta dell'esclusione: $($_.Exception.Message)"
        Show-Console
        [System.Windows.MessageBox]::Show(
            "💥 Errore durante l'aggiunta dell'esclusione:`n`n$($_.Exception.Message)`n`nControlla la console per dettagli.",
            "Errore Critico",
            "OK",
            "Error"
        )
    }
})

# Pulsante RIMUOVI ESCLUSIONE (migliorato)
$removeBtn.Add_Click({
    Write-Log "🗑️ Avvio rimozione esclusione..."
    
    try {
        if ($global:ExclusionListControl.SelectedItem) {
            $selectedItem = $global:ExclusionListControl.SelectedItem.ToString()
            Write-Log "🎯 Selezionato per rimozione: '$selectedItem'"
            
            # Verifica se è un'esclusione critica
            $criticalExclusions = @("explorer", "winlogon", "csrss", "wininit", "services", "lsass", "dwm", "audiodg")
            
            if ($criticalExclusions -contains $selectedItem.ToLower()) {
                $warningResult = [System.Windows.MessageBox]::Show(
                    "🚨 ATTENZIONE: '$selectedItem' è un processo CRITICO di sistema!`n`n⚠️ Rimuoverlo dalle esclusioni potrebbe causare:`n• Instabilità del sistema`n• Crash durante il boost`n• Perdita di dati non salvati`n`n❓ Sei VERAMENTE sicuro di voler procedere?`n`n💡 Consiglio: Lascia i processi critici nelle esclusioni per sicurezza.",
                    "⚠️ Rimozione Processo Critico",
                    "YesNo",
                    "Warning"
                )
                
                if ($warningResult -eq "No") {
                    Write-Log "🛡️ Rimozione processo critico annullata (scelta saggia!)"
                    return
                }
                
                Write-Log "⚠️ L'utente ha confermato la rimozione del processo critico '$selectedItem'"
            }
            
            # Conferma rimozione normale
            $confirmResult = [System.Windows.MessageBox]::Show(
                "🗑️ Conferma rimozione esclusione`n`nProcesso: '$selectedItem'`n`n❓ Sei sicuro di voler rimuovere questa esclusione?`n`n⚠️ Dopo la rimozione, questo processo potrà essere chiuso durante il boost.",
                "Conferma Rimozione",
                "YesNo",
                "Question"
            )
            
            if ($confirmResult -eq "Yes") {
                $currentExclusions = Load-Exclusions | Where-Object { $_ -ne $selectedItem }
                
                if (Save-Exclusions $currentExclusions) {
                    Update-ExclusionsList
                    Write-Log "✅ Esclusione rimossa: '$selectedItem'"
                    [System.Windows.MessageBox]::Show(
                        "🎉 Esclusione '$selectedItem' rimossa con successo!`n`n⚠️ Questo processo potrà ora essere chiuso durante il boost.`n📊 Esclusioni rimanenti: $($currentExclusions.Count)",
                        "Esclusione Rimossa",
                        "OK",
                        "Information"
                    )
                } else {
                    Write-Log "❌ Errore durante il salvataggio"
                    [System.Windows.MessageBox]::Show(
                        "💥 Errore durante il salvataggio delle modifiche.`n`nRiprova o controlla i permessi del file.",
                        "Errore Salvataggio",
                        "OK",
                        "Error"
                    )
                }
            } else {
                Write-Log "❌ Rimozione annullata dall'utente"
            }
        } else {
            Write-Log "⚠️ Nessun elemento selezionato"
            [System.Windows.MessageBox]::Show(
                "🎯 Seleziona prima un'esclusione da rimuovere`n`n📋 Come fare:`n1️⃣ Clicca su un elemento nella lista 'PROCESSI PROTETTI'`n2️⃣ Premi il pulsante 'Rimuovi'`n`n💡 Suggerimento: Evita di rimuovere processi di sistema critici!",
                "Nessuna Selezione",
                "OK",
                "Information"
            )
        }
        
    } catch {
        Write-Log "💥 Errore nella rimozione dell'esclusione: $($_.Exception.Message)"
        Show-Console
        [System.Windows.MessageBox]::Show(
            "💥 Errore durante la rimozione dell'esclusione:`n`n$($_.Exception.Message)`n`nControlla la console per dettagli.",
            "Errore Critico",
            "OK",
            "Error"
        )
    }
})

# Evento chiusura finestra
$global:Window.Add_Closing({
    Write-Log "👋 Chiusura kaosFWD Gaming Booster v2.0"
    Write-Log "🙏 Grazie per aver utilizzato il booster!"
    Write-Log "⭐ Lascia una recensione se ti è stato utile!"
})

# Doppio click sulla lista esclusioni per informazioni dettagliate
$global:ExclusionListControl.Add_MouseDoubleClick({
    if ($global:ExclusionListControl.SelectedItem) {
        $selectedProcess = $global:ExclusionListControl.SelectedItem.ToString()
        
        # Cerca informazioni dettagliate sul processo
        $processInfo = Get-Process -Name $selectedProcess -ErrorAction SilentlyContinue
        
        $infoText = "🔍 Informazioni dettagliate: '$selectedProcess'`n`n"
        
        if ($processInfo) {
            $totalInstances = $processInfo.Count
            $firstProcess = $processInfo[0]
            
            $infoText += "📊 Stato: ✅ In esecuzione ($totalInstances istanze)`n"
            $infoText += "🆔 PID principale: $($firstProcess.Id)`n"
            
            # Memoria totale utilizzata da tutte le istanze
            $totalMemoryMB = ($processInfo | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB
            $infoText += "💾 Memoria totale: $([math]::Round($totalMemoryMB, 1)) MB`n"
            
            try {
                if ($firstProcess.Path) {
                    $infoText += "📁 Percorso: $($firstProcess.Path)`n"
                }
                if ($firstProcess.MainModule.FileVersionInfo.FileDescription) {
                    $infoText += "📝 Descrizione: $($firstProcess.MainModule.FileVersionInfo.FileDescription)`n"
                }
                if ($firstProcess.MainModule.FileVersionInfo.CompanyName) {
                    $infoText += "🏢 Azienda: $($firstProcess.MainModule.FileVersionInfo.CompanyName)`n"
                }
                if ($firstProcess.MainModule.FileVersionInfo.FileVersion) {
                    $infoText += "🔖 Versione: $($firstProcess.MainModule.FileVersionInfo.FileVersion)`n"
                }
            } catch {
                $infoText += "⚠️ Informazioni aggiuntive: Accesso limitato`n"
            }
        } else {
            $infoText += "📊 Stato: ❌ Non in esecuzione`n"
            $infoText += "💡 Il processo potrebbe avviarsi automaticamente quando necessario.`n"
        }
        
        $infoText += "`n🛡️ PROTEZIONE ATTIVA"
        $infoText += "`nQuesto processo è PROTETTO e NON verrà mai chiuso durante il boost.`n"
        
        # Determina se è critico
        $criticalProcesses = @("explorer", "winlogon", "csrss", "wininit", "services", "lsass", "dwm", "audiodg")
        if ($criticalProcesses -contains $selectedProcess.ToLower()) {
            $infoText += "`n🚨 PROCESSO CRITICO DI SISTEMA`nLa rimozione dalle esclusioni è SCONSIGLIATA!"
        }
        
        [System.Windows.MessageBox]::Show(
            $infoText,
            "🔍 Informazioni Processo",
            "OK",
            "Information"
        )
        
        Write-Log "ℹ️ Visualizzate informazioni per processo: $selectedProcess"
    }
})

# === AVVIO APPLICAZIONE ===
try {
    Write-Host "🚀 Avvio interfaccia principale..."
    Write-Log "🎉 === INTERFACCIA v2.0 PRONTA === 🎉"
    Write-Log "⚡ Tutte le funzionalità sono operative"
    Write-Log "🎮 Pronto per ottimizzare la tua sessione gaming!"
    Write-Log ""
    Write-Log "💡 TIPS & TRICKS:"
    Write-Log "   • Doppio click su esclusione = Info dettagliate"
    Write-Log "   • Trascina la finestra dal titolo per spostarla"
    Write-Log "   • Usa BOOST prima di giocare per max performance"
    Write-Log "   • Usa RIPRISTINA dopo il gaming per normalità"
    
    # Mostra finestra
    $result = $global:Window.ShowDialog()
    
} catch {
    Show-Console
    Write-Host "💥 ERRORE CRITICO INTERFACCIA: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "💥 Errore fatale nell'interfaccia: $($_.Exception.Message)"
    
    [System.Windows.MessageBox]::Show(
        "💥 Errore critico nell'interfaccia:`n`n$($_.Exception.Message)`n`n🔧 L'applicazione verrà chiusa. Controlla i file di configurazione e riprova.`n`n📋 Log completo disponibile nella console.",
        "💥 Errore Fatale",
        "OK",
        "Error"
    )
} finally {
    Write-Host "👋 kaosFWD Gaming Booster v2.0 terminato"
    Write-Host "🙏 Grazie per aver utilizzato il booster!"
    Write-Host "⭐ Visita il nostro sito per aggiornamenti e supporto!"
}Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Nascondi finestra PowerShell se non in modalità debug
$consolePtr = [Console.Window]::GetConsoleWindow()
if ($consolePtr -ne [System.IntPtr]::Zero) {
    [Console.Window]::ShowWindow($consolePtr, 0) # 0 = Hide
}

# Definisci API Windows per gestire la console
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

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

# Funzione per mostrare la console in caso di errore
function Show-Console {
    $consolePtr = [Console.Window]::GetConsoleWindow()
    if ($consolePtr -ne [System.IntPtr]::Zero) {
        [Console.Window]::ShowWindow($consolePtr, 5) # 5 = Show
    }
}

try {
    Write-Host "=== kaosFWD Booster v2.0 - Avvio ==="
    Write-Host "Directory script: $ScriptDir"
    Write-Host "File GUI: $GuiPath"
    Write-Host "File esclusioni: $ExclusionsFile"
    
    # Verifica GUI
    if (-not (Test-Path $GuiPath)) {
        Show-Console
        Write-Host "ERRORE: File GUI non trovato: $GuiPath" -ForegroundColor Red
        Read-Host "Premi INVIO per uscire"
        exit 1
    }
} catch {
    Show-Console
    Write-Host "ERRORE CRITICO durante l'inizializzazione: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Premi INVIO per uscire"
    exit 1
}

# Variabili globali
$global:LogBox = $null
$global:ExclusionListControl = $null
$global:Window = $null

# === FUNZIONI UTILITY ===
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
        "svchost",      # Service Host
        "dllhost",      # DLL Host Process
        "RuntimeBroker", # Runtime Broker
        "SearchIndexer", # Windows Search
        "spoolsv"       # Print Spooler
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

function Write-Log {
    param([string]$message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    
    # Scrivi sulla console (nascosta)
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
        
        Write-Log "✅ Esclusioni salvate: $($cleanList.Count) elementi"
        return $true
    }
    catch {
        Write-Log "❌ Errore salvataggio esclusioni: $($_.Exception.Message)"
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
        Write-Log "📋 Lista esclusioni aggiornata: $($exclusions.Count) elementi"
    }
    catch {
        Write-Log "❌ Errore aggiornamento lista esclusioni: $($_.Exception.Message)"
    }
}

function Show-CustomInputDialog {
    param([string]$Title, [string]$Prompt, [string]$DefaultValue = "")
    
    # Form con design moderno
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(480, 200)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.TopMost = $true
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    
    # Label con stile moderno
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20, 25)
    $label.Size = New-Object System.Drawing.Size(430, 50)
    $label.Text = $Prompt
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $label.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
    $form.Controls.Add($label)
    
    # TextBox moderno
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(20, 75)
    $textBox.Size = New-Object System.Drawing.Size(430, 30)
    $textBox.Text = $DefaultValue
    $textBox.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $textBox.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
    $textBox.ForeColor = [System.Drawing.Color]::White
    $textBox.BorderStyle = "FixedSingle"
    $form.Controls.Add($textBox)
    
    # Pulsanti con colori moderni
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(290, 125)
    $okButton.Size = New-Object System.Drawing.Size(80, 35)
    $okButton.Text = "OK"
    $okButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $okButton.BackColor = [System.Drawing.Color]::FromArgb(0, 212, 170)
    $okButton.ForeColor = [System.Drawing.Color]::White
    $okButton.FlatStyle = "Flat"
    $okButton.Add_Click({
        $form.Tag = $textBox.Text
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    })
    $form.Controls.Add($okButton)
    
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(375, 125)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 35)
    $cancelButton.Text = "Annulla"
    $cancelButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $cancelButton.BackColor = [System.Drawing.Color]::FromArgb(231, 76, 60)
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
    Write-Log "🔍 Apertura selettore processi..."
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Seleziona Processo da Escludere"
    $form.Size = New-Object System.Drawing.Size(650, 520)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.TopMost = $true
    $form.FormBorderStyle = "Sizable"
    $form.MinimumSize = New-Object System.Drawing.Size(500, 400)
    
    # Label istruzioni
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.Size = New-Object System.Drawing.Size(600, 30)
    $label.Text = "🎯 Seleziona un processo dalla lista per aggiungerlo alle esclusioni:"
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $label.ForeColor = [System.Drawing.Color]::FromArgb(107, 115, 255)
    $form.Controls.Add($label)
    
    # ListView per processi
    $listView = New-Object System.Windows.Forms.ListView
    $listView.Location = New-Object System.Drawing.Point(20, 60)
    $listView.Size = New-Object System.Drawing.Size(600, 380)
    $listView.View = "Details"
    $listView.FullRowSelect = $true
    $listView.GridLines = $true
    $listView.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
    $listView.ForeColor = [System.Drawing.Color]::White
    $listView.Font = New-Object System.Drawing.Font("Cascadia Code", 9)
    
    # Colonne
    $listView.Columns.Add("Nome Processo", 180)
    $listView.Columns.Add("PID", 70)
    $listView.Columns.Add("CPU %", 80)
    $listView.Columns.Add("Descrizione", 270)
    
    # Carica processi con informazioni aggiuntive
    try {
        $processes = Get-Process | Sort-Object ProcessName
        foreach ($proc in $processes) {
            $item = New-Object System.Windows.Forms.ListViewItem
            $item.Text = $proc.ProcessName
            $item.SubItems.Add($proc.Id.ToString())
            
            # CPU usage (approssimativo)
            try {
                $cpuUsage = Get-Counter -Counter "\Process($($proc.ProcessName))\% Processor Time" -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
                if ($cpuUsage) {
                    $cpuPercent = [math]::Round($cpuUsage.CounterSamples[0].CookedValue, 1)
                    $item.SubItems.Add("$cpuPercent%")
                } else {
                    $item.SubItems.Add("N/A")
                }
            } catch {
                $item.SubItems.Add("N/A")
            }
            
            # Descrizione
            $description = ""
            try {
                if ($proc.MainModule) {
                    $description = $proc.MainModule.FileVersionInfo.FileDescription
                    if (-not $description) {
                        $description = $proc.MainModule.FileVersionInfo.ProductName
                    }
                }
                if (-not $description) {
                    $description = "Processo di sistema"
                }
            }
            catch {
                $description = "Accesso negato"
            }
            
            $item.SubItems.Add($description)
            $listView.Items.Add($item)
        }
    }
    catch {
        Write-Log "❌ Errore caricamento processi: $($_.Exception.Message)"
    }
    
    $form.Controls.Add($listView)
    
    # Pulsanti con design moderno
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(460, 455)
    $okButton.Size = New-Object System.Drawing.Size(80, 35)
    $okButton.Text = "Seleziona"
    $okButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $okButton.BackColor = [System.Drawing.Color]::FromArgb(0, 212, 170)
    $okButton.ForeColor = [System.Drawing.Color]::White
    $okButton.FlatStyle = "Flat"
    $okButton.Add_Click({
        if ($listView.SelectedItems.Count -gt 0) {
            $form.Tag = $listView.SelectedItems[0].Text
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        } else {
            [System.Windows.Forms.MessageBox]::Show("Seleziona un processo dalla lista", "⚠️ Attenzione", "OK", "Warning")
        }
    })
    $form.Controls.Add($okButton)
    
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(545, 455)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 35)
    $cancelButton.Text = "Annulla"
    $cancelButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $cancelButton.BackColor = [System.Drawing.Color]::FromArgb(231, 76, 60)
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
        Write-Log "✅ Processo selezionato: $selectedProcess"
        return $selectedProcess
    }
    return $null
}

# === FUNZIONI PRINCIPALI MIGLIORATE ===
function Invoke-Boost {
    Write-Log "⚡ === AVVIO MODALITA' GAMING BOOST v2.0 ==="
    
    try {
        $exclusions = Load-Exclusions
        Write-Log "🛡️ Caricate $($exclusions.Count) esclusioni"
        
        # Processi critici aggiuntivi (oltre a quelli nell'exclusions.json)
        $criticalProcesses = @(
            "System", "Registry", "Idle", "kaosFWD-Booster", "MsMpEng", "NisSrv", "SecurityHealthService"
        )
        
        # Combina esclusioni
        $allExclusions = $exclusions + $criticalProcesses | Sort-Object -Unique
        Write-Log "🔒 Esclusioni totali: $($allExclusions.Count)"
        
        $closedApps = @()
        $currentPID = $PID
        
        # Ottieni lista processi da chiudere con filtri migliorati
        $processesToClose = Get-Process | Where-Object {
            $_.Id -ne $currentPID -and
            -not ($allExclusions -contains $_.ProcessName) -and
            $_.ProcessName -ne "" -and
            $_.ProcessName -notlike "svchost*" -and  # Evita servizi critici
            $_.ProcessName -notlike "Windows*" -and   # Evita processi Windows core
            $_.WorkingSet64 -gt 10MB                  # Solo processi che usano >10MB RAM
        }
        
        Write-Log "🎯 Trovati $($processesToClose.Count) processi da chiudere"
        
        $successCount = 0
        $failCount = 0
        $totalProcesses = $processesToClose.Count
        $currentProcess = 0
        
        foreach ($proc in $processesToClose) {
            $currentProcess++
            $progress = [math]::Round(($currentProcess / $totalProcesses) * 100, 1)
            
            try {
                $procPath = $null
                $procMemory = 0
                
                try {
                    $procPath = $proc.Path
                    $procMemory = [math]::Round($proc.WorkingSet64 / 1MB, 1)
                } catch {
                    # Alcuni processi non hanno path/memoria accessibile
                }
                
                $procName = $proc.ProcessName
                
                Write-Log "🔄 [$progress%] Elaborando: $procName (${procMemory}MB)"
                
                # Tentativo di chiusura gentile prima
                $closed = $false
                if ($proc.MainWindowHandle -ne 0) {
                    try {
                        if ($proc.CloseMainWindow()) {
                            Start-Sleep -Milliseconds 150
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
                        Start-Sleep -Milliseconds 50
                        $closed = $true
                    } catch { }
                }
                
                if ($closed) {
                    $closedApps += @{
                        Name = $procName
                        Path = $procPath
                        Memory = $procMemory
                        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                    Write-Log "✅ Chiuso: $procName"
                    $successCount++
                } else {
                    Write-Log "⚠️ Non chiuso: $procName"
                    $failCount++
                }
            }
            catch {
                Write-Log "❌ Errore con $($proc.ProcessName): $($_.Exception.Message)"
                $failCount++
            }
        }
        
        # Salva lista app chiuse
        try {
            $closedApps | ConvertTo-Json -Depth 10 | Out-File $ClosedAppsFile -Encoding UTF8
        } catch {
            Write-Log "❌ Errore salvataggio app chiuse: $($_.Exception.Message)"
        }
        
        # Ottimizzazione memoria aggressiva
        Write-Log "🧹 Pulizia memoria di sistema..."
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        # Statistiche finali
        $memoryFreed = ($closedApps | Measure-Object -Property Memory -Sum).Sum
        
        Write-Log "🎉 === BOOST COMPLETATO === 🎉"
        Write-Log "📊 Successi: $successCount | Fallimenti: $failCount"
        Write-Log "💾 Memoria liberata: ~${memoryFreed}MB"
        Write-Log "🚀 Sistema ottimizzato per il gaming!"
        
    } catch {
        Write-Log "💥 ERRORE CRITICO durante il boost: $($_.Exception.Message)"
        Show-Console
    }
}

function Restore-Apps {
    Write-Log "🔄 === AVVIO RIPRISTINO APPLICAZIONI ==="
    
    try {
        if (-not (Test-Path $ClosedAppsFile)) {
            Write-Log "📂 Nessun file di ripristino trovato"
            return
        }
        
        $content = Get-Content $ClosedAppsFile -Raw -Encoding UTF8
        if (-not $content -or $content.Trim() -eq "" -or $content.Trim() -eq "[]") {
            Write-Log "📋 Nessuna applicazione da ripristinare"
            return
        }
        
        $appsToRestore = $content | ConvertFrom-Json
        if (-not $appsToRestore -or $appsToRestore.Count -eq 0) {
            Write-Log "📝 Lista ripristino vuota"
            return
        }
        
        Write-Log "🔍 Trovate $($appsToRestore.Count) applicazioni da ripristinare"
        
        $restoredCount = 0
        $failedCount = 0
        $totalApps = $appsToRestore.Count
        $currentApp = 0
        
        foreach ($app in $appsToRestore) {
            $currentApp++
            $progress = [math]::Round(($currentApp / $totalApps) * 100, 1)
            
            try {
                Write-Log "🔄 [$progress%] Ripristinando: $($app.Name)"
                
                if ($app.Path -and (Test-Path $app.Path)) {
                    Start-Process $app.Path -ErrorAction Stop
                    Write-Log "✅ Riaperto: $($app.Name)"
                    $restoredCount++
                    Start-Sleep -Milliseconds 200
                } else {
                    Write-Log "⚠️ Path non trovato per: $($app.Name)"
                    $failedCount++
                }
            }
            catch {
                Write-Log "❌ Errore riaprendo $($app.Name): $($_.Exception.Message)"
                $failedCount++
            }
        }
        
        # Pulisci file ripristino
        @() | ConvertTo-Json | Out-File $ClosedAppsFile -Encoding UTF8
        
        Write-Log "🎉 === RIPRISTINO COMPLETATO ==="
        Write-Log "📊 Riaperte: $restoredCount | Fallite: $failedCount"
        
    } catch {
        Write-Log "💥 ERRORE durante il ripristino: $($_.Exception.Message)"
        Show-Console
    }
}