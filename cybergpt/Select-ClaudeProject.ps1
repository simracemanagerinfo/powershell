[CmdletBinding()]
param(
    [switch]$UseCurrentDirectory
)

# La cronologia e' personale, memorizzata solo nel runtime locale e mai nel repository.
$historyPath = Join-Path $env:LOCALAPPDATA 'PowerShellCustomizationPublic\claude-project-history.json'
$maxItems = 15
$canSaveHistory = $true

function Resolve-ProjectDirectory {
    param([AllowEmptyString()][string]$Candidate)

    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($Candidate.Trim().Trim('"'))
    try {
        $directory = Get-Item -LiteralPath $expanded -ErrorAction Stop
        if ($directory -is [System.IO.DirectoryInfo]) {
            return $directory.FullName
        }
    }
    catch { }
    return $null
}

function Read-ProjectHistory {
    if (-not (Test-Path -LiteralPath $historyPath -PathType Leaf)) { return @() }
    try {
        $json = [IO.File]::ReadAllText($historyPath) | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $json -or $json.Version -ne 1 -or $null -eq $json.Paths) {
            throw 'Formato cronologia non riconosciuto.'
        }
        $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $valid = @()
        foreach ($stored in @($json.Paths)) {
            if ($stored -isnot [string]) { continue }
            $path = Resolve-ProjectDirectory -Candidate $stored
            if ($path -and $seen.Add($path)) {
                $valid += $path
                if ($valid.Count -ge $maxItems) { break }
            }
        }
        return $valid
    }
    catch {
        # Non sovrascriviamo una cronologia danneggiata: l'utente puo recuperarla.
        $script:canSaveHistory = $false
        Write-Warning "Storico Claude non leggibile: $historyPath. Il file sara' preservato."
        return @()
    }
}

function Save-ProjectHistory {
    param([Parameter(Mandatory)][string]$SelectedPath, [string[]]$Previous)

    if (-not $script:canSaveHistory) { return }
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $paths = @()
    foreach ($path in @($SelectedPath) + @($Previous)) {
        if (-not $path -or -not $seen.Add($path)) { continue }
        $paths += $path
        if ($paths.Count -ge $maxItems) { break }
    }

    $parent = Split-Path -Parent $historyPath
    $temporary = Join-Path $parent ("claude-project-history-$([guid]::NewGuid().ToString('N')).tmp")
    try {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $text = ([pscustomobject]@{
            Version = 1
            Paths = @($paths)
        } | ConvertTo-Json -Depth 4) + [Environment]::NewLine
        [IO.File]::WriteAllText($temporary, $text, [Text.UTF8Encoding]::new($false))
        # Atomicamente sostituito sullo stesso filesystem; nessuna modifica al repo.
        [IO.File]::Move($temporary, $historyPath, $true)
    }
    catch {
        Write-Warning "Impossibile salvare la cronologia Claude: $($_.Exception.Message)"
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

function Select-DirectoryFromDialog {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
        try {
            $dialog.Description = 'Seleziona la directory di lavoro per Claude Code'
            $dialog.ShowNewFolderButton = $false
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                return Resolve-ProjectDirectory -Candidate $dialog.SelectedPath
            }
        }
        finally { $dialog.Dispose() }
    }
    catch {
        Write-Warning 'Selezione grafica non disponibile. Usa N per inserire un percorso.'
    }
    return $null
}

$recent = @(Read-ProjectHistory)
$currentPath = Resolve-ProjectDirectory -Candidate (Get-Location).Path
$chosen = $null

if ($UseCurrentDirectory) {
    if (-not $currentPath) {
        Write-Warning 'La cartella corrente non e una directory valida.'
        return
    }
    $chosen = $currentPath
}
else {
    while (-not $chosen) {
        Write-Host ''
        Write-Host '  CLAUDE CODE  //  SCEGLI IL PROGETTO' -ForegroundColor DarkYellow
        Write-Host '  -----------------------------------' -ForegroundColor DarkGray
        for ($i = 0; $i -lt $recent.Count; $i++) {
            Write-Host ("  [{0}] {1}" -f ($i + 1), $recent[$i]) -ForegroundColor Gray
        }
        if ($recent.Count -eq 0) {
            Write-Host '  Nessun progetto recente.' -ForegroundColor DarkGray
        }
        if ($currentPath) {
            Write-Host "  [C] Cartella corrente: $currentPath" -ForegroundColor Cyan
        }
        Write-Host '  [N] Inserisci un percorso'
        Write-Host '  [B] Sfoglia le cartelle'
        Write-Host '  [Q] Esci senza aprire Claude'
        $answer = (Read-Host '  Scelta').Trim()

        if ($answer -eq '') {
            # La scelta e' esplicita: Invio non lancia accidentalmente l'ultimo progetto.
            continue
        }

        switch -Regex ($answer) {
            '^(?i:q)$' { return }
            '^(?i:c)$' {
                if ($currentPath) { $chosen = $currentPath }
                else { Write-Warning 'Cartella corrente non valida.' }
                break
            }
            '^(?i:n)$' {
                $inputPath = Read-Host '  Percorso completo del progetto'
                $chosen = Resolve-ProjectDirectory -Candidate $inputPath
                if (-not $chosen) { Write-Warning 'Cartella inesistente o non accessibile.' }
                break
            }
            '^(?i:b)$' {
                $chosen = Select-DirectoryFromDialog
                if (-not $chosen) { Write-Host '  Nessuna cartella selezionata.' -ForegroundColor DarkGray }
                break
            }
            '^\d+$' {
                $index = 0
                if ([int]::TryParse($answer, [ref]$index) -and $index -ge 1 -and $index -le $recent.Count) {
                    $chosen = Resolve-ProjectDirectory -Candidate $recent[$index - 1]
                    if (-not $chosen) {
                        Write-Warning 'Il progetto selezionato non e piu disponibile.'
                        $recent = @(Read-ProjectHistory)
                    }
                }
                else { Write-Warning 'Numero non valido.' }
                break
            }
            default { Write-Warning 'Scelta non riconosciuta.' }
        }
    }
}

Save-ProjectHistory -SelectedPath $chosen -Previous $recent
# Unico output della pipeline: il percorso effettivamente scelto.
Write-Output $chosen
