Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Carica Microsoft.VisualBasic per InputBox
try {
    Add-Type -AssemblyName Microsoft.VisualBasic
} catch {
    # Se fallisce, useremo una finestra personalizzata
}

# Percorsi file
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$GuiPath = Join-Path $ScriptDir "gui.xaml"
$ExclusionsFile = Join-Path $ScriptDir "exclusions.json"
$ClosedAppsFile = Join-Path $ScriptDir "closed_apps.json"

# Verifica GUI
if (-not (Test-Path $GuiPath)) {
    Write-Host "File GUI non trovato: $GuiPath"
    Read-Host "Premi INVIO per uscire"
    exit
}

# Crea file se non esistono
if (-not (Test-Path $ExclusionsFile)) {
    $defaultExclusions = @("explorer", "powershell", "cmd", "winlogon", "csrss", "wininit", "services", "lsass", "dwm")
    $defaultExclusions | ConvertTo-Json | Out-File $ExclusionsFile -Encoding UTF8
}

if (-not (Test-Path $ClosedAppsFile)) {
    @() | ConvertTo-Json | Out-File $ClosedAppsFile -Encoding UTF8
}

# Variabile globale
$global:LogBox = $null

# Funzioni
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
        $content = Get-Content $ExclusionsFile -Raw
        if ($content.Trim()) {
            return ($content | ConvertFrom-Json)
        }
    }
    catch {
        Write-Log "Errore caricamento esclusioni"
    }
    return @("explorer", "powershell", "cmd", "winlogon", "csrss", "wininit", "services", "lsass", "dwm")
}

function Save-Exclusions {
    param($list)
    try {
        $list | ConvertTo-Json | Out-File $ExclusionsFile -Encoding UTF8
        Write-Log "Esclusioni salvate"
    }
    catch {
        Write-Log "Errore salvataggio esclusioni"
    }
}

function Show-InputBox {
    param([string]$Title, [string]$Prompt)
    
    # Prova prima con Microsoft.VisualBasic
    try {
        return [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, $Title)
    } catch {
        # Fallback: usando Windows.Forms
        $form = New-Object System.Windows.Forms.Form
        $form.Text = $Title
        $form.Size = New-Object System.Drawing.Size(400, 150)
        $form.StartPosition = "CenterParent"
        $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $form.ForeColor = [System.Drawing.Color]::White
        
        $label = New-Object System.Windows.Forms.Label
        $label.Location = New-Object System.Drawing.Point(10, 20)
        $label.Size = New-Object System.Drawing.Size(370, 20)
        $label.Text = $Prompt
        $form.Controls.Add($label)
        
        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Location = New-Object System.Drawing.Point(10, 50)
        $textBox.Size = New-Object System.Drawing.Size(360, 20)
        $form.Controls.Add($textBox)
        
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Location = New-Object System.Drawing.Point(215, 80)
        $okButton.Size = New-Object System.Drawing.Size(75, 23)
        $okButton.Text = "OK"
        $okButton.Add_Click({ $form.DialogResult = "OK" })
        $form.Controls.Add($okButton)
        
        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Location = New-Object System.Drawing.Point(295, 80)
        $cancelButton.Size = New-Object System.Drawing.Size(75, 23)
        $cancelButton.Text = "Annulla"
        $cancelButton.Add_Click({ $form.DialogResult = "Cancel" })
        $form.Controls.Add($cancelButton)
        
        $form.AcceptButton = $okButton
        $form.CancelButton = $cancelButton
        
        if ($form.ShowDialog() -eq "OK") {
            return $textBox.Text
        }
        return ""
    }
}

function Show-ProcessSelector {
    # Usa Windows Forms per semplicità
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Seleziona Processo"
    $form.Size = New-Object System.Drawing.Size(500, 400)
    $form.StartPosition = "CenterParent"
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::White
    
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(470, 20)
    $label.Text = "Seleziona un processo dalla lista:"
    $form.Controls.Add($label)
    
    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(10, 40)
    $listBox.Size = New-Object System.Drawing.Size(460, 280)
    $listBox.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
    $listBox.ForeColor = [System.Drawing.Color]::White
    
    # Carica processi
    $processes = Get-Process | Sort-Object ProcessName | ForEach-Object { 
        "$($_.ProcessName) (PID: $($_.Id))" 
    }
    foreach ($proc in $processes) {
        $listBox.Items.Add($proc)
    }
    
    $form.Controls.Add($listBox)
    
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(315, 330)
    $okButton.Size = New-Object System.Drawing.Size(75, 23)
    $okButton.Text = "Seleziona"
    $okButton.Add_Click({ 
        if ($listBox.SelectedItem) {
            $form.DialogResult = "OK"
        }
    })
    $form.Controls.Add($okButton)
    
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(395, 330)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 23)
    $cancelButton.Text = "Annulla"
    $cancelButton.Add_Click({ $form.DialogResult = "Cancel" })
    $form.Controls.Add($cancelButton)
    
    if ($form.ShowDialog() -eq "OK" -and $listBox.SelectedItem) {
        $selectedText = $listBox.SelectedItem
        return ($selectedText -split ' \(PID:')[0]
    }
    return ""
}

function Invoke-Boost {
    Write-Log "Avvio modalità Boost..."
    
    $Exclusions = Load-Exclusions
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
            try { 
                $path = $proc.Path 
            }
            catch { }
            
            if ($proc.CloseMainWindow()) {
                Start-Sleep -Milliseconds 300
            }
            
            if (-not $proc.HasExited) {
                $proc.Kill()
            }
            
            $ClosedList += @{
                Name = $proc.ProcessName
                Path = $path
            }
            
            Write-Log "Chiuso: $($proc.ProcessName)"
        }
        catch {
            Write-Log "Errore chiudendo $($proc.ProcessName)"
        }
    }
    
    try {
        $ClosedList | ConvertTo-Json | Out-File $ClosedAppsFile -Encoding UTF8
        Write-Log "Modalità Boost attivata! Chiusi $($ClosedList.Count) processi"
    }
    catch {
        Write-Log "Errore salvando lista app chiuse"
    }
    
    [System.GC]::Collect()
    Write-Log "Memoria ottimizzata"
}

function Restore-Apps {
    Write-Log "Avvio ripristino applicazioni..."
    
    if (-not (Test-Path $ClosedAppsFile)) {
        Write-Log "Nessuna app da riaprire"
        return
    }
    
    try {
        $content = Get-Content $ClosedAppsFile -Raw
        if (-not $content.Trim()) {
            Write-Log "Lista app vuota"
            return
        }
        
        $Apps = $content | ConvertFrom-Json
        $RestoredCount = 0
        
        foreach ($app in $Apps) {
            if ($app.Path -and (Test-Path $app.Path)) {
                try {
                    Start-Process $app.Path
                    Write-Log "Riaperto: $($app.Name)"
                    $RestoredCount++
                    Start-Sleep -Milliseconds 200
                }
                catch {
                    Write-Log "Errore riaprendo $($app.Name)"
                }
            }
        }
        
        @() | ConvertTo-Json | Out-File $ClosedAppsFile -Encoding UTF8
        Write-Log "Ripristino completato! Riaperti $RestoredCount processi"
    }
    catch {
        Write-Log "Errore durante il ripristino"
    }
}

# Carica GUI
try {
    [xml]$XAML = Get-Content $GuiPath -Encoding UTF8
    $Reader = (New-Object System.Xml.XmlNodeReader $XAML)
    $Window = [Windows.Markup.XamlReader]::Load($Reader)
}
catch {
    Write-Host "Errore caricamento GUI"
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

# Verifica controlli
if (-not $BoostBtn -or -not $RestoreBtn -or -not $AddBtn -or -not $RemoveBtn -or -not $ExclusionList -or -not $global:LogBox) {
    Write-Host "Errore: Controlli GUI non trovati"
    Read-Host "Premi INVIO per uscire"
    exit
}

# Carica esclusioni
try {
    $ExclusionList.ItemsSource = Load-Exclusions
    Write-Log "kaosFWD Booster caricato correttamente"
}
catch {
    Write-Log "Errore caricamento esclusioni"
}

# Eventi
$BoostBtn.Add_Click({
    $BoostBtn.IsEnabled = $false
    try {
        Invoke-Boost
    }
    finally {
        $BoostBtn.IsEnabled = $true
    }
})

$RestoreBtn.Add_Click({
    $RestoreBtn.IsEnabled = $false
    try {
        Restore-Apps
    }
    finally {
        $RestoreBtn.IsEnabled = $true
    }
})

$AddBtn.Add_Click({
    # Menu di scelta semplice
    $choice = [System.Windows.MessageBox]::Show("Come vuoi aggiungere l'esclusione?`n`nSì = Inserisci manualmente`nNo = Seleziona da processi correnti", "Metodo di aggiunta", "YesNoCancel", "Question")
    
    $input = ""
    if ($choice -eq "Yes") {
        $input = Show-InputBox "Aggiungi esclusione" "Inserisci nome processo (senza .exe):"
    }
    elseif ($choice -eq "No") {
        $input = Show-ProcessSelector
    }
    
    if ($input -and $input.Trim() -ne "") {
        $input = $input.Trim()
        $list = Load-Exclusions
        if (-not ($list -contains $input)) {
            $list += $input
            Save-Exclusions $list
            $ExclusionList.ItemsSource = $null
            $ExclusionList.ItemsSource = $list
            Write-Log "Aggiunta esclusione: $input"
        }
        else {
            Write-Log "Esclusione già presente: $input"
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
        Write-Log "Rimossa esclusione: $selectedItem"
    }
    else {
        Write-Log "Seleziona un elemento da rimuovere"
    }
})

$Window.Add_Closing({
    Write-Log "Chiusura kaosFWD Booster"
})

# Mostra finestra
try {
    Write-Log "Interfaccia pronta all'uso"
    $null = $Window.ShowDialog()
}
catch {
    Write-Host "Errore visualizzazione finestra"
    Read-Host "Premi INVIO per uscire"
}