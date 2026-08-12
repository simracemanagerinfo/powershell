[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputDirectory,

    [Parameter(Mandatory)]
    [string]$AssetRoot,

    [Parameter()]
    [ValidateSet('Matrix GPT', 'Cyber Glass', 'Neon Dev', 'Stern HUD')]
    [string[]]$Launchers = @('Matrix GPT', 'Cyber Glass', 'Neon Dev', 'Stern HUD'),

    [Parameter(DontShow)]
    [switch]$ForcePortableToolchain
)

$ErrorActionPreference = 'Stop'

$llvmVersion = '20260616'
$llvmFolderName = "llvm-mingw-$llvmVersion-ucrt-x86_64"
$llvmUrl = "https://github.com/mstorsjo/llvm-mingw/releases/download/$llvmVersion/$llvmFolderName.zip"
$toolCacheRoot = Join-Path $env:LOCALAPPDATA 'PowerShellCustomization\build-tools'
$llvmRoot = Join-Path $toolCacheRoot $llvmFolderName

function Get-ExistingGnuToolchain {
    $gcc = Get-Command gcc.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    $windres = Get-Command windres.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gcc -and $windres) {
        return [pscustomobject]@{
            Kind = 'gnu'
            Compiler = $gcc.Source
            ResourceCompiler = $windres.Source
            ResourceConverter = $null
        }
    }
    return $null
}

function Get-PortableLlvmToolchain {
    $bin = Join-Path $llvmRoot 'bin'
    $clang = Join-Path $bin 'x86_64-w64-mingw32-clang.exe'
    $llvmRc = Join-Path $bin 'llvm-rc.exe'
    $llvmCvtRes = Join-Path $bin 'llvm-cvtres.exe'

    if (-not ((Test-Path -LiteralPath $clang -PathType Leaf) -and
              (Test-Path -LiteralPath $llvmRc -PathType Leaf) -and
              (Test-Path -LiteralPath $llvmCvtRes -PathType Leaf))) {
        New-Item -ItemType Directory -Path $toolCacheRoot -Force | Out-Null
        $archive = Join-Path $toolCacheRoot "$llvmFolderName.zip"

        Write-Host 'Compiler C non trovato. Scarico LLVM-MinGW portable nel profilo utente...' -ForegroundColor Cyan
        Invoke-WebRequest -Uri $llvmUrl -OutFile $archive -UseBasicParsing

        if (Test-Path -LiteralPath $llvmRoot) {
            Remove-Item -LiteralPath $llvmRoot -Recurse -Force
        }
        Expand-Archive -LiteralPath $archive -DestinationPath $toolCacheRoot -Force
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path -LiteralPath $clang -PathType Leaf)) {
        throw "LLVM-MinGW non contiene il compilatore atteso: $clang"
    }
    if (-not (Test-Path -LiteralPath $llvmRc -PathType Leaf)) {
        throw "LLVM-MinGW non contiene llvm-rc.exe: $llvmRc"
    }
    if (-not (Test-Path -LiteralPath $llvmCvtRes -PathType Leaf)) {
        throw "LLVM-MinGW non contiene llvm-cvtres.exe: $llvmCvtRes"
    }

    return [pscustomobject]@{
        Kind = 'llvm'
        Compiler = $clang
        ResourceCompiler = $llvmRc
        ResourceConverter = $llvmCvtRes
    }
}

function Get-BuildToolchain {
    if (-not $ForcePortableToolchain) {
        $existing = Get-ExistingGnuToolchain
        if ($existing) {
            Write-Host "Uso gcc/windres già presenti: $($existing.Compiler)" -ForegroundColor DarkGray
            return $existing
        }
    }
    else {
        Write-Host 'Test/uso forzato della toolchain LLVM-MinGW portable.' -ForegroundColor DarkGray
    }
    return Get-PortableLlvmToolchain
}

function New-ResourceScript {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$IconPath,
        [Parameter(Mandatory)][string]$ManifestPath
    )

    $icon = ([IO.Path]::GetFullPath($IconPath)).Replace('\', '/')
    $manifest = ([IO.Path]::GetFullPath($ManifestPath)).Replace('\', '/')
    $content = "1 ICON `"$icon`"`r`n1 24 `"$manifest`"`r`n"
    [IO.File]::WriteAllText($Path, $content, [Text.UTF8Encoding]::new($false))
}

$launcherDefinitions = @(
    @{ Name = 'Matrix GPT'; Source = 'Matrix GPT.c'; Icon = 'matrix_gpt.ico' },
    @{ Name = 'Cyber Glass'; Source = 'Cyber Glass.c'; Icon = 'matrix_gpt_clear.ico' },
    @{ Name = 'Neon Dev'; Source = 'Neon Dev.c'; Icon = 'svi_gpt_original.ico' },
    @{ Name = 'Stern HUD'; Source = 'Stern HUD.c'; Icon = 'stern_logs.ico' }
)

$manifestPath = Join-Path $PSScriptRoot 'launcher.manifest'
$iconRoot = Join-Path $AssetRoot 'icons'
$toolchain = Get-BuildToolchain
$selectedDefinitions = @($launcherDefinitions | Where-Object { $_.Name -in $Launchers })

if ($selectedDefinitions.Count -eq 0) {
    throw 'Seleziona almeno un launcher da compilare.'
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
foreach ($definition in $launcherDefinitions) {
    $previousOutput = Join-Path $OutputDirectory "$($definition.Name).exe"
    if (Test-Path -LiteralPath $previousOutput -PathType Leaf) {
        Remove-Item -LiteralPath $previousOutput -Force
    }
}
$tempRoot = Join-Path $env:TEMP "powershell-customization-launchers-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

Push-Location $PSScriptRoot
try {
    foreach ($launcher in $selectedDefinitions) {
        $source = Join-Path $PSScriptRoot $launcher.Source
        $icon = Join-Path $iconRoot $launcher.Icon
        $executable = Join-Path $OutputDirectory "$($launcher.Name).exe"
        $resourceRc = Join-Path $tempRoot "$($launcher.Name).rc"

        if (-not (Test-Path -LiteralPath $icon -PathType Leaf)) {
            throw "Icona mancante per $($launcher.Name): $icon"
        }

        New-ResourceScript -Path $resourceRc -IconPath $icon -ManifestPath $manifestPath

        if ($toolchain.Kind -eq 'gnu') {
            $resourceObject = Join-Path $tempRoot "$($launcher.Name).resource.o"
            & $toolchain.ResourceCompiler --input $resourceRc --output $resourceObject --output-format=coff
            if ($LASTEXITCODE -ne 0) {
                throw "windres non riuscito per $($launcher.Name)"
            }

            & $toolchain.Compiler -std=c11 -Os -s -mwindows -municode -ffunction-sections -fdata-sections `
                -Wall -Wextra -Werror '-Wl,--gc-sections' -o $executable $source $resourceObject
            if ($LASTEXITCODE -ne 0) {
                throw "gcc non riuscito per $($launcher.Name)"
            }
        }
        else {
            $resourceRes = Join-Path $tempRoot "$($launcher.Name).res"
            $resourceObject = Join-Path $tempRoot "$($launcher.Name).resource.o"

            & $toolchain.ResourceCompiler "/fo$resourceRes" $resourceRc
            if ($LASTEXITCODE -ne 0) {
                throw "llvm-rc non riuscito per $($launcher.Name)"
            }

            & $toolchain.ResourceConverter '/machine:x64' "/out:$resourceObject" $resourceRes
            if ($LASTEXITCODE -ne 0) {
                throw "llvm-cvtres non riuscito per $($launcher.Name)"
            }

            & $toolchain.Compiler -std=c11 -Os -s -mwindows -municode -ffunction-sections -fdata-sections `
                -Wall -Wextra -Werror '-Wl,--gc-sections' -o $executable $source $resourceObject
            if ($LASTEXITCODE -ne 0) {
                throw "clang non riuscito per $($launcher.Name)"
            }
        }

        if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
            throw "Build completata senza produrre $executable"
        }

        Write-Host "[BUILT] $executable" -ForegroundColor Green
    }
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$built = @(Get-ChildItem -LiteralPath $OutputDirectory -File -Filter '*.exe' | Sort-Object Name)
if ($built.Count -ne $selectedDefinitions.Count) {
    throw "Build incompleta: attesi $($selectedDefinitions.Count) EXE, trovati $($built.Count)."
}

$built | Select-Object Name, Length, @{ Name = 'SHA256'; Expression = { (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash } }
