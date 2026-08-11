param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("matrix_neon_gpt","cyber_glass_gpt","neon_dev_gpt","stern_hud_gpt")]
    [string]$Theme
)

$ErrorActionPreference = "SilentlyContinue"
$env:VIRTUAL_ENV_DISABLE_PROMPT = "1"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$ps7Profile = $PROFILE.CurrentUserCurrentHost
if (Test-Path $ps7Profile) {
    . $ps7Profile
}

if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}

$themePath = Join-Path $PSScriptRoot "themes\$Theme.omp.json"
if (-not (Test-Path -LiteralPath $themePath -PathType Leaf)) {
    Write-Warning "Tema Oh My Posh non trovato: $themePath"
}
elseif (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config $themePath | Invoke-Expression
}

if (Get-Module PSReadLine) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle InlineView
}

$Host.UI.RawUI.WindowTitle = "CyberGPT :: $Theme"
