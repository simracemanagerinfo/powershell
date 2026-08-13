# Public PowerShell compatibility entrypoint.
$bootstrapPath = Join-Path $PSScriptRoot 'bootstrap.ps1'
if (Test-Path -LiteralPath $bootstrapPath -PathType Leaf) {
    . $bootstrapPath
}
else {
    Write-Warning 'PowerShellCustomization bootstrap non trovato. Esegui refresh.ps1 dal repository.'
}
