<#
.SYNOPSIS
    Debloat sicuro per PC aziendali Windows 10/11 Pro (domain-joined).

.DESCRIPTION
    - Rimuove app Appx preinstallate non necessarie (solo da lista esplicita)
    - Applica policy di privacy/telemetria compatibili con Windows Pro
    - Disabilita un piccolo elenco di servizi inutili in ambito aziendale
    - NON tocca mai servizi di stampa, dominio, rete, sicurezza o aggiornamento
      (vedi $ProtectedServices: il script si blocca se un servizio protetto
      finisse per errore nella lista di quelli da disabilitare)

.PARAMETER WhatIf
    Dry run: mostra cosa verrebbe fatto senza modificare nulla. Consigliato al primo avvio.

.PARAMETER SkipRestorePoint
    Non crea il punto di ripristino.

.PARAMETER RemoveOneDrive
    Disinstalla anche OneDrive (OFF di default: potrebbe essere usato in azienda).

.EXAMPLE
    .\Debloat-Windows.ps1 -WhatIf
    .\Debloat-Windows.ps1
    .\Debloat-Windows.ps1 -RemoveOneDrive
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipRestorePoint,
    [switch]$RemoveOneDrive
)

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------
$LogDir  = Join-Path $env:ProgramData 'Debloat\logs'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir ("debloat_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR','OK')][string]$Level = 'INFO')
    $line = "[{0:HH:mm:ss}] [{1}] {2}" -f (Get-Date), $Level, $Message
    Add-Content -Path $LogFile -Value $line
    $color = @{INFO='Gray'; WARN='Yellow'; ERROR='Red'; OK='Green'}[$Level]
    Write-Host $line -ForegroundColor $color
}

# ----------------------------------------------------------------------------
# Servizi protetti: NON vengono mai disabilitati (stampa, dominio, rete, sicurezza)
# ----------------------------------------------------------------------------
$ProtectedServices = @(
    # Stampa
    'Spooler','PrintNotify','PrintWorkflowUserSvc','PrintDeviceConfigurationService','PrintScanBrokerService',
    'Fax','WSDScan','stisvc','FDResPub','fdPHost','SSDPSRV','upnphost',
    # Dominio / autenticazione / GPO
    'Netlogon','LanmanWorkstation','LanmanServer','KDC','Kerberos','W32Time','gpsvc','ProfSvc','SamSs',
    'lsass','CryptSvc','Dnscache','NlaSvc','netprofm','RpcSs','RpcEptMapper','DcomLaunch','LSM',
    'Winmgmt','WinRM','Schedule','EventLog','SENS','UserManager','TrustedInstaller',
    # Rete
    'Dhcp','nsi','BFE','mpssvc','iphlpsvc','netman','NcaSvc','NcbService','Wcmsvc','WlanSvc','LanmanSvc',
    'RasMan','RemoteAccess','SessionEnv','TermService','UmRdpService',
    # Sicurezza / aggiornamenti / gestione
    'WinDefend','Sense','wscsvc','SecurityHealthService','wuauserv','UsoSvc','BITS','DoSvc',
    'WaaSMedicSvc','Appinfo','VSS','swprv','CertPropSvc','SCardSvr','ScDeviceEnum','Netlogon',
    'dot3svc','EapHost','PolicyAgent','IKEEXT','RemoteRegistry','smphost','ClipSVC','StorSvc'
)

# ----------------------------------------------------------------------------
# Servizi da disabilitare (Manual/Disabled) - solo roba inutile in ufficio
# ----------------------------------------------------------------------------
$ServicesToDisable = @(
    'DiagTrack',          # Telemetria "Connected User Experiences"
    'dmwappushservice',   # WAP push (telemetria)
    'MapsBroker',         # Mappe offline
    'XblAuthManager',     # Xbox
    'XblGameSave',
    'XboxNetApiSvc',
    'XboxGipSvc',
    'RetailDemo',         # Modalita demo negozio
    'WMPNetworkSvc',      # Condivisione Windows Media Player
    'lfsvc',              # Geolocalizzazione
    'WerSvc'              # Segnalazione errori Windows
)

# Guardia di sicurezza: nessun servizio protetto nella lista da disabilitare
$conflict = $ServicesToDisable | Where-Object { $ProtectedServices -contains $_ }
if ($conflict) {
    Write-Log "ERRORE DI CONFIGURAZIONE: servizi protetti in lista disabilitazione: $($conflict -join ', ')" 'ERROR'
    exit 1
}

# ----------------------------------------------------------------------------
# App Appx da rimuovere (wildcard sul nome pacchetto)
# ----------------------------------------------------------------------------
$AppsToRemove = @(
    'Microsoft.BingNews','Microsoft.BingWeather','Microsoft.BingFinance','Microsoft.BingSports',
    'Microsoft.BingSearch','Microsoft.GetHelp','Microsoft.Getstarted','Microsoft.Microsoft3DViewer',
    'Microsoft.MicrosoftOfficeHub','Microsoft.MicrosoftSolitaireCollection','Microsoft.MixedReality.Portal',
    'Microsoft.People','Microsoft.SkypeApp','Microsoft.WindowsFeedbackHub','Microsoft.WindowsMaps',
    'Microsoft.Xbox*','Microsoft.GamingApp','Microsoft.ZuneMusic','Microsoft.ZuneVideo',
    'Microsoft.YourPhone','Microsoft.549981C3F5F10','Microsoft.Todos','Microsoft.PowerAutomateDesktop',
    'Microsoft.Clipchamp','Clipchamp.Clipchamp','MicrosoftTeams','MSTeams','Microsoft.DevHome',
    'Microsoft.OneConnect','Microsoft.Wallet','Microsoft.MicrosoftStickyNotes',
    'microsoft.windowscommunicationsapps',      # Mail/Calendario legacy
    'Microsoft.Copilot','Microsoft.Windows.Ai.Copilot.Provider',
    '*CandyCrush*','*Disney*','*Spotify*','*TikTok*','*Facebook*','*Instagram*','*Netflix*',
    '*AmazonPrimeVideo*','*LinkedInforWindows*','*Twitter*','*McAfee*','*Dropbox*','*Evernote*'
)

# App protette: mai rimosse, anche se per errore matchano una wildcard sopra
$ProtectedApps = @(
    'Microsoft.WindowsStore','Microsoft.StorePurchaseApp','Microsoft.DesktopAppInstaller',
    'Microsoft.WindowsCalculator','Microsoft.Windows.Photos','Microsoft.WindowsNotepad',
    'Microsoft.WindowsTerminal','Microsoft.Paint','Microsoft.ScreenSketch','Microsoft.SecHealthUI',
    'Microsoft.WindowsCamera','Microsoft.HEIFImageExtension','Microsoft.WebpImageExtension',
    'Microsoft.VCLibs*','Microsoft.NET*','Microsoft.UI.Xaml*','Microsoft.WindowsAppRuntime*',
    'Microsoft.MicrosoftEdge*','Microsoft.Win32WebViewHost','Microsoft.AAD.BrokerPlugin',
    'Microsoft.AccountsControl','Microsoft.LockApp','Microsoft.CredDialogHost',
    'Microsoft.ECApp','Microsoft.AsyncTextService','Microsoft.Windows.*','Windows.*',
    'Microsoft.PrintQueueActionCenter','Windows.PrintDialog','*Print*',
    'MicrosoftWindows.*','NcsiUwpApp','Microsoft.OutlookForWindows','Microsoft.Office.*'
)

function Test-Protected([string]$Name) {
    foreach ($p in $ProtectedApps) { if ($Name -like $p) { return $true } }
    return $false
}

# ----------------------------------------------------------------------------
# Controlli iniziali
# ----------------------------------------------------------------------------
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
Write-Log "Host: $env:COMPUTERNAME | OS: $($os.Caption) build $($os.BuildNumber)"
Write-Log ("Dominio: {0} (PartOfDomain={1})" -f $cs.Domain, $cs.PartOfDomain)
if ($os.Caption -notmatch 'Pro|Enterprise|Education') {
    Write-Log "Edizione non Pro/Enterprise/Education: alcune policy potrebbero non avere effetto." 'WARN'
}
if ($WhatIfPreference) { Write-Log "MODALITA DRY RUN (-WhatIf): nessuna modifica verra applicata." 'WARN' }

# ----------------------------------------------------------------------------
# Punto di ripristino
# ----------------------------------------------------------------------------
if (-not $SkipRestorePoint -and -not $WhatIfPreference) {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description 'Pre-Debloat' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log 'Punto di ripristino creato.' 'OK'
    } catch {
        Write-Log "Punto di ripristino non creato: $($_.Exception.Message)" 'WARN'
    }
}

# ----------------------------------------------------------------------------
# 1) Rimozione app Appx
# ----------------------------------------------------------------------------
Write-Log '--- Rimozione app preinstallate ---'
foreach ($pattern in $AppsToRemove) {
    # Pacchetti installati (tutti gli utenti)
    $installed = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
    foreach ($pkg in $installed) {
        if (Test-Protected $pkg.Name) { Write-Log "SKIP (protetta): $($pkg.Name)" 'WARN'; continue }
        if ($PSCmdlet.ShouldProcess($pkg.PackageFullName, 'Remove-AppxPackage -AllUsers')) {
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                Write-Log "Rimossa: $($pkg.Name)" 'OK'
            } catch { Write-Log "Errore rimuovendo $($pkg.Name): $($_.Exception.Message)" 'WARN' }
        }
    }
    # Pacchetti provisioned (evitano la reinstallazione per i nuovi utenti di dominio)
    $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $pattern }
    foreach ($pp in $prov) {
        if (Test-Protected $pp.DisplayName) { Write-Log "SKIP provisioned (protetta): $($pp.DisplayName)" 'WARN'; continue }
        if ($PSCmdlet.ShouldProcess($pp.DisplayName, 'Remove-AppxProvisionedPackage')) {
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null
                Write-Log "Rimosso provisioned: $($pp.DisplayName)" 'OK'
            } catch { Write-Log "Errore provisioned $($pp.DisplayName): $($_.Exception.Message)" 'WARN' }
        }
    }
}

# ----------------------------------------------------------------------------
# 2) Policy di registro (compatibili con Windows Pro)
# ----------------------------------------------------------------------------
Write-Log '--- Policy di privacy / telemetria / consumer ---'
$policies = @(
    # Telemetria al minimo consentito su Pro (1 = Basic/Required; 0 funziona solo su Enterprise)
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name='AllowTelemetry'; Value=1 },
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name='DoNotShowFeedbackNotifications'; Value=1 },
    # ID pubblicitario e suggerimenti
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name='DisabledByGroupPolicy'; Value=1 },
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableWindowsConsumerFeatures'; Value=1 },
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableSoftLanding'; Value=1 },
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableCloudOptimizedContent'; Value=1 },
    # Widget / News and Interests
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name='AllowNewsAndInterests'; Value=0 },
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'; Name='EnableFeeds'; Value=0 },
    # Copilot e Recall
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Value=1 },
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='DisableAIDataAnalysis'; Value=1 },
    # Chat consumer in taskbar
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat'; Name='ChatIcon'; Value=3 },
    # Ricerca web nel menu Start
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='DisableSearchBoxSuggestions'; Value=1 },
    # Segnalazione errori / esperienze personalizzate
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableTailoredExperiencesWithDiagnosticData'; Value=1 }
)
foreach ($p in $policies) {
    if ($PSCmdlet.ShouldProcess("$($p.Path)\$($p.Name)", "Set = $($p.Value)")) {
        try {
            if (-not (Test-Path $p.Path)) { New-Item -Path $p.Path -Force | Out-Null }
            New-ItemProperty -Path $p.Path -Name $p.Name -Value $p.Value -PropertyType DWord -Force | Out-Null
            Write-Log "Policy: $($p.Name) = $($p.Value)" 'OK'
        } catch { Write-Log "Errore policy $($p.Name): $($_.Exception.Message)" 'WARN' }
    }
}
if ($cs.PartOfDomain) {
    Write-Log 'PC in dominio: se hai GPO equivalenti, queste prevarranno sulle policy locali (comportamento normale).' 'INFO'
}

# ----------------------------------------------------------------------------
# 3) Servizi
# ----------------------------------------------------------------------------
Write-Log '--- Servizi ---'
foreach ($svcName in $ServicesToDisable) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if (-not $svc) { continue }
    if ($PSCmdlet.ShouldProcess($svcName, 'Stop + Set-Service Disabled')) {
        try {
            if ($svc.Status -eq 'Running') { Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue }
            Set-Service -Name $svcName -StartupType Disabled -ErrorAction Stop
            Write-Log "Servizio disabilitato: $svcName" 'OK'
        } catch { Write-Log "Errore servizio $svcName: $($_.Exception.Message)" 'WARN' }
    }
}

# ----------------------------------------------------------------------------
# 4) OneDrive (opzionale)
# ----------------------------------------------------------------------------
if ($RemoveOneDrive) {
    Write-Log '--- OneDrive ---'
    $setup = @("$env:SystemRoot\SysWOW64\OneDriveSetup.exe", "$env:SystemRoot\System32\OneDriveSetup.exe") |
             Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($setup -and $PSCmdlet.ShouldProcess('OneDrive', 'Uninstall')) {
        Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Process $setup -ArgumentList '/uninstall' -Wait
        Write-Log 'OneDrive disinstallato.' 'OK'
    }
}

# ----------------------------------------------------------------------------
# Verifica finale: servizi di stampa/dominio ancora a posto?
# ----------------------------------------------------------------------------
Write-Log '--- Verifica servizi critici ---'
foreach ($name in 'Spooler','Netlogon','LanmanWorkstation','gpsvc','W32Time') {
    $s = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($s) {
        $lvl = if ($s.StartType -eq 'Disabled') { 'ERROR' } else { 'OK' }
        Write-Log ("{0}: stato={1}, avvio={2}" -f $name, $s.Status, $s.StartType) $lvl
    }
}

Write-Log "Fine. Log salvato in: $LogFile" 'OK'
Write-Log 'Consigliato un riavvio per completare le modifiche.' 'INFO'
