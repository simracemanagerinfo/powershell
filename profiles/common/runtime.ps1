# Runtime pubblico condiviso dalla personalizzazione PowerShell.
# Viene caricato esclusivamente dentro il modulo PowerShellCustomization.

$WORKSPACE = if ($env:WORKSPACE_ROOT) { $env:WORKSPACE_ROOT } else { Join-Path $HOME 'workspace' }
$customizationRuntimeRoot = $PSScriptRoot

$AliasDescriptions = @{
    aliases   = 'Mostra alias e funzioni personalizzate'
    reload    = 'Sincronizza dal repository installato e ricarica il modulo PowerShell'
    show      = 'Mostra i comandi personalizzati disponibili'
    workspace = 'Sposta la shell nella root del workspace'
}

function Get-CustomCommands {
    foreach ($name in ($AliasDescriptions.Keys | Sort-Object)) {
        $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            [pscustomobject]@{
                Nome        = $name
                Tipo        = [string]$command.CommandType
                Comando     = if ($command.CommandType -eq 'Alias') { $command.Definition } else { $command.Name }
                Descrizione = $AliasDescriptions[$name]
            }
        }
    }
}

function Show-Aliases {
    Get-CustomCommands | Format-Table -AutoSize
}

function workspace {
    if (-not (Test-Path -LiteralPath $WORKSPACE)) {
        New-Item -ItemType Directory -Path $WORKSPACE -Force | Out-Null
    }
    Set-Location -LiteralPath $WORKSPACE
}

Set-Alias aliases Show-Aliases
Set-Alias show Show-Aliases

# Command plugin autoconsistenti: ogni *.ps1 può definire funzioni/alias e
# registrare le proprie descrizioni in $AliasDescriptions.
$commandsRoot = Join-Path $customizationRuntimeRoot 'commands'
if (Test-Path -LiteralPath $commandsRoot -PathType Container) {
    foreach ($commandFile in Get-ChildItem -LiteralPath $commandsRoot -File -Filter '*.ps1' | Sort-Object Name) {
        try {
            . $commandFile.FullName
        }
        catch {
            Write-Warning "Command plugin non caricato: $($commandFile.Name) - $($_.Exception.Message)"
        }
    }
}

# Feature OpenShift/Stern opzionale e generica, caricata soltanto dal modulo.
$openShiftFeature = Join-Path $customizationRuntimeRoot 'features\openshift-stern.ps1'
if (Test-Path -LiteralPath $openShiftFeature -PathType Leaf) {
    . $openShiftFeature
}

# Estensioni locali opzionali, mai versionate.
$localProfile = Join-Path $customizationRuntimeRoot 'profile.local.ps1'
if (Test-Path -LiteralPath $localProfile -PathType Leaf) {
    . $localProfile
}
