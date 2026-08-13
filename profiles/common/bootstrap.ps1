# Bootstrap stabile della sessione PowerShell pubblica.
# reload vive nello scope globale; i comandi personalizzati vivono nel modulo runtime.

$runtimeRoot = $PSScriptRoot
$modulePath = Join-Path $runtimeRoot 'PowerShellCustomization.psm1'

function global:reload {
    [CmdletBinding()]
    param([switch]$ProfileOnly)

    $runtimeRoot = Join-Path $env:LOCALAPPDATA 'PowerShellCustomization'
    $markerPath = Join-Path $runtimeRoot 'source-root.txt'

    function Test-ReloadSource {
        param([Parameter(Mandatory)][string]$Path)

        if (-not (Test-Path -LiteralPath (Join-Path $Path 'refresh.ps1') -PathType Leaf)) {
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

    function Resolve-ReloadSource {
        if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
            $saved = [IO.File]::ReadAllText($markerPath).Trim()
            if (-not [string]::IsNullOrWhiteSpace($saved) -and (Test-ReloadSource -Path $saved)) {
                return $saved
            }
        }

        $documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
        $workspace = Join-Path $documents 'workspace'
        $candidates = @()

        try {
            $gitRoot = (& git -C (Get-Location).Path rev-parse --show-toplevel 2>$null | Select-Object -First 1)
            if ($gitRoot) { $candidates += ([string]$gitRoot).Trim() }
        }
        catch { }

        $candidates += @(
            (Join-Path $documents 'powershell'),
            (Join-Path $workspace 'powershell'),
            (Join-Path $HOME 'powershell')
        )

        foreach ($candidate in ($candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
            if (-not (Test-ReloadSource -Path $candidate)) { continue }
            return [IO.Path]::GetFullPath($candidate)
        }

        return $null
    }

    if (-not $ProfileOnly) {
        $sourceRoot = Resolve-ReloadSource
        if (-not $sourceRoot) {
            Write-Warning 'Clone powershell non trovato. Esegui reload una volta dalla root del repository.'
            return
        }

        Write-Host "Sincronizzo PowerShell da: $sourceRoot" -ForegroundColor Cyan
        try {
            & (Join-Path $sourceRoot 'refresh.ps1')
            if (-not $?) {
                Write-Warning 'La sincronizzazione ha restituito un errore.'
                return
            }
        }
        catch {
            Write-Warning "Sincronizzazione non riuscita: $($_.Exception.Message)"
            return
        }
    }

    $newBootstrap = Join-Path $runtimeRoot 'bootstrap.ps1'
    if (-not (Test-Path -LiteralPath $newBootstrap -PathType Leaf)) {
        Write-Warning "Bootstrap runtime non trovato: $newBootstrap"
        return
    }

    # Ricarica anche reload stesso, così eventuali aggiornamenti al bootstrap
    # diventano attivi immediatamente nella sessione corrente.
    . $newBootstrap
    Write-Host '[OK] PowerShellCustomization ricaricato.' -ForegroundColor Green
}

if (Test-Path -LiteralPath $modulePath -PathType Leaf) {
    Import-Module -Name $modulePath -Force -Global
}
else {
    Write-Warning "Modulo PowerShellCustomization non trovato: $modulePath"
}
