Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Percorsi file dati
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$GuiPath = Join-Path $ScriptDir "gui.xaml"
if (-not (Test-Path $GuiPath)) {
    [System.Windows.MessageBox]::Show("File GUI non trovato: $GuiPath", "Errore avvio", "OK", "Error")
    pause
    exit
}

$ExclusionsFile = Join-Path $ScriptDir "exclusions.json"
$ClosedAppsFile = Join-Path $ScriptDir "closed_apps.json"

# Crea file exclusions se non esiste
if (-not (Test-Path $ExclusionsFile)) {
    @("explorer", "powershell", "cmd") | ConvertTo-Json | Out-File $ExclusionsFile -Encoding UTF8
}

# Funzione per caricare le esclusioni
function Load-Exclusions {
    return (Get-Content $ExclusionsFile | ConvertFrom-Json)
}

# Funzione per salvare esclusioni
function Save-Exclusions($list) {
    $list | ConvertTo-Json | Out-File $ExclusionsFile -Encoding UTF8
}

# Funzione per eseguire Boost
function Boost {
    $Exclusions = Load-Exclusions
    $Protected = @("System", "Registry", "Idle") # processi che non tocchiamo mai

    $ClosedList = @()
    foreach ($proc in Get-Process) {
        if (-not ($Exclusions -contains $proc.ProcessName) -and -not ($Protected -contains $proc.ProcessName)) {
            try {
                $path = $null
                try { $path = $proc.Path } catch {}
                $proc.Kill()
                $ClosedList += [PSCustomObject]@{
                    Name = $proc.ProcessName
                    Path = $path
                }
                $LogBox.AppendText("Chiuso: $($proc.ProcessName)`n")
            } catch {
                $LogBox.AppendText("Errore chiudendo $($proc.ProcessName)`n")
            }
        }
    }
    $ClosedList | ConvertTo-Json | Out-File $ClosedAppsFile -Encoding UTF8
    $LogBox.AppendText("Modalità Boost attivata!`n")
}

# Funzione per ripristinare app chiuse
function Restore-Apps {
    if (-not (Test-Path $ClosedAppsFile)) {
        $LogBox.AppendText("Nessuna app da riaprire.`n")
        return
    }
    $Apps = Get-Content $ClosedAppsFile | ConvertFrom-Json
    foreach ($app in $Apps) {
        if ($app.Path -and (Test-Path $app.Path)) {
            try {
                Start-Process $app.Path
                $LogBox.AppendText("Riaperto: $($app.Name)`n")
            } catch {
                $LogBox.AppendText("Errore riaprendo $($app.Name)`n")
            }
        }
    }
    Remove-Item $ClosedAppsFile -ErrorAction SilentlyContinue
    $LogBox.AppendText("Stato predefinito ripristinato!`n")
}

# Carica GUI
[xml]$XAML = Get-Content $GuiPath
$Reader = (New-Object System.Xml.XmlNodeReader $XAML)
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# Collega controlli
$BoostBtn = $Window.FindName("BoostBtn")
$RestoreBtn = $Window.FindName("RestoreBtn")
$AddBtn = $Window.FindName("AddBtn")
$RemoveBtn = $Window.FindName("RemoveBtn")
$ExclusionList = $Window.FindName("ExclusionList")
$LogBox = $Window.FindName("LogBox")

# Carica lista esclusioni nella GUI
$ExclusionList.ItemsSource = Load-Exclusions()

# Eventi
$BoostBtn.Add_Click({ Boost })
$RestoreBtn.Add_Click({ Restore-Apps })
$AddBtn.Add_Click({
    $input = [System.Windows.Forms.InputBox]::Show("Inserisci nome processo (senza .exe)", "Aggiungi esclusione")
    if ($input -and $input -ne "") {
        $list = Load-Exclusions()
        if (-not ($list -contains $input)) {
            $list += $input
            Save-Exclusions $list
            $ExclusionList.ItemsSource = $null
            $ExclusionList.ItemsSource = $list
        }
    }
})
$RemoveBtn.Add_Click({
    if ($ExclusionList.SelectedItem) {
        $list = Load-Exclusions() | Where-Object { $_ -ne $ExclusionList.SelectedItem }
        Save-Exclusions $list
        $ExclusionList.ItemsSource = $null
        $ExclusionList.ItemsSource = $list
    }
})

# Mostra finestra
$Window.ShowDialog() | Out-Null
pause
