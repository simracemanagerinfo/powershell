[CmdletBinding()]
param(
    [Parameter(DontShow)]
    [AllowNull()]
    [string]$ProfilePathOverride
)

$ErrorActionPreference = 'Continue'
$runtimeRoot = Join-Path $env:LOCALAPPDATA 'PowerShellCustomization'
$assetRoot = Join-Path $runtimeRoot 'assets'
$launcherRoot = Join-Path $runtimeRoot 'launchers'
$fragmentRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\PowerShellCustomization'
$documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
$profilePath = if ([string]::IsNullOrWhiteSpace($ProfilePathOverride)) {
    Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1'
}
else {
    [IO.Path]::GetFullPath($ProfilePathOverride)
}
$optionsPath = Join-Path $runtimeRoot 'install-options.json'
$launcherNames = @('Matrix GPT', 'Cyber Glass', 'Neon Dev', 'Stern HUD')
$selectedLaunchers = @($launcherNames)
if (Test-Path -LiteralPath $optionsPath -PathType Leaf) {
    try {
        $savedOptions = [IO.File]::ReadAllText($optionsPath) | ConvertFrom-Json
        if ($savedOptions.PSObject.Properties['Launchers']) {
            $candidateLaunchers = @($savedOptions.Launchers | Where-Object { $_ -in $launcherNames } | Select-Object -Unique)
            if ($candidateLaunchers.Count -gt 0) {
                $selectedLaunchers = $candidateLaunchers
            }
        }
    }
    catch { }
}

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('PASS','WARN','FAIL','SKIP')][string]$Status,
        [string]$Details = ''
    )
    $results.Add([pscustomobject]@{ Name = $Name; Status = $Status; Details = $Details })
}

foreach ($item in @(
    @{ Name = 'Windows Terminal'; Command = 'wt.exe' },
    @{ Name = 'PowerShell 7'; Command = 'pwsh.exe' },
    @{ Name = 'Oh My Posh'; Command = 'oh-my-posh.exe' })) {
    $command = Get-Command $item.Command -ErrorAction SilentlyContinue | Select-Object -First 1
    Add-Result -Name $item.Name -Status $(if ($command) { 'PASS' } else { 'FAIL' }) -Details $(if ($command) { $command.Source } else { 'Non trovato nel PATH' })
}

foreach ($module in @('PSReadLine', 'Terminal-Icons')) {
    $found = Get-Module -ListAvailable -Name $module | Select-Object -First 1
    Add-Result -Name "Modulo $module" -Status $(if ($found) { 'PASS' } else { 'FAIL' }) -Details $(if ($found) { [string]$found.Version } else { 'Non installato' })
}

$fontFound = $false
foreach ($registryPath in @(
    'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts',
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts')) {
    if (Test-Path $registryPath) {
        $names = (Get-ItemProperty $registryPath).PSObject.Properties.Name
        if ($names | Where-Object { $_ -like '*MesloLGM*' -or $_ -like '*Meslo LGM*' }) {
            $fontFound = $true
            break
        }
    }
}
Add-Result -Name 'MesloLGM Nerd Font' -Status $(if ($fontFound) { 'PASS' } else { 'WARN' }) -Details $(if ($fontFound) { 'Installato' } else { 'Non rilevato' })

$fragment = Join-Path $fragmentRoot 'powershell-customization.json'
$fragmentExists = Test-Path -LiteralPath $fragment -PathType Leaf
Add-Result -Name 'Windows Terminal fragment' -Status $(if ($fragmentExists) { 'PASS' } else { 'FAIL' }) -Details $fragment
if ($fragmentExists) {
    try {
        $fragmentJson = [IO.File]::ReadAllText($fragment) | ConvertFrom-Json
        $profileCount = @($fragmentJson.profiles).Count
        Add-Result -Name 'Profili Windows Terminal' -Status $(if ($profileCount -eq 4) { 'PASS' } else { 'FAIL' }) -Details "Profili rilevati: $profileCount"
    }
    catch {
        Add-Result -Name 'Profili Windows Terminal' -Status 'FAIL' -Details $_.Exception.Message
    }
}
else {
    Add-Result -Name 'Profili Windows Terminal' -Status 'FAIL' -Details 'Fragment non disponibile'
}

foreach ($shader in @('matrix_rain.hlsl', 'cyber_glass_hud.hlsl', 'neon_glow.hlsl')) {
    $path = Join-Path $fragmentRoot "shaders\$shader"
    Add-Result -Name "Shader $shader" -Status $(if (Test-Path -LiteralPath $path -PathType Leaf) { 'PASS' } else { 'FAIL' }) -Details $path
}

foreach ($asset in @(
    'icons\matrix_gpt.ico',
    'icons\matrix_gpt_clear.ico',
    'icons\svi_gpt_original.ico',
    'icons\stern_logs.ico',
    'watermarks\svi_gpt.png',
    'watermarks\stern_logs.png',
    'backgrounds\pool\01_roma_vaticano_neon.png',
    'backgrounds\pool\02_simrace_pitlane_neon.png',
    'backgrounds\pool\03_roma_colosseo_future.png',
    'backgrounds\pool\04_simrace_garage_future.png',
    'backgrounds\pool\05_roma_colosseo_rain.png',
    'backgrounds\pool\06_simrace_night_race.png',
    'backgrounds\current.png')) {
    $path = Join-Path $assetRoot $asset
    Add-Result -Name "Asset $asset" -Status $(if (Test-Path -LiteralPath $path -PathType Leaf) { 'PASS' } else { 'FAIL' }) -Details $path
}

foreach ($launcher in $launcherNames) {
    $path = Join-Path $launcherRoot "$launcher.exe"
    if ($launcher -in $selectedLaunchers) {
        Add-Result -Name "$launcher.exe" -Status $(if (Test-Path -LiteralPath $path -PathType Leaf) { 'PASS' } else { 'FAIL' }) -Details $path
    }
    else {
        Add-Result -Name "$launcher.exe" -Status 'SKIP' -Details 'Non selezionato durante l installazione'
    }
}

$profileExists = Test-Path -LiteralPath $profilePath -PathType Leaf
$profileManaged = $false
if ($profileExists) {
    $profileText = [IO.File]::ReadAllText($profilePath)
    $profileManaged = $profileText.Contains('# >>> powershell-customization managed >>>') -and
        $profileText.Contains('# <<< powershell-customization managed <<<')
}
Add-Result -Name 'PowerShell 7 profile' -Status $(if ($profileManaged) { 'PASS' } elseif ($profileExists) { 'WARN' } else { 'FAIL' }) -Details $profilePath

$openShiftEnabled = $false
if (Test-Path -LiteralPath $optionsPath -PathType Leaf) {
    try {
        $options = [IO.File]::ReadAllText($optionsPath) | ConvertFrom-Json
        $openShiftEnabled = [bool]$options.OpenShiftStern
    }
    catch { }
}

if ($openShiftEnabled) {
    foreach ($item in @(
        @{ Name = 'OpenShift CLI'; Command = 'oc.exe' },
        @{ Name = 'Stern'; Command = 'stern.exe' })) {
        $command = Get-Command $item.Command -ErrorAction SilentlyContinue | Select-Object -First 1
        Add-Result -Name $item.Name -Status $(if ($command) { 'PASS' } else { 'FAIL' }) -Details $(if ($command) { $command.Source } else { 'Non trovato nel PATH' })
    }

    $openShiftConfig = Join-Path $runtimeRoot 'openshift.local.json'
    Add-Result -Name 'Configurazione OpenShift locale' -Status $(if (Test-Path -LiteralPath $openShiftConfig -PathType Leaf) { 'PASS' } else { 'FAIL' }) -Details $openShiftConfig
}
else {
    Add-Result -Name 'OpenShift / Stern CLI' -Status 'SKIP' -Details 'Feature disabilitata; i launcher grafici restano indipendenti dalla CLI'
}

$results | Format-Table -AutoSize

if ($results.Status -contains 'FAIL') {
    exit 1
}
