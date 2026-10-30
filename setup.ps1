[CmdletBinding()]
param(
    [switch]$SkipDependencies,
    [switch]$Reconfigure,
    [ValidateSet('Matrix GPT','Cyber Glass','Neon Dev','Stern HUD','Claude Code')]
    [string[]]$AddLauncher
)

$ErrorActionPreference = 'Stop'

$installScript = Join-Path $PSScriptRoot 'install.ps1'

$installArgs = @{}
if ($SkipDependencies) { $installArgs.SkipDependencies = $true }
if ($Reconfigure) { $installArgs.Reconfigure = $true }
if ($AddLauncher) { $installArgs.AddLauncher = $AddLauncher }

& $installScript @installArgs

Write-Host ''
Write-Host 'Setup completato.' -ForegroundColor Green
Write-Host 'Apri una nuova tab PowerShell. Da quel momento usa: git pull; reload' -ForegroundColor Cyan
