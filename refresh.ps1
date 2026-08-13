[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$runtimeRoot = Join-Path $env:LOCALAPPDATA 'PowerShellCustomization'
$sourceRoot = $PSScriptRoot

function Copy-TextFileIfChanged {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        return $false
    }

    $content = [IO.File]::ReadAllText($Source)
    if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and
        [IO.File]::ReadAllText($Destination) -ceq $content) {
        return $false
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
    [IO.File]::WriteAllText($Destination, $content, [Text.UTF8Encoding]::new($false))
    return $true
}

New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
$changed = @()

if (Copy-TextFileIfChanged -Source (Join-Path $sourceRoot 'profiles\common\common.ps1') -Destination (Join-Path $runtimeRoot 'common.ps1')) {
    $changed += 'common.ps1'
}

# Command plugin: la directory runtime viene mantenuta allineata al clone.
# Basta aggiungere/rimuovere un *.ps1 in commands/ e lanciare reload.
$commandsSource = Join-Path $sourceRoot 'commands'
$commandsTarget = Join-Path $runtimeRoot 'commands'
New-Item -ItemType Directory -Path $commandsTarget -Force | Out-Null

$sourceCommandNames = @()
if (Test-Path -LiteralPath $commandsSource -PathType Container) {
    foreach ($file in Get-ChildItem -LiteralPath $commandsSource -File -Filter '*.ps1') {
        $sourceCommandNames += $file.Name
        $destination = Join-Path $commandsTarget $file.Name
        if (Copy-TextFileIfChanged -Source $file.FullName -Destination $destination) {
            $changed += "commands/$($file.Name)"
        }
    }
}

foreach ($runtimeCommand in Get-ChildItem -LiteralPath $commandsTarget -File -Filter '*.ps1' -ErrorAction SilentlyContinue) {
    if ($runtimeCommand.Name -notin $sourceCommandNames) {
        Remove-Item -LiteralPath $runtimeCommand.FullName -Force
        $changed += "commands/$($runtimeCommand.Name) (rimosso)"
    }
}

# OpenShift/Stern resta opzionale anche durante il refresh.
$openShiftEnabled = $false
$optionsPath = Join-Path $runtimeRoot 'install-options.json'
if (Test-Path -LiteralPath $optionsPath -PathType Leaf) {
    try {
        $options = [IO.File]::ReadAllText($optionsPath) | ConvertFrom-Json
        if ($options.PSObject.Properties['OpenShiftStern']) {
            $openShiftEnabled = [bool]$options.OpenShiftStern
        }
    }
    catch {
        Write-Warning "Impossibile leggere le opzioni installate: $($_.Exception.Message)"
    }
}

$openShiftSource = Join-Path $sourceRoot 'profiles\features\openshift-stern.ps1'
$openShiftTarget = Join-Path $runtimeRoot 'openshift-stern.ps1'
if ($openShiftEnabled) {
    if (Copy-TextFileIfChanged -Source $openShiftSource -Destination $openShiftTarget) {
        $changed += 'openshift-stern.ps1'
    }
}
elseif (Test-Path -LiteralPath $openShiftTarget -PathType Leaf) {
    Remove-Item -LiteralPath $openShiftTarget -Force
    $changed += 'openshift-stern.ps1 (rimosso)'
}

# Supporta eventuali script/config di supporto aggiunti in futuro senza richiedere
# modifiche al core. I command possono richiamarli dal runtime scripts/.
$scriptsSource = Join-Path $sourceRoot 'scripts'
if (Test-Path -LiteralPath $scriptsSource -PathType Container) {
    foreach ($file in Get-ChildItem -LiteralPath $scriptsSource -File) {
        $destination = Join-Path (Join-Path $runtimeRoot 'scripts') $file.Name
        if (Copy-TextFileIfChanged -Source $file.FullName -Destination $destination) {
            $changed += "scripts/$($file.Name)"
        }
    }
}

if ($changed.Count -eq 0) {
    Write-Host '[OK] Runtime PowerShell già aggiornato.' -ForegroundColor Green
}
else {
    Write-Host "Runtime aggiornato: $($changed -join ', ')" -ForegroundColor Green
}
