[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputRoot
)

$ErrorActionPreference = 'Stop'

try {
    Add-Type -AssemblyName System.Drawing.Common -ErrorAction Stop
}
catch {
    Add-Type -AssemblyName System.Drawing
}

$iconsRoot = Join-Path $OutputRoot 'icons'
$backgroundRoot = Join-Path $OutputRoot 'backgrounds'
$poolRoot = Join-Path $backgroundRoot 'pool'
$watermarkRoot = Join-Path $OutputRoot 'watermarks'

foreach ($directory in @($iconsRoot, $backgroundRoot, $poolRoot, $watermarkRoot)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

function Convert-HexColor {
    param([Parameter(Mandatory)][string]$Hex)
    return [System.Drawing.ColorTranslator]::FromHtml($Hex)
}

function New-CyberBitmap {
    param(
        [int]$Width,
        [int]$Height,
        [string]$Top,
        [string]$Bottom,
        [string]$Accent,
        [string]$Title,
        [string]$Subtitle,
        [switch]$Transparent
    )

    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    if ($Transparent) {
        $graphics.Clear([System.Drawing.Color]::Transparent)
    }
    else {
        $rect = [System.Drawing.Rectangle]::new(0, 0, $Width, $Height)
        $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $rect,
            (Convert-HexColor $Top),
            (Convert-HexColor $Bottom),
            35.0)
        $graphics.FillRectangle($brush, $rect)
        $brush.Dispose()

        $accentColor = Convert-HexColor $Accent
        $gridColor = [System.Drawing.Color]::FromArgb(42, [int]$accentColor.R, [int]$accentColor.G, [int]$accentColor.B)
        $gridPen = [System.Drawing.Pen]::new($gridColor, 1)
        $horizon = [int]($Height * 0.58)
        for ($x = -$Width; $x -lt ($Width * 2); $x += [Math]::Max(50, [int]($Width / 18))) {
            $graphics.DrawLine($gridPen, [int]($Width / 2), $horizon, $x, $Height)
        }
        for ($y = $horizon; $y -lt $Height; $y += [Math]::Max(24, [int](($y - $horizon + 40) / 4))) {
            $graphics.DrawLine($gridPen, 0, $y, $Width, $y)
        }
        $gridPen.Dispose()

        $glowColor = [System.Drawing.Color]::FromArgb(105, [int]$accentColor.R, [int]$accentColor.G, [int]$accentColor.B)
        $glowPen = [System.Drawing.Pen]::new($glowColor, [Math]::Max(2, [int]($Width / 500)))
        $graphics.DrawLine($glowPen, 0, $horizon, $Width, $horizon)
        $graphics.DrawRectangle($glowPen, 18, 18, $Width - 37, $Height - 37)
        $glowPen.Dispose()
    }

    $accentColorForText = Convert-HexColor $Accent
    $titleSize = [Math]::Max(16, [int]($Width / 18))
    $subtitleSize = [Math]::Max(10, [int]($Width / 42))
    $titleFont = [System.Drawing.Font]::new('Segoe UI', $titleSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $subtitleFont = [System.Drawing.Font]::new('Consolas', $subtitleSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $titleBrush = [System.Drawing.SolidBrush]::new($accentColorForText)
    $subtitleColor = [System.Drawing.Color]::FromArgb(205, 220, 235, 245)
    $subtitleBrush = [System.Drawing.SolidBrush]::new($subtitleColor)

    $graphics.DrawString($Title, $titleFont, $titleBrush, 34, 32)
    $graphics.DrawString($Subtitle, $subtitleFont, $subtitleBrush, 38, 32 + $titleSize + 8)

    $titleBrush.Dispose()
    $subtitleBrush.Dispose()
    $titleFont.Dispose()
    $subtitleFont.Dispose()
    $graphics.Dispose()

    return $bitmap
}

function Save-Png {
    param([System.Drawing.Bitmap]$Bitmap, [string]$Path)
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $Bitmap.Dispose()
}

function New-ThemeIcon {
    param(
        [string]$Path,
        [string]$Background,
        [string]$Accent,
        [string]$Glyph
    )

    $size = 64
    $bitmap = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear((Convert-HexColor $Background))

    $accentColor = Convert-HexColor $Accent
    $pen = [System.Drawing.Pen]::new($accentColor, 3)
    $graphics.DrawRectangle($pen, 4, 4, 55, 55)
    $graphics.DrawLine($pen, 8, 51, 56, 12)

    $font = [System.Drawing.Font]::new('Segoe UI', 27, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $brush = [System.Drawing.SolidBrush]::new($accentColor)
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $graphics.DrawString($Glyph, $font, $brush, [System.Drawing.RectangleF]::new(0, 0, $size, $size), $format)

    $iconHandle = $bitmap.GetHicon()
    try {
        $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Create, [IO.FileAccess]::Write)
        try { $icon.Save($stream) } finally { $stream.Dispose() }
    }
    finally {
        if (-not ('NativeIconMethods' -as [type])) {
            Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NativeIconMethods {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
'@
        }
        [NativeIconMethods]::DestroyIcon($iconHandle) | Out-Null
        $format.Dispose()
        $brush.Dispose()
        $font.Dispose()
        $pen.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

$backgrounds = @(
    @{ File='01_roma_vaticano_neon.png'; Top='#06111D'; Bottom='#11081D'; Accent='#00D9FF'; Title='ROMA // VATICANO'; Subtitle='CYBER GLASS / PUBLIC EDITION' },
    @{ File='02_simrace_pitlane_neon.png'; Top='#020806'; Bottom='#07170F'; Accent='#00FF41'; Title='SIMRACE // PITLANE'; Subtitle='TELEMETRY GRID / NIGHT SESSION' },
    @{ File='03_roma_colosseo_future.png'; Top='#0B1020'; Bottom='#1A0A1D'; Accent='#C084FC'; Title='ROMA // COLOSSEO'; Subtitle='FUTURE DISTRICT / TERMINAL NODE' },
    @{ File='04_simrace_garage_future.png'; Top='#071018'; Bottom='#0D1B25'; Accent='#62E7FF'; Title='SIMRACE // GARAGE'; Subtitle='ENGINEERING BAY / SYSTEM READY' },
    @{ File='05_roma_colosseo_rain.png'; Top='#050B14'; Bottom='#15101C'; Accent='#FF6AD5'; Title='ROMA // RAIN'; Subtitle='COLOSSEO LINK / WET NIGHT' },
    @{ File='06_simrace_night_race.png'; Top='#02060A'; Bottom='#071423'; Accent='#FFD166'; Title='SIMRACE // NIGHT RACE'; Subtitle='RACE CONTROL / LIVE CHANNEL' }
)

foreach ($item in $backgrounds) {
    $bitmap = New-CyberBitmap -Width 1280 -Height 720 -Top $item.Top -Bottom $item.Bottom -Accent $item.Accent -Title $item.Title -Subtitle $item.Subtitle
    Save-Png -Bitmap $bitmap -Path (Join-Path $poolRoot $item.File)
}

$neonWatermark = New-CyberBitmap -Width 520 -Height 190 -Top '#000000' -Bottom '#000000' -Accent '#00C8FF' -Title 'NEON DEV' -Subtitle 'POWERSHELL / DEVELOPMENT' -Transparent
Save-Png -Bitmap $neonWatermark -Path (Join-Path $watermarkRoot 'svi_gpt.png')

$sternWatermark = New-CyberBitmap -Width 520 -Height 190 -Top '#000000' -Bottom '#000000' -Accent '#A78BFA' -Title 'STERN HUD' -Subtitle 'OPENSHIFT / LOG STREAM' -Transparent
Save-Png -Bitmap $sternWatermark -Path (Join-Path $watermarkRoot 'stern_logs.png')

New-ThemeIcon -Path (Join-Path $iconsRoot 'matrix_gpt.ico') -Background '#020806' -Accent '#00FF41' -Glyph 'M'
New-ThemeIcon -Path (Join-Path $iconsRoot 'matrix_gpt_clear.ico') -Background '#06111D' -Accent '#00D9FF' -Glyph 'C'
New-ThemeIcon -Path (Join-Path $iconsRoot 'svi_gpt_original.ico') -Background '#08111F' -Accent '#00C8FF' -Glyph 'N'
New-ThemeIcon -Path (Join-Path $iconsRoot 'stern_logs.ico') -Background '#090B18' -Accent '#A78BFA' -Glyph 'S'

$firstBackground = Join-Path $poolRoot '01_roma_vaticano_neon.png'
$currentBackground = Join-Path $backgroundRoot 'current.png'
Copy-Item -LiteralPath $firstBackground -Destination $currentBackground -Force

Write-Host "Asset grafici creati in: $OutputRoot" -ForegroundColor Green
