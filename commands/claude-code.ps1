# Avvia Claude Code con la grafica dedicata partendo dalla directory desiderata.
# Il profilo viene caricato normalmente: questo command non avvia nulla durante il reload.
$AliasDescriptions['claudeCode'] = 'Apri Claude Code nella cartella corrente (oppure -Path / -Choose)'

function claudeCode {
    [CmdletBinding(DefaultParameterSetName='Directory')]
    param(
        [Parameter(ParameterSetName='Directory', Position=0)]
        [string]$Path,

        [Parameter(ParameterSetName='Selection')]
        [switch]$Choose
    )

    $terminal = Get-Command wt.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $terminal) {
        Write-Warning 'Windows Terminal non trovato (wt.exe).'
        return
    }

    if ($Choose) {
        & $terminal.Source -p 'Claude Code'
        return
    }

    $candidate = if ($PSBoundParameters.ContainsKey('Path')) { $Path } else { (Get-Location).Path }
    try {
        $folder = Get-Item -LiteralPath $candidate -ErrorAction Stop
        if ($folder -isnot [System.IO.DirectoryInfo]) {
            throw 'Non e una directory.'
        }
    }
    catch {
        Write-Warning "Cartella Claude non valida: $candidate"
        return
    }

    $startupScript = Join-Path $env:LOCALAPPDATA 'PowerShellCustomizationPublic\terminal\Start-CyberProfile.ps1'
    if (-not (Test-Path -LiteralPath $startupScript -PathType Leaf)) {
        Write-Warning 'Profilo Claude Code non installato. Esegui install.ps1 -AddLauncher "Claude Code".'
        return
    }

    # L'override del commandline mantiene il profilo grafico Windows Terminal e
    # salta soltanto il menu, aprendo Claude nella directory scelta.
    & $terminal.Source -p 'Claude Code' -d $folder.FullName pwsh.exe -NoLogo -NoExit -NoProfile -File $startupScript -Theme claude_code -LaunchClaude -UseCurrentDirectory
}
