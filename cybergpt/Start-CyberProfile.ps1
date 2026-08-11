param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("matrix_neon_gpt","cyber_glass_gpt","neon_dev_gpt","stern_hud_gpt")]
    [string]$Theme
)

$ErrorActionPreference = "SilentlyContinue"
$env:VIRTUAL_ENV_DISABLE_PROMPT = "1"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# Carica il profilo PowerShell dell'utente senza sostituirlo.
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

    switch ($Theme) {
        "matrix_neon_gpt" {
            Set-PSReadLineOption -Colors @{
                Command="#D7FF72"; Parameter="#7DFFE0"; String="#A8FF60"
                Operator="#45FFD2"; Variable="#72FFB5"; Number="#C7FF8A"
                Member="#45FFD2"; Type="#B7FFD1"; Comment="#247344"
                Keyword="#72FFB5"; InlinePrediction="#247344"
            }
        }
        "cyber_glass_gpt" {
            Set-PSReadLineOption -Colors @{
                Command="#FFD166"; Parameter="#62E7FF"; String="#64FF9B"
                Operator="#7CFFD0"; Variable="#C084FC"; Number="#FFB86C"
                Member="#62E7FF"; Type="#FFD166"; Comment="#6B8A7A"
                Keyword="#C084FC"; InlinePrediction="#557067"
            }
        }
        "neon_dev_gpt" {
            Set-PSReadLineOption -Colors @{
                Command="#FF9F43"; Parameter="#42D6FF"; String="#59F2A9"
                Operator="#00E5FF"; Variable="#FF6AD5"; Number="#FFD166"
                Member="#00E5FF"; Type="#FF9F43"; Comment="#60738F"
                Keyword="#C678DD"; InlinePrediction="#455B78"
            }
        }
        "stern_hud_gpt" {
            Set-PSReadLineOption -Colors @{
                Command="#67E8F9"; Parameter="#A78BFA"; String="#2CE5A7"
                Operator="#38BDF8"; Variable="#C084FC"; Number="#FFD166"
                Member="#67E8F9"; Type="#A78BFA"; Comment="#615C86"
                Keyword="#C084FC"; InlinePrediction="#4B4769"
            }
        }
    }
}

$Host.UI.RawUI.WindowTitle = "CyberGPT :: $Theme"
