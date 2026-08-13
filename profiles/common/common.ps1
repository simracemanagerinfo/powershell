# Public, reusable PowerShell customizations.
# Machine/user-specific values belong in profile.local.ps1 (ignored by Git).

$WORKSPACE = if ($env:WORKSPACE_ROOT) { $env:WORKSPACE_ROOT } else { Join-Path $HOME 'workspace' }
$customizationRuntimeRoot = $PSScriptRoot

$AliasDescriptions = @{
    aliases   = 'Mostra alias e funzioni personalizzate'
    reload    = 'Sincronizza dal repository installato e ricarica il profilo PowerShell'
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

function Test-PowerShellCustomizationSource {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath (Join-Path $Path 'install.ps1') -PathType Leaf)) {
        return $false
    }

    try {
        $remote = (& git -C $Path remote get-url origin 2>$null | Select-Object -First 1)
        if ($remote -and ([string]$remote).Trim() -match 'simracemanagerinfo/powershell(?:\.git)?$') {
            return $true
        }
    }
    catch { }

    return (Split-Path -Leaf $Path) -ieq 'powershell'
}

function Resolve-PowerShellCustomizationSource {
    $markerPath = Join-Path $customizationRuntimeRoot 'source-root.txt'

    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        $saved = [IO.File]::ReadAllText($markerPath).Trim()
        if (-not [string]::IsNullOrWhiteSpace($saved) -and (Test-PowerShellCustomizationSource -Path $saved)) {
            return $saved
        }
    }

    $candidates = @()
    try {
        $gitRoot = (& git -C (Get-Location).Path rev-parse --show-toplevel 2>$null | Select-Object -First 1)
        if ($gitRoot) { $candidates += ([string]$gitRoot).Trim() }
    }
    catch { }

    $documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    $candidates += @(
        (Join-Path $documents 'powershell'),
        (Join-Path $WORKSPACE 'powershell'),
        (Join-Path $HOME 'powershell')
    )

    foreach ($candidate in ($candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        if (-not (Test-PowerShellCustomizationSource -Path $candidate)) { continue }

        $resolved = [IO.Path]::GetFullPath($candidate)
        [IO.File]::WriteAllText($markerPath, $resolved, [Text.UTF8Encoding]::new($false))
        return $resolved
    }

    return $null
}

function reload {
    param([switch]$ProfileOnly)

    if (-not $ProfileOnly) {
        $sourceRoot = Resolve-PowerShellCustomizationSource
        if ($sourceRoot) {
            $refreshScript = Join-Path $sourceRoot 'refresh.ps1'
            Write-Host "Sincronizzo PowerShell da: $sourceRoot" -ForegroundColor Cyan
            try {
                if (Test-Path -LiteralPath $refreshScript -PathType Leaf) {
                    & $refreshScript
                }
                else {
                    & (Join-Path $sourceRoot 'install.ps1') -SkipDependencies
                }
                if (-not $?) {
                    Write-Warning 'La sincronizzazione ha restituito un errore; ricarico comunque il profilo corrente.'
                }
            }
            catch {
                Write-Warning "Sincronizzazione non riuscita: $($_.Exception.Message)"
            }
        }
        else {
            Write-Warning 'Clone powershell non trovato. Esegui reload una volta dalla root del repository oppure usa reload -ProfileOnly.'
        }
    }

    . $PROFILE
}

Set-Alias aliases Show-Aliases
Set-Alias show Show-Aliases

# Optional local extensions. This file must never be committed.
$localProfile = Join-Path $PSScriptRoot 'profile.local.ps1'
if (Test-Path -LiteralPath $localProfile -PathType Leaf) {
    . $localProfile
}
