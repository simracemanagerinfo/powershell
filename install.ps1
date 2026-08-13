[CmdletBinding()]
param(
    [switch]$SkipDependencies,
    [switch]$Reconfigure,

    [Parameter(DontShow)]
    [AllowNull()]
    [Nullable[bool]]$OpenShiftSternOverride,

    [Parameter(DontShow)]
    [AllowNull()]
    [string]$ProfilePathOverride,

    [Parameter(DontShow)]
    [AllowNull()]
    [string[]]$LaunchersOverride,

    [Parameter(DontShow)]
    [AllowNull()]
    [string]$RuntimeRootOverride,

    [Parameter(DontShow)]
    [AllowNull()]
    [string]$TerminalSettingsPathOverride,

    [Parameter(DontShow)]
    [AllowNull()]
    [string]$FragmentRootOverride,

    [Parameter(DontShow)]
    [AllowNull()]
    [string]$StartMenuRootOverride
)

$ErrorActionPreference = 'Stop'

$scriptPath = $MyInvocation.MyCommand.Path
$corePath = Join-Path $PSScriptRoot 'install-core.ps1'
$forwardParameters = @{}
foreach ($key in $PSBoundParameters.Keys) {
    $forwardParameters[$key] = $PSBoundParameters[$key]
}

function Refresh-BootstrapPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($machine, $user, $env:Path) -join ';'
    $env:Path = (($parts -split ';' |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique) -join ';')
}

function Ensure-WindowsAppsPath {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { return }

    $windowsApps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (-not (Test-Path -LiteralPath $windowsApps -PathType Container)) { return }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $userParts = @()
    if (-not [string]::IsNullOrWhiteSpace($userPath)) {
        $userParts = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    if (-not ($userParts | Where-Object { $_.TrimEnd('\') -ieq $windowsApps.TrimEnd('\') })) {
        $userParts += $windowsApps
        [Environment]::SetEnvironmentVariable('Path', (($userParts | Select-Object -Unique) -join ';'), 'User')
        Write-Host '[BOOTSTRAP] Aggiunto Microsoft\WindowsApps al PATH utente.' -ForegroundColor Cyan
    }

    Refresh-BootstrapPath
}

function Resolve-BootstrapCommand {
    param([Parameter(Mandatory)][string]$Name)

    Refresh-BootstrapPath
    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }

    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $alias = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\$Name"
        if (Test-Path -LiteralPath $alias -PathType Leaf) { return $alias }
    }

    return $null
}

function Get-PowerShell7Path {
    $resolved = Resolve-BootstrapCommand -Name 'pwsh.exe'
    if ($resolved) { return $resolved }

    $programFilesCandidate = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
    if (Test-Path -LiteralPath $programFilesCandidate -PathType Leaf) {
        return $programFilesCandidate
    }

    return $null
}

function Ensure-SupportedWindows {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        throw 'Questo installer è supportato solo su Windows.'
    }

    $versionKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $buildText = (Get-ItemProperty -LiteralPath $versionKey -Name CurrentBuildNumber -ErrorAction Stop).CurrentBuildNumber
    $build = 0
    if (-not [int]::TryParse([string]$buildText, [ref]$build)) {
        throw "Impossibile determinare la build di Windows: $buildText"
    }

    if ($build -lt 19045) {
        throw "Versione Windows non supportata (build $build). Richiesto Windows 10 22H2 build 19045 o successivo."
    }
}

function Get-WinGetPath {
    Ensure-WindowsAppsPath
    $winget = Resolve-BootstrapCommand -Name 'winget.exe'
    if (-not $winget) {
        throw 'WinGet non è disponibile. Installa o aggiorna Microsoft App Installer, quindi rilancia install.ps1.'
    }
    return $winget
}

function Install-PowerShell7Bootstrap {
    param([Parameter(Mandatory)][string]$WingetPath)

    Write-Host '[BOOTSTRAP] PowerShell 7 non trovato. Lo installo per l’utente corrente...' -ForegroundColor Cyan
    & $WingetPath install --id Microsoft.PowerShell --exact --source winget --scope user --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) {
        throw "Installazione di PowerShell 7 fallita. WinGet exit code: $LASTEXITCODE"
    }

    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        Ensure-WindowsAppsPath
        $pwsh = Get-PowerShell7Path
        if ($pwsh) { return $pwsh }
        Start-Sleep -Seconds 1
    }

    throw 'PowerShell 7 risulta installato, ma pwsh.exe non è disponibile nel PATH o negli App Execution Alias.'
}

function Invoke-InstallerWithPowerShell7 {
    param([Parameter(Mandatory)][string]$PwshPath)

    $token = [Guid]::NewGuid().ToString('N')
    $argumentsFile = Join-Path $env:TEMP "powershell-customization-args-$token.clixml"
    $relayFile = Join-Path $env:TEMP "powershell-customization-relay-$token.ps1"

    $relay = @'
param(
    [Parameter(Mandatory)][string]$InstallerPath,
    [Parameter(Mandatory)][string]$ArgumentsFile
)
$ErrorActionPreference = 'Stop'
$bound = Import-Clixml -LiteralPath $ArgumentsFile
& $InstallerPath @bound
'@

    try {
        $forwardParameters | Export-Clixml -LiteralPath $argumentsFile
        [IO.File]::WriteAllText($relayFile, $relay, [Text.UTF8Encoding]::new($false))

        Write-Host '[BOOTSTRAP] Continuo automaticamente l’installazione con PowerShell 7...' -ForegroundColor Cyan
        & $PwshPath -NoLogo -NoProfile -ExecutionPolicy Bypass -File $relayFile -InstallerPath $scriptPath -ArgumentsFile $argumentsFile
        if ($LASTEXITCODE -ne 0) {
            throw "L'installazione eseguita con PowerShell 7 è terminata con exit code $LASTEXITCODE."
        }
    }
    finally {
        Remove-Item -LiteralPath $argumentsFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $relayFile -Force -ErrorAction SilentlyContinue
    }
}

function Assert-BaseRuntime {
    if ($SkipDependencies) { return }

    Ensure-WindowsAppsPath
    $missing = @()
    foreach ($dependency in @('pwsh.exe', 'wt.exe', 'oh-my-posh.exe')) {
        if (-not (Resolve-BootstrapCommand -Name $dependency)) {
            $missing += $dependency
        }
    }

    if ($missing.Count -gt 0) {
        throw "Installazione incompleta. Dipendenze obbligatorie non disponibili: $($missing -join ', ')."
    }
}

Ensure-SupportedWindows
Ensure-WindowsAppsPath

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    $pwsh = Get-PowerShell7Path
    if (-not $pwsh) {
        if ($SkipDependencies) {
            throw 'PowerShell 7 non è installato e -SkipDependencies impedisce il bootstrap automatico.'
        }
        $winget = Get-WinGetPath
        $pwsh = Install-PowerShell7Bootstrap -WingetPath $winget
    }

    Invoke-InstallerWithPowerShell7 -PwshPath $pwsh
    return
}

if (-not (Test-Path -LiteralPath $corePath -PathType Leaf)) {
    throw "Installer core mancante: $corePath"
}

if (-not $SkipDependencies) {
    Get-WinGetPath | Out-Null
}

& $corePath @forwardParameters
Assert-BaseRuntime
