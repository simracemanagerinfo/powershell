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

# Supporta eventuali script versionati aggiunti in futuro senza richiedere una
# nuova logica di copia nel comando reload.
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
