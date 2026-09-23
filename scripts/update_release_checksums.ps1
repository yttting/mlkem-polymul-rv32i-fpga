$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$release = Join-Path $root 'release'
$lines = @('mlkem_pynqz2.bit', 'mlkem_pynqz2.ltx') | ForEach-Object {
    $hash = Get-FileHash -LiteralPath (Join-Path $release $_) -Algorithm SHA256
    '{0}  {1}' -f $hash.Hash.ToLowerInvariant(), $_
}
[IO.File]::WriteAllText((Join-Path $release 'SHA256SUMS'), ($lines -join "`n") + "`n", [Text.Encoding]::ASCII)
