[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$runtimeRoot = Join-Path $env:LOCALAPPDATA 'PowerShellCustomization'
$sourceRoot = $PSScriptRoot

function Write-TextIfChanged {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Destination
    )

    if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and
        [IO.File]::ReadAllText($Destination) -ceq $Content) {
        return $false
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
    [IO.File]::WriteAllText($Destination, $Content, [Text.UTF8Encoding]::new($false))
    return $true
}

function Copy-TextFileIfChanged {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        return $false
    }

    return Write-TextIfChanged -Content ([IO.File]::ReadAllText($Source)) -Destination $Destination
}

New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
$changed = @()

foreach ($fileName in @('common.ps1', 'bootstrap.ps1')) {
    $source = Join-Path $sourceRoot "profiles\common\$fileName"
    $destination = Join-Path $runtimeRoot $fileName
    if (Copy-TextFileIfChanged -Source $source -Destination $destination) {
        $changed += $fileName
    }
}

$runtimeSource = Join-Path $sourceRoot 'profiles\common\runtime.ps1'
$moduleTarget = Join-Path $runtimeRoot 'PowerShellCustomization.psm1'
$moduleContent = [IO.File]::ReadAllText($runtimeSource).TrimEnd("`r", "`n") +
    "`r`n`r`nExport-ModuleMember -Function * -Alias *`r`n"
if (Write-TextIfChanged -Content $moduleContent -Destination $moduleTarget) {
    $changed += 'PowerShellCustomization.psm1'
}

$sourceMarker = Join-Path $runtimeRoot 'source-root.txt'
$resolvedSource = [IO.Path]::GetFullPath($sourceRoot)
if (Write-TextIfChanged -Content $resolvedSource -Destination $sourceMarker) {
    $changed += 'source-root.txt'
}

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

$scriptsSource = Join-Path $sourceRoot 'scripts'
$scriptsTarget = Join-Path $runtimeRoot 'scripts'
New-Item -ItemType Directory -Path $scriptsTarget -Force | Out-Null
$sourceScriptNames = @()
if (Test-Path -LiteralPath $scriptsSource -PathType Container) {
    foreach ($file in Get-ChildItem -LiteralPath $scriptsSource -File) {
        $sourceScriptNames += $file.Name
        $destination = Join-Path $scriptsTarget $file.Name
        if (Copy-TextFileIfChanged -Source $file.FullName -Destination $destination) {
            $changed += "scripts/$($file.Name)"
        }
    }
}
foreach ($runtimeScript in Get-ChildItem -LiteralPath $scriptsTarget -File -ErrorAction SilentlyContinue) {
    if ($runtimeScript.Name -notin $sourceScriptNames) {
        Remove-Item -LiteralPath $runtimeScript.FullName -Force
        $changed += "scripts/$($runtimeScript.Name) (rimosso)"
    }
}

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

$featuresTarget = Join-Path $runtimeRoot 'features'
New-Item -ItemType Directory -Path $featuresTarget -Force | Out-Null
$openShiftSource = Join-Path $sourceRoot 'profiles\features\openshift-stern.ps1'
$openShiftTarget = Join-Path $featuresTarget 'openshift-stern.ps1'
if ($openShiftEnabled) {
    if (Copy-TextFileIfChanged -Source $openShiftSource -Destination $openShiftTarget) {
        $changed += 'features/openshift-stern.ps1'
    }
}
elseif (Test-Path -LiteralPath $openShiftTarget -PathType Leaf) {
    Remove-Item -LiteralPath $openShiftTarget -Force
    $changed += 'features/openshift-stern.ps1 (rimosso)'
}

# Rimuove la vecchia copia root: i profili legacy la cercano ancora, ma così
# OpenShift viene caricato una sola volta, esclusivamente dal modulo.
$legacyOpenShiftTarget = Join-Path $runtimeRoot 'openshift-stern.ps1'
if (Test-Path -LiteralPath $legacyOpenShiftTarget -PathType Leaf) {
    Remove-Item -LiteralPath $legacyOpenShiftTarget -Force
    $changed += 'openshift-stern.ps1 legacy (rimosso)'
}

if ($changed.Count -eq 0) {
    Write-Host '[OK] Runtime PowerShell già aggiornato.' -ForegroundColor Green
}
else {
    Write-Host "Runtime aggiornato: $($changed -join ', ')" -ForegroundColor Green
}
