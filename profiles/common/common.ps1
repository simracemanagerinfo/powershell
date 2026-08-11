# Public, reusable PowerShell customizations.
# Machine/user-specific values belong in profile.local.ps1 (ignored by Git).

$WORKSPACE = if ($env:WORKSPACE_ROOT) { $env:WORKSPACE_ROOT } else { Join-Path $HOME 'workspace' }

$AliasDescriptions = @{
    aliases   = 'Mostra alias e funzioni personalizzate'
    reload    = 'Ricarica il profilo PowerShell corrente'
    show      = 'Mostra i comandi personalizzati disponibili'
    workspace = 'Sposta la shell nella root del workspace'
}

function Get-CustomCommands {
    foreach ($name in ($AliasDescriptions.Keys | Sort-Object)) {
        $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            [pscustomobject]@{
                Nome = $name
                Tipo = [string]$command.CommandType
                Comando = if ($command.CommandType -eq 'Alias') { $command.Definition } else { $command.Name }
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

function reload {
    . $PROFILE
}

Set-Alias aliases Show-Aliases
Set-Alias show Show-Aliases

# Optional local extensions. This file must never be committed.
$localProfile = Join-Path $PSScriptRoot 'profile.local.ps1'
if (Test-Path -LiteralPath $localProfile -PathType Leaf) {
    . $localProfile
}
