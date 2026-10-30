param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("matrix_neon_gpt","cyber_glass_gpt","cyber_2_0_gpt","neon_dev_gpt","stern_hud_gpt","claude_code")]
    [string]$Theme,
    [switch]$LaunchClaude,
    [switch]$UseCurrentDirectory
)

$ErrorActionPreference = "SilentlyContinue"
$env:VIRTUAL_ENV_DISABLE_PROMPT = "1"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# Carica il normale profilo PowerShell 7, compreso il blocco gestito dal repository.
$ps7Profile = $PROFILE.CurrentUserCurrentHost

if (Test-Path $ps7Profile) {
    . $ps7Profile
}
else {
    Write-Warning "Profilo PowerShell 7 non trovato: $ps7Profile"
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
else {
    Write-Warning "Oh My Posh non trovato. Esegui install_cyber_gpt.ps1."
}

# Predictive IntelliSense, kept compact (inline rather than the large ListView).
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
        "cyber_2_0_gpt" {
            Set-PSReadLineOption -Colors @{
                Command="#FFD166"; Parameter="#00E5FF"; String="#64FF9B"
                Operator="#62E7FF"; Variable="#FF5FD2"; Number="#FFB86C"
                Member="#00E5FF"; Type="#FFD166"; Comment="#507080"
                Keyword="#C084FC"; InlinePrediction="#3D5C68"
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
        "claude_code" {
            Set-PSReadLineOption -Colors @{
                Command="#EAA07C"; Parameter="#EBCFAD"; String="#B9DBA2"
                Operator="#D97757"; Variable="#E8B6CE"; Number="#F1CF82"
                Member="#E8A588"; Type="#F8D5BC"; Comment="#877870"
                Keyword="#D97757"; InlinePrediction="#74645C"
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

if ($LaunchClaude) {
    # Prima di avviare la CLI, seleziona sempre la directory corretta.
    $selector = Join-Path $PSScriptRoot 'Select-ClaudeProject.ps1'
    $selectedPath = if (Test-Path -LiteralPath $selector -PathType Leaf) {
        & $selector -UseCurrentDirectory:$UseCurrentDirectory
    }
    else {
        Write-Warning "Selettore progetti Claude non installato: $selector"
        $null
    }

    if (-not $selectedPath) {
        Write-Host '[CLAUDE CODE] Avvio annullato. Sei in PowerShell.' -ForegroundColor DarkYellow
        $Host.UI.RawUI.WindowTitle = 'PowerShell :: Claude non avviato'
    }
    else {
        try {
            Set-Location -LiteralPath $selectedPath -ErrorAction Stop
            Write-Host "[CLAUDE CODE] Progetto: $((Get-Location).Path)" -ForegroundColor DarkYellow

            $claudeCommand = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $claudeCommand) {
                Write-Warning 'Claude CLI non trovata nel PATH. Configura claude e riapri questo profilo.'
                $Host.UI.RawUI.WindowTitle = 'PowerShell :: Claude CLI assente'
            }
            else {
                $Host.UI.RawUI.WindowTitle = "Claude Code :: $((Get-Location).Path)"
                & claude
                Write-Host '[CLAUDE CODE] Sessione terminata. Ora sei in PowerShell.' -ForegroundColor DarkYellow
                $Host.UI.RawUI.WindowTitle = 'PowerShell :: Claude Code terminato'
            }
        }
        catch {
            Write-Warning "Avvio Claude CLI non riuscito: $($_.Exception.Message)"
            $Host.UI.RawUI.WindowTitle = 'PowerShell :: errore Claude'
        }
    }
}
else {
    $Host.UI.RawUI.WindowTitle = "CyberGPT :: $Theme"
}
