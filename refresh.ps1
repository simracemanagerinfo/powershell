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

# Mantiene aggiornate le feature versionate. Il blocco gestito nel profile decide
# quali file vengono realmente caricati in base alle opzioni dell'installazione.
$featuresSource = Join-Path $sourceRoot 'profiles\features'
if (Test-Path -LiteralPath $featuresSource -PathType Container) {
    foreach ($file in Get-ChildItem -LiteralPath $featuresSource -File -Filter '*.ps1') {
        $destination = Join-Path $runtimeRoot $file.Name
        if (Copy-TextFileIfChanged -Source $file.FullName -Destination $destination) {
            $changed += $file.Name
        }
    }
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
