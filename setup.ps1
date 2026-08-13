[CmdletBinding()]
param(
    [switch]$SkipDependencies,
    [switch]$Reconfigure
)

$ErrorActionPreference = 'Stop'

$installScript = Join-Path $PSScriptRoot 'install.ps1'
$refreshScript = Join-Path $PSScriptRoot 'refresh.ps1'

$installArgs = @{}
if ($SkipDependencies) { $installArgs.SkipDependencies = $true }
if ($Reconfigure) { $installArgs.Reconfigure = $true }

& $installScript @installArgs
& $refreshScript

Write-Host ''
Write-Host 'Setup completato.' -ForegroundColor Green
Write-Host 'Apri una nuova tab PowerShell. Da quel momento usa: git pull; reload' -ForegroundColor Cyan
