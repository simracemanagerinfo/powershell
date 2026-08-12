[CmdletBinding()]
param(
    [switch]$SkipDependencies,
    [switch]$Reconfigure,

    [Parameter(DontShow)]
    [AllowNull()]
    [Nullable[bool]]$OpenShiftSternOverride,

    [Parameter(DontShow)]
    [AllowNull()]
    [string]$ProfilePathOverride,

    [Parameter(DontShow)]
    [AllowNull()]
    [string[]]$LaunchersOverride
)

$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Questo install.ps1 configura Windows Terminal ed è attualmente supportato solo su Windows.'
}

$script:RuntimeRoot = Join-Path $env:LOCALAPPDATA 'PowerShellCustomization'
$script:AssetRoot = Join-Path $script:RuntimeRoot 'assets'
$script:LauncherRoot = Join-Path $script:RuntimeRoot 'launchers'
$script:FragmentRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\PowerShellCustomization'
$script:OptionsPath = Join-Path $script:RuntimeRoot 'install-options.json'
$script:BinRoot = Join-Path $script:RuntimeRoot 'bin'
$script:Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:LauncherNames = @('Matrix GPT', 'Cyber Glass', 'Neon Dev', 'Stern HUD')

function Read-YesNo {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [AllowNull()][Nullable[bool]]$Default
    )

    while ($true) {
        $answer = (Read-Host $Prompt).Trim()
        if ([string]::IsNullOrWhiteSpace($answer) -and $null -ne $Default) {
            return [bool]$Default
        }
        switch -Regex ($answer) {
            '^(?i:s|si|sì|y|yes)$' { return $true }
            '^(?i:n|no)$' { return $false }
            default { Write-Host 'Rispondi S oppure N.' -ForegroundColor Yellow }
        }
    }
}

function Resolve-LauncherSelection {
    param([AllowNull()][string[]]$Names)

    $resolved = @()
    foreach ($name in @($Names)) {
        $canonical = $script:LauncherNames | Where-Object { $_ -ieq $name } | Select-Object -First 1
        if (-not $canonical) {
            throw "Launcher non riconosciuto: $name. Valori ammessi: $($script:LauncherNames -join ', ')."
        }
        if ($canonical -notin $resolved) {
            $resolved += $canonical
        }
    }
    if ($resolved.Count -eq 0) {
        throw 'Seleziona almeno un launcher.'
    }
    return $resolved
}

function Read-LauncherSelection {
    while ($true) {
        Write-Host ''
        Write-Host 'Quali launcher EXE vuoi creare? Premi Invio per accettare S.' -ForegroundColor Cyan
        $selected = @($script:LauncherNames | Where-Object {
                Read-YesNo -Prompt "  $_ [S/N]" -Default $true
            })
        if ($selected.Count -gt 0) {
            return $selected
        }
        Write-Host 'Devi selezionare almeno un launcher.' -ForegroundColor Yellow
    }
}

function Refresh-ProcessPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($machine, $user, $env:Path) -join ';'
    $env:Path = (($parts -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique) -join ';')
}

function Add-UserPathEntry {
    param([Parameter(Mandatory)][string]$Directory)

    $normalized = [IO.Path]::GetFullPath($Directory).TrimEnd('\')
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        $parts = @($current -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $normalized })) {
        $parts += $normalized
        [Environment]::SetEnvironmentVariable('Path', (($parts | Select-Object -Unique) -join ';'), 'User')
    }
    Refresh-ProcessPath
}

function Ensure-WingetApplication {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$WingetId
    )

    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-Host "[OK] $Name" -ForegroundColor Green
        return $true
    }

    if (-not (Read-YesNo -Prompt "$Name non trovato. Vuoi provare l'installazione per il solo utente corrente? [S/N]" -Default $true)) {
        Write-Warning "$Name non installato."
        return $false
    }

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Warning "winget non disponibile: impossibile installare automaticamente $Name senza privilegi amministrativi."
        return $false
    }

    Write-Host "Installazione user-level: $Name" -ForegroundColor Cyan
    & $winget.Source install --id $WingetId --exact --scope user --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Installazione user-level fallita per $Name. Non verrà tentata automaticamente un'installazione elevata."
        return $false
    }

    Refresh-ProcessPath
    return $true
}

function Ensure-PowerShellModule {
    param([Parameter(Mandatory)][string]$Name)

    if (Get-Module -ListAvailable -Name $Name) {
        Write-Host "[OK] Modulo $Name" -ForegroundColor Green
        return
    }
    if (-not (Read-YesNo -Prompt "Modulo $Name non trovato. Installarlo in CurrentUser? [S/N]" -Default $true)) {
        return
    }
    Install-Module -Name $Name -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
}

function Test-MesloFont {
    foreach ($registryPath in @(
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts')) {
        if (Test-Path $registryPath) {
            $names = (Get-ItemProperty $registryPath).PSObject.Properties.Name
            if ($names | Where-Object { $_ -like '*MesloLGM*' -or $_ -like '*Meslo LGM*' }) {
                return $true
            }
        }
    }
    return $false
}

function Ensure-MesloFont {
    if (Test-MesloFont) {
        Write-Host '[OK] MesloLGM Nerd Font' -ForegroundColor Green
        return
    }
    if (-not (Read-YesNo -Prompt 'MesloLGM Nerd Font non trovato. Installarlo per il solo utente corrente? [S/N]' -Default $true)) {
        return
    }

    Refresh-ProcessPath
    $omp = Get-Command oh-my-posh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $omp) {
        Write-Warning 'Oh My Posh non è disponibile nella sessione: impossibile installare automaticamente Meslo.'
        return
    }

    & $omp.Source font install meslo
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Installazione Meslo Nerd Font non riuscita.'
    }
}

function Test-SafeOcSource {
    param([AllowNull()][string]$Source)

    if ([string]::IsNullOrWhiteSpace($Source)) { return $false }
    if ($Source -notmatch '^https?://') {
        return Test-Path -LiteralPath $Source -PathType Leaf
    }

    [Uri]$uri = $null
    if (-not [Uri]::TryCreate($Source, [UriKind]::Absolute, [ref]$uri)) { return $false }
    return $uri.Scheme -in @('http', 'https') -and
        [string]::IsNullOrWhiteSpace($uri.UserInfo) -and
        [string]::IsNullOrWhiteSpace($uri.Query) -and
        [string]::IsNullOrWhiteSpace($uri.Fragment) -and
        $uri.AbsolutePath -notmatch '(?i)(password|passwd|secret|token|credential|api[-_.]?key)'
}

function Read-OcSource {
    while ($true) {
        $source = (Read-Host 'Inserisci il link diretto di oc.exe oppure il path locale completo di oc.exe').Trim()
        if (Test-SafeOcSource -Source $source) { return $source }
        Write-Host 'Sorgente non valida. Non sono accettati URL con credential, query o fragment.' -ForegroundColor Yellow
    }
}

function Ensure-OcClient {
    $existing = Get-Command oc.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existing) {
        Write-Host "oc.exe trovato: $($existing.Source)" -ForegroundColor Cyan
        try { & $existing.Source version --client | Out-Host } catch { }
        if (Read-YesNo -Prompt 'Vuoi usare questa versione di oc.exe? [S/N]' -Default $true) {
            return $existing.Source
        }
    }

    $source = Read-OcSource
    New-Item -ItemType Directory -Path $script:BinRoot -Force | Out-Null
    $target = Join-Path $script:BinRoot 'oc.exe'

    if ($source -match '^https?://') {
        Invoke-WebRequest -Uri $source -OutFile $target -UseBasicParsing
    }
    else {
        Copy-Item -LiteralPath $source -Destination $target -Force
    }

    try {
        & $target version --client | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'oc.exe ha restituito un errore.' }
    }
    catch {
        Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        throw "Verifica di oc.exe fallita: $($_.Exception.Message)"
    }

    Add-UserPathEntry -Directory $script:BinRoot
    return $target
}

function Get-InstallOptions {
    if (-not $Reconfigure -and $null -eq $OpenShiftSternOverride -and $null -eq $LaunchersOverride -and
        (Test-Path -LiteralPath $script:OptionsPath -PathType Leaf)) {
        try {
            $saved = [IO.File]::ReadAllText($script:OptionsPath) | ConvertFrom-Json
            if ($saved.PSObject.Properties['OpenShiftStern'] -and $saved.PSObject.Properties['Launchers']) {
                return [pscustomobject]@{
                    OpenShiftStern = [bool]$saved.OpenShiftStern
                    Launchers      = @(Resolve-LauncherSelection -Names @($saved.Launchers))
                }
            }
        }
        catch { }
    }

    return [pscustomobject]@{
        OpenShiftStern = if ($null -ne $OpenShiftSternOverride) {
            [bool]$OpenShiftSternOverride
        }
        else {
            Read-YesNo -Prompt 'Ti serve il supporto OpenShift / Stern? [S/N]' -Default $false
        }
        Launchers = if ($null -ne $LaunchersOverride) {
            @(Resolve-LauncherSelection -Names $LaunchersOverride)
        }
        else {
            @(Read-LauncherSelection)
        }
    }
}

function Save-InstallOptions {
    param([Parameter(Mandatory)]$Options)

    New-Item -ItemType Directory -Path $script:RuntimeRoot -Force | Out-Null
    $json = ([pscustomobject]@{
            OpenShiftStern = [bool]$Options.OpenShiftStern
            Launchers      = @($Options.Launchers)
        } | ConvertTo-Json) + [Environment]::NewLine
    [IO.File]::WriteAllText($script:OptionsPath, $json, [Text.UTF8Encoding]::new($false))
}

function Copy-TextFileUtf8 {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
    $content = [IO.File]::ReadAllText($Source)
    [IO.File]::WriteAllText($Destination, $content, [Text.UTF8Encoding]::new($false))
}

function Get-ProfileEncoding {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [Text.UTF8Encoding]::new($false)
    }

    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 4) {
        if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) {
            return [Text.UTF32Encoding]::new($false, $true)
        }
        if ($bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
            return [Text.UTF32Encoding]::new($true, $true)
        }
    }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [Text.UTF8Encoding]::new($true)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [Text.UnicodeEncoding]::new($false, $true)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return [Text.UnicodeEncoding]::new($true, $true)
    }

    return [Text.UTF8Encoding]::new($false)
}

function Backup-Profile {
    param([Parameter(Mandatory)][string]$ProfilePath)

    if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) { return }
    $backupDir = Join-Path $script:RuntimeRoot "backups\$($script:Timestamp)"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Copy-Item -LiteralPath $ProfilePath -Destination (Join-Path $backupDir 'Microsoft.PowerShell_profile.ps1') -Force
}

function Update-ManagedProfileBlock {
    param([Parameter(Mandatory)][string]$ProfilePath)

    $startMarker = '# >>> powershell-customization managed >>>'
    $endMarker = '# <<< powershell-customization managed <<<'
    $managedBlock = (@"
$startMarker
`$runtimeRoot = Join-Path `$env:LOCALAPPDATA 'PowerShellCustomization'
. (Join-Path `$runtimeRoot 'common.ps1')
`$openShiftFeature = Join-Path `$runtimeRoot 'openshift-stern.ps1'
if (Test-Path -LiteralPath `$openShiftFeature -PathType Leaf) {
    . `$openShiftFeature
}
$endMarker
"@).TrimEnd("`r", "`n")

    $exists = Test-Path -LiteralPath $ProfilePath -PathType Leaf
    $encoding = Get-ProfileEncoding -Path $ProfilePath
    $original = if ($exists) { [IO.File]::ReadAllText($ProfilePath, $encoding) } else { '' }

    $pattern = '(?ms)^' + [regex]::Escape($startMarker) + '.*?^' +
        [regex]::Escape($endMarker) + '[ \t]*(?:\r?\n)?'
    $matches = [regex]::Matches($original, $pattern)

    if ($matches.Count -eq 0) {
        $prefix = $original.TrimEnd("`r", "`n")
        $updated = if ($prefix.Length -gt 0) {
            $prefix + [Environment]::NewLine + [Environment]::NewLine + $managedBlock + [Environment]::NewLine
        }
        else { $managedBlock + [Environment]::NewLine }
    }
    else {
        $updated = $original
        for ($index = $matches.Count - 1; $index -ge 0; $index--) {
            $replacement = if ($index -eq 0) { $managedBlock + [Environment]::NewLine } else { '' }
            $updated = $updated.Remove($matches[$index].Index, $matches[$index].Length)
            $updated = $updated.Insert($matches[$index].Index, $replacement)
        }
    }

    if ($updated -ceq $original) {
        Write-Host '[OK] Profilo PowerShell già configurato, nessuna modifica.' -ForegroundColor Green
        return
    }

    if ($exists) {
        Backup-Profile -ProfilePath $ProfilePath
        Write-Host 'Profilo PowerShell esistente preservato; modifico soltanto il blocco gestito.' -ForegroundColor Cyan
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $ProfilePath) -Force | Out-Null
    [IO.File]::WriteAllText($ProfilePath, $updated, $encoding)
}

function Install-RuntimeFiles {
    param([Parameter(Mandatory)]$Options)

    New-Item -ItemType Directory -Path $script:RuntimeRoot -Force | Out-Null
    Copy-TextFileUtf8 -Source (Join-Path $PSScriptRoot 'profiles\common\common.ps1') -Destination (Join-Path $script:RuntimeRoot 'common.ps1')

    $featureTarget = Join-Path $script:RuntimeRoot 'openshift-stern.ps1'
    if ($Options.OpenShiftStern) {
        Copy-TextFileUtf8 -Source (Join-Path $PSScriptRoot 'profiles\features\openshift-stern.ps1') -Destination $featureTarget
        $localConfig = Join-Path $script:RuntimeRoot 'openshift.local.json'
        if (-not (Test-Path -LiteralPath $localConfig -PathType Leaf)) {
            Copy-TextFileUtf8 -Source (Join-Path $PSScriptRoot 'config\openshift.example.json') -Destination $localConfig
            Write-Host "Creato esempio locale OpenShift: $localConfig" -ForegroundColor Yellow
            Write-Host 'Personalizzalo con cluster, namespace e servizi della tua azienda.' -ForegroundColor Yellow
        }
    }
    elseif (Test-Path -LiteralPath $featureTarget -PathType Leaf) {
        Remove-Item -LiteralPath $featureTarget -Force
    }
}

function Install-Graphics {
    $sourceRoot = Join-Path $PSScriptRoot 'assets'
    $requiredAssets = @(
        'backgrounds\pool\01_roma_vaticano_neon.png',
        'backgrounds\pool\02_simrace_pitlane_neon.png',
        'backgrounds\pool\03_roma_colosseo_future.png',
        'backgrounds\pool\04_simrace_garage_future.png',
        'backgrounds\pool\05_roma_colosseo_rain.png',
        'backgrounds\pool\06_simrace_night_race.png',
        'icons\matrix_gpt.ico',
        'icons\matrix_gpt_clear.ico',
        'icons\svi_gpt_original.ico',
        'icons\stern_logs.ico',
        'watermarks\svi_gpt.png',
        'watermarks\stern_logs.png'
    )

    foreach ($relativePath in $requiredAssets) {
        $source = Join-Path $sourceRoot $relativePath
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Asset versionato mancante: $source"
        }

        $destination = Join-Path $script:AssetRoot $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }

    $initialBackground = Join-Path $script:AssetRoot 'backgrounds\pool\01_roma_vaticano_neon.png'
    Copy-Item -LiteralPath $initialBackground -Destination (Join-Path $script:AssetRoot 'backgrounds\current.png') -Force
}

function Install-WindowsTerminalFragment {
    New-Item -ItemType Directory -Path $script:FragmentRoot -Force | Out-Null

    Copy-TextFileUtf8 -Source (Join-Path $PSScriptRoot 'cybergpt\Start-CyberProfile.ps1') -Destination (Join-Path $script:FragmentRoot 'Start-CyberProfile.ps1')

    $themeDir = Join-Path $script:FragmentRoot 'themes'
    New-Item -ItemType Directory -Path $themeDir -Force | Out-Null
    foreach ($theme in @('matrix_neon_gpt.omp.json', 'cyber_glass_gpt.omp.json', 'neon_dev_gpt.omp.json', 'stern_hud_gpt.omp.json')) {
        Copy-TextFileUtf8 -Source (Join-Path $PSScriptRoot "cybergpt\themes\$theme") -Destination (Join-Path $themeDir $theme)
    }

    $shaderDir = Join-Path $script:FragmentRoot 'shaders'
    New-Item -ItemType Directory -Path $shaderDir -Force | Out-Null
    foreach ($shader in @('matrix_rain.hlsl', 'cyber_glass_hud.hlsl', 'neon_glow.hlsl')) {
        Copy-TextFileUtf8 -Source (Join-Path $PSScriptRoot "cybergpt\shaders\$shader") -Destination (Join-Path $shaderDir $shader)
    }

    $template = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'windows-terminal\managed-settings.json'))
    $fragmentJsonRoot = $script:FragmentRoot.Replace('\', '\\')
    $assetJsonRoot = $script:AssetRoot.Replace('\', '\\')
    $rendered = $template.Replace('{{FRAGMENT_ROOT}}', $fragmentJsonRoot).Replace('{{ASSET_ROOT}}', $assetJsonRoot)

    $validated = $rendered | ConvertFrom-Json
    $json = ($validated | ConvertTo-Json -Depth 100) + [Environment]::NewLine
    [IO.File]::WriteAllText((Join-Path $script:FragmentRoot 'powershell-customization.json'), $json, [Text.UTF8Encoding]::new($false))
}

function Build-Launchers {
    param([Parameter(Mandatory)][string[]]$Names)

    $buildScript = Join-Path $PSScriptRoot 'launchers\src\build.ps1'
    & $buildScript -OutputDirectory $script:LauncherRoot -AssetRoot $script:AssetRoot -Launchers $Names | Out-Host

    foreach ($name in $Names) {
        $path = Join-Path $script:LauncherRoot "$name.exe"
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Launcher non prodotto: $path"
        }
    }
}

function Install-LauncherShortcuts {
    param([Parameter(Mandatory)][string[]]$Names)

    $startMenuRoot = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\PowerShell Customization'
    New-Item -ItemType Directory -Path $startMenuRoot -Force | Out-Null
    $shell = New-Object -ComObject WScript.Shell

    foreach ($knownName in $script:LauncherNames) {
        if ($knownName -notin $Names) {
            $obsoleteShortcut = Join-Path $startMenuRoot "$knownName.lnk"
            if (Test-Path -LiteralPath $obsoleteShortcut -PathType Leaf) {
                Remove-Item -LiteralPath $obsoleteShortcut -Force
            }
        }
    }

    foreach ($name in $Names) {
        $exe = Join-Path $script:LauncherRoot "$name.exe"
        $shortcutPath = Join-Path $startMenuRoot "$name.lnk"
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exe
        $shortcut.WorkingDirectory = $script:LauncherRoot
        $shortcut.IconLocation = "$exe,0"
        $shortcut.Description = "PowerShell Customization - $name"
        $shortcut.Save()
    }
}

$options = Get-InstallOptions
Save-InstallOptions -Options $options

if (-not $SkipDependencies) {
    Ensure-WingetApplication -Name 'Windows Terminal' -Command 'wt.exe' -WingetId 'Microsoft.WindowsTerminal' | Out-Null
    Ensure-WingetApplication -Name 'PowerShell 7' -Command 'pwsh.exe' -WingetId 'Microsoft.PowerShell' | Out-Null
    Ensure-WingetApplication -Name 'Oh My Posh' -Command 'oh-my-posh.exe' -WingetId 'JanDeDobbeleer.OhMyPosh' | Out-Null
    Ensure-PowerShellModule -Name 'Terminal-Icons'
    Ensure-PowerShellModule -Name 'PSReadLine'
    Ensure-MesloFont

    if ($options.OpenShiftStern) {
        Ensure-OcClient | Out-Null
        Ensure-WingetApplication -Name 'Stern' -Command 'stern.exe' -WingetId 'stern.stern' | Out-Null
    }
}

Install-RuntimeFiles -Options $options
Install-Graphics
Install-WindowsTerminalFragment
Build-Launchers -Names $options.Launchers
Install-LauncherShortcuts -Names $options.Launchers

$powerShell7Profile = if (-not [string]::IsNullOrWhiteSpace($ProfilePathOverride)) {
    [IO.Path]::GetFullPath($ProfilePathOverride)
}
else {
    $documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1'
}
Update-ManagedProfileBlock -ProfilePath $powerShell7Profile

Write-Host ''
Write-Host 'Installazione completata.' -ForegroundColor Green
Write-Host "Profilo PowerShell 7: $powerShell7Profile"
Write-Host "Asset PNG/ICO: $script:AssetRoot"
Write-Host "Windows Terminal fragments: $script:FragmentRoot"
Write-Host "Launcher EXE: $script:LauncherRoot"
Write-Host "Creati: $((@($options.Launchers) | ForEach-Object { "$_.exe" }) -join ', ')" -ForegroundColor Green
Write-Host 'Il contenuto preesistente del profilo PowerShell non viene sovrascritto.' -ForegroundColor Cyan
