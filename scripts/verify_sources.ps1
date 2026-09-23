$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$manifest = Import-Csv -LiteralPath (Join-Path $root 'docs/source_integrity.csv')
foreach ($entry in $manifest) {
    $file = Join-Path $root $entry.Path
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing source: $($entry.Path)" }
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    if ($actual -ne $entry.SHA256) { throw "Source content changed: $($entry.Path)" }
}
Write-Host "SOURCE_INTEGRITY_PASS: $($manifest.Count) files match the original 601079b snapshot."
