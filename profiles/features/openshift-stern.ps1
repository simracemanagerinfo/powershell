# Optional OpenShift / Stern feature.
# No company endpoint, namespace or application name is stored in this repository.

$configPath = if ($env:POWERSHELL_OPENSHIFT_CONFIG) {
    $env:POWERSHELL_OPENSHIFT_CONFIG
}
else {
    Join-Path $HOME '.config/powershell-personalization/openshift.local.json'
}

function Get-OpenShiftCustomizationConfig {
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        Write-Warning "Configurazione OpenShift non trovata: $configPath"
        Write-Warning 'Copia config/openshift.example.json in un file locale e personalizzalo.'
        return $null
    }
    try {
        return [IO.File]::ReadAllText($configPath) | ConvertFrom-Json
    }
    catch {
        Write-Error "Configurazione OpenShift non valida: $($_.Exception.Message)"
        return $null
    }
}

function loginoc {
    param([Parameter(Mandatory)][string]$Environment)

    $config = Get-OpenShiftCustomizationConfig
    if (-not $config) { return }

    $url = $config.clusters.$Environment
    if (-not $url) {
        Write-Error "Cluster non configurato: $Environment"
        return
    }

    & oc login --web $url
}

function sternLog {
    param(
        [Parameter(Mandatory)][string]$Project,
        [switch]$Full,
        [string]$Include
    )

    $config = Get-OpenShiftCustomizationConfig
    if (-not $config) { return }

    $selected = $config.sternProjects.$Project
    if (-not $selected) {
        Write-Host 'Progetti configurati:' -ForegroundColor Cyan
        $config.sternProjects.PSObject.Properties.Name | Sort-Object | ForEach-Object { Write-Host "- $_" }
        return
    }

    $arguments = @([string]$selected.app, '-n', [string]$selected.namespace)
    if (-not $Full) { $arguments += @('--tail', '0') }
    if ($Include) { $arguments += @('-i', $Include) }

    & stern @arguments
}
