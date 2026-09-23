param([string]$ToolDir = $env:RISCV_TOOLCHAIN_BIN)
$ErrorActionPreference = 'Stop'

$projectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$firmwareDir = Join-Path $projectDir 'firmware'
$buildDir = Join-Path $projectDir 'build/firmware'
if (-not $ToolDir) { throw 'Set RISCV_TOOLCHAIN_BIN or pass -ToolDir (directory containing riscv64-unknown-elf-gcc.exe).' }
$toolDir = $ToolDir
$gcc = Join-Path $toolDir 'riscv64-unknown-elf-gcc.exe'
$objcopy = Join-Path $toolDir 'riscv64-unknown-elf-objcopy.exe'
$objdump = Join-Path $toolDir 'riscv64-unknown-elf-objdump.exe'
$size = Join-Path $toolDir 'riscv64-unknown-elf-size.exe'
$nm = Join-Path $toolDir 'riscv64-unknown-elf-nm.exe'

foreach ($tool in @($gcc, $objcopy, $objdump, $size, $nm)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Missing RISC-V tool: $tool" }
}
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

function Build-TransferMode([string]$Name, [int]$Mode) {
    $source = Join-Path $firmwareDir 'src/memory_transfer_compare_firmware.c'
    $linker = Join-Path $firmwareDir 'linker/link.ld'
    $includeDir = Join-Path $firmwareDir 'include'
    $prefix = Join-Path $buildDir ("transfer_" + $Name)
    $elf = $prefix + '.elf'
    $map = $prefix + '.map'
    $dump = $prefix + '.dump'
    $bin = $prefix + '.bin'
    $mem = $prefix + '.mem'
    $sizeReport = $prefix + '.size.txt'
    $nmReport = $prefix + '.nm.txt'

    & $gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding `
        -fno-pic -fno-builtin -O2 "-DLOOP_MODE=$Mode" `
        '-Wl,--build-id=none' "-Wl,-Map,$map" -I $includeDir -T $linker $source -o $elf
    if ($LASTEXITCODE -ne 0) { throw "$Name firmware gcc failed" }

    & $objdump -d -S $elf | Set-Content -Encoding ascii $dump
    if ($LASTEXITCODE -ne 0) { throw "$Name objdump failed" }
    & $size $elf | Set-Content -Encoding ascii $sizeReport
    & $size -A $elf | Add-Content -Encoding ascii $sizeReport
    $textLine = Select-String -Path $sizeReport -Pattern '^\.text\s+([0-9]+)\s+' | Select-Object -Last 1
    if (-not $textLine) { throw "Could not parse .text size for $Name firmware" }
    $textBytes = [int]$textLine.Matches[0].Groups[1].Value
    $nmOutput = & $nm -n $elf
    $nmOutput | Set-Content -Encoding ascii $nmReport

    $bad = Select-String -Path $dump `
        -Pattern '^\s*[0-9a-f]+:\s+[0-9a-f ]+\s+(mul|mulh|mulhsu|mulhu|div|divu|rem|remu)\s'
    if ($bad) { throw "M-extension instruction found in $Name firmware" }

    & $objcopy -O binary $elf $bin
    if ($LASTEXITCODE -ne 0) { throw "$Name objcopy failed" }
    $bytes = [IO.File]::ReadAllBytes($bin)
    if ($bytes.Length -gt 4096) { throw "$Name binary exceeds 4 KiB RAM" }

    $words = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $bytes.Length; $i += 4) {
        $word = 0L
        for ($j = 0; $j -lt 4; $j++) {
            if (($i + $j) -lt $bytes.Length) {
                $word = $word -bor ([long]$bytes[$i + $j] -shl (8*$j))
            }
        }
        $words.Add(('{0:x8}' -f $word))
    }
    [IO.File]::WriteAllLines($mem, $words)

    $endLine = $nmOutput | Where-Object { $_ -match '\s_end$' } | Select-Object -First 1
    if (-not $endLine) { throw "Could not locate _end in $Name firmware" }
    $endAddress = [Convert]::ToUInt32((($endLine -split '\s+')[0]), 16)
    if ($endAddress -ge 0x00000ff0) {
        throw "$Name static sections collide with STACKADDR=0x00000ff0"
    }
    [pscustomobject]@{
        Mode = $Name
        ModeId = $Mode
        BinBytes = $bytes.Length
        TextBytes = $textBytes
        EndAddress = ('0x{0:x8}' -f $endAddress)
        StackGap = 0x00000ff0 - $endAddress
    }
}

$results = @(
    Build-TransferMode -Name 'baseline' -Mode 0
    Build-TransferMode -Name 'write_unroll4' -Mode 1
    Build-TransferMode -Name 'read_unroll4' -Mode 2
    Build-TransferMode -Name 'both_unroll4' -Mode 3
)
$results | Format-Table -AutoSize
$results | Export-Csv -NoTypeInformation -Encoding ascii `
    (Join-Path $buildDir 'memory_transfer_compare_build.csv')
Write-Host 'Memory-transfer firmware build PASS; RV32I, static RAM, and M-extension checks PASS.'
