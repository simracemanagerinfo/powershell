# Command plugin autoconsistente: version bump Maven + Helm.
$AliasDescriptions['bv'] = 'Aggiorna la versione Maven e i file values*.yaml: patch, minor, major o versione esplicita'

function bv {
    $ErrorActionPreference = 'Stop'
    $arguments = @($args)

    $usage = @"
Uso:
    bv
    bv patch
    bv minor
    bv major
    bv 1.0.0
    bv -v patch
    bv -v minor
    bv -v major
    bv -v 1.0.0
    bv -h
    bv --help

Valori supportati:
    patch  Incrementa la patch di una versione semantica valida
    minor  Incrementa la minor e azzera la patch
    major  Incrementa la major e azzera minor e patch
    x.y.z  Imposta esplicitamente una versione semantica valida

Opzioni:
    -h, --help     Mostra questo aiuto
    -v, --version  Specifica esplicitamente il valore da applicare
"@

    $requestedVersion = 'patch'

    if ($arguments.Count -gt 0) {
        $first = [string]$arguments[0]

        if ($first -in @('-h', '--help', '-?', '/?')) {
            Write-Host $usage
            return
        }

        if ($first -in @('-v', '--version')) {
            if ($arguments.Count -ne 2) {
                throw "Uso non valido. Specifica un solo valore dopo $first.`n`n$usage"
            }
            $requestedVersion = [string]$arguments[1]
        }
        elseif ($arguments.Count -eq 1) {
            $requestedVersion = $first
        }
        else {
            throw "Argomenti non riconosciuti: $($arguments -join ' ')`n`n$usage"
        }
    }

    $pomPath = Join-Path $PWD 'pom.xml'

    if (-not (Test-Path -LiteralPath $pomPath -PathType Leaf)) {
        throw 'pom.xml non trovato nella directory corrente'
    }

    [xml]$pom = Get-Content -LiteralPath $pomPath
    $currentVersion = [string]$pom.project.version

    function Test-BvSemanticVersion {
        param([string]$Version)

        return [regex]::IsMatch($Version, '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')
    }

    $requestedMode = $requestedVersion.ToLowerInvariant()

    switch ($requestedMode) {
        'major' {
            if (-not (Test-BvSemanticVersion -Version $currentVersion)) {
                throw "La versione corrente nel pom.xml non e' semantica: '$currentVersion'. Usa 'bv -v X.Y.Z' per impostarla esplicitamente."
            }

            $currentMatch = [regex]::Match($currentVersion, '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')
            $major = [int]$currentMatch.Groups[1].Value
            $newVersion = "$($major + 1).0.0"
        }
        'minor' {
            if (-not (Test-BvSemanticVersion -Version $currentVersion)) {
                throw "La versione corrente nel pom.xml non e' semantica: '$currentVersion'. Usa 'bv -v X.Y.Z' per impostarla esplicitamente."
            }

            $currentMatch = [regex]::Match($currentVersion, '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')
            $major = [int]$currentMatch.Groups[1].Value
            $minor = [int]$currentMatch.Groups[2].Value
            $newVersion = "$major.$($minor + 1).0"
        }
        'patch' {
            if (-not (Test-BvSemanticVersion -Version $currentVersion)) {
                throw "La versione corrente nel pom.xml non e' semantica: '$currentVersion'. Usa 'bv -v X.Y.Z' per impostarla esplicitamente."
            }

            $currentMatch = [regex]::Match($currentVersion, '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')
            $major = [int]$currentMatch.Groups[1].Value
            $minor = [int]$currentMatch.Groups[2].Value
            $patch = [int]$currentMatch.Groups[3].Value
            $newVersion = "$major.$minor.$($patch + 1)"
        }
        default {
            if (-not (Test-BvSemanticVersion -Version $requestedVersion)) {
                throw "Versione semantica non valida: $requestedVersion"
            }

            $newVersion = $requestedVersion
        }
    }

    function Update-BvYamlVersionLine {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string]$Line,
            [Parameter(Mandatory)][string]$Key,
            [Parameter(Mandatory)][string]$Version
        )

        if ([string]::IsNullOrEmpty($Line)) {
            return $Line
        }

        $escapedKey = [regex]::Escape($Key)
        $quotedPattern = '^(\s*' + $escapedKey + '\s*:\s*)(["''])(\d+\.\d+\.\d+)([^"'']*)\2(\s*(?:#.*)?)$'
        $quotedMatch = [regex]::Match($Line, $quotedPattern)
        if ($quotedMatch.Success) {
            return $quotedMatch.Groups[1].Value +
                $quotedMatch.Groups[2].Value +
                $Version +
                $quotedMatch.Groups[4].Value +
                $quotedMatch.Groups[2].Value +
                $quotedMatch.Groups[5].Value
        }

        $plainPattern = '^(\s*' + $escapedKey + '\s*:\s*)(\d+\.\d+\.\d+)([^\s#]*)(\s*(?:#.*)?)$'
        $plainMatch = [regex]::Match($Line, $plainPattern)
        if ($plainMatch.Success) {
            return $plainMatch.Groups[1].Value +
                $Version +
                $plainMatch.Groups[3].Value +
                $plainMatch.Groups[4].Value
        }

        return $Line
    }

    function Update-BvYamlVersionFile {
        param(
            [Parameter(Mandatory)][string]$Path,
            [Parameter(Mandatory)][string]$Key,
            [Parameter(Mandatory)][string]$Version
        )

        # Read the whole file and keep the original newline separators. Splitting with
        # a capturing group returns [line, separator, line, separator, ...], so joining
        # the array afterwards reproduces every blank line and CRLF/LF exactly.
        $content = [IO.File]::ReadAllText($Path)
        $parts = [regex]::Split($content, '(\r\n|\n|\r)')
        $changed = $false

        for ($index = 0; $index -lt $parts.Length; $index += 2) {
            $line = $parts[$index]
            $updatedLine = Update-BvYamlVersionLine -Line $line -Key $Key -Version $Version
            if ($updatedLine -cne $line) {
                $parts[$index] = $updatedLine
                $changed = $true
            }
        }

        if ($changed) {
            [IO.File]::WriteAllText($Path, ($parts -join ''), [Text.UTF8Encoding]::new($false))
            Write-Host "Aggiornato $Path"
        }
        else {
            Write-Host "Nessuna voce '$Key' aggiornabile in $Path" -ForegroundColor DarkGray
        }
    }

    $valuesFiles = @(Get-ChildItem -Recurse -File | Where-Object {
        $_.Name -in @('values.yaml', 'values-prod.yaml', 'values-preprod.yaml')
    })
    $chartFiles = @(Get-ChildItem -Recurse -File -Filter 'Chart.yaml')

    # Snapshot byte-for-byte before touching anything. If any operation fails, every
    # version file is restored to exactly the state it had before bv started.
    $originalBytes = @{}
    $pathsToProtect = @($pomPath) + @($valuesFiles.FullName) + @($chartFiles.FullName) |
        Select-Object -Unique
    foreach ($path in $pathsToProtect) {
        $originalBytes[$path] = [IO.File]::ReadAllBytes($path)
    }

    Write-Host ''
    Write-Host ('Versione attuale: {0}' -f $currentVersion)
    Write-Host ('Nuova versione:   {0}' -f $newVersion)
    Write-Host ''

    try {
        $pom.project.version = $newVersion
        $pom.Save($pomPath)
        Write-Host 'Aggiornato pom.xml'

        foreach ($file in $valuesFiles) {
            Update-BvYamlVersionFile -Path $file.FullName -Key 'tag' -Version $newVersion
        }

        foreach ($file in $chartFiles) {
            Update-BvYamlVersionFile -Path $file.FullName -Key 'appVersion' -Version $newVersion
        }
    }
    catch {
        foreach ($path in $pathsToProtect) {
            try {
                [IO.File]::WriteAllBytes($path, [byte[]]$originalBytes[$path])
            }
            catch {
                Write-Warning ('Rollback non riuscito per {0}: {1}' -f $path, $_.Exception.Message)
            }
        }

        throw "Aggiornamento versione fallito. I file modificabili sono stati ripristinati. Errore originale: $($_.Exception.Message)"
    }

    Write-Host ''
    Write-Host 'Completato.'
}
