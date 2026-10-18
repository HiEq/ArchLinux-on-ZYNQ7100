# 打印差异字节 + 同一位置重复读稳定性检查
$ErrorActionPreference = 'Stop'
$Disk   = '\\.\PHYSICALDRIVE2'
$WslDir = '\\wsl.localhost\Ubuntu-22.04\home\hieq\alarm'
$Base   = @{ 'p1.img' = 1048576; 'p2.img' = 537919488; 'p3.img' = 17717788672 }

function ReadFull($fs, [int64]$off, [int]$len) {
  $fs.Seek($off, 'Begin') | Out-Null
  $b = New-Object byte[] $len
  $got = 0
  while ($got -lt $len) { $n = $fs.Read($b, $got, $len - $got); if ($n -le 0) { break }; $got += $n }
  return ,$b
}
function Hex8($b, [int]$from) {
  $to = [Math]::Min($from + 11, $b.Length - 1)
  return (($b[$from..$to] | ForEach-Object { $_.ToString('x2') }) -join ' ')
}

$plan = @{}
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $WslDir 'manifest.txt'))) {
  if ($line.StartsWith('#') -or $line.Trim() -eq '') { continue }
  $p = $line.Split('|')
  if (-not $plan.ContainsKey($p[0])) { $plan[$p[0]] = New-Object System.Collections.ArrayList }
  [void]$plan[$p[0]].Add(@([int64]$p[1], [int64]$p[2]))
}

$Probe = 64KB
$dev = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, $Probe)
try {
  # ---- 1. 差异字节 ----
  foreach ($pair in @(@('p2.img', 0, 0), @('p2.img', 8, 0), @('p2.img', 19, 0), @('p3.img', 0, 0))) {
    $name = $pair[0]; $ei = [int]$pair[1]
    $exts = @($plan[$name]); $e = $exts[$ei]
    $imgOff  = [int64]$e[0]
    $cardOff = [int64]($Base[$name] + $imgOff)
    $in = New-Object System.IO.FileStream((Join-Path $WslDir $name), [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, $Probe)
    try { $a = ReadFull $in $imgOff $Probe } finally { $in.Close() }
    $b = ReadFull $dev $cardOff $Probe

    $diffs = New-Object System.Collections.ArrayList
    for ($k = 0; $k -lt $Probe; $k++) { if ($a[$k] -ne $b[$k]) { [void]$diffs.Add($k); if ($diffs.Count -ge 8) { break } } }
    $total = 0; for ($k = 0; $k -lt $Probe; $k++) { if ($a[$k] -ne $b[$k]) { $total++ } }
    Write-Host ("=== {0} 区块#{1}  镜像偏移 {2:N0}  卡偏移 {3:N0} ===" -f $name, $ei, $imgOff, $cardOff)
    Write-Host ("  64 KiB 内差异字节总数: {0:N0}" -f $total)
    foreach ($d in $diffs) {
      Write-Host ("    @+{0,-6} 镜像 {1}   卡上 {2}" -f $d, (Hex8 $a $d), (Hex8 $b $d))
    }
  }

  # ---- 2. 重复读稳定性 ----
  Write-Host ''
  Write-Host '=== 同一位置连续读 3 次是否稳定 ==='
  foreach ($pair in @(@('p2.img', 0), @('p2.img', 8), @('p2.img', 19), @('p3.img', 0))) {
    $name = $pair[0]; $ei = [int]$pair[1]
    $exts = @($plan[$name]); $e = $exts[$ei]
    $cardOff = [int64]($Base[$name] + [int64]$e[0])
    $r1 = ReadFull $dev $cardOff $Probe
    Start-Sleep -Milliseconds 300
    $r2 = ReadFull $dev $cardOff $Probe
    Start-Sleep -Milliseconds 300
    $r3 = ReadFull $dev $cardOff $Probe
    $d12 = 0; $d13 = 0
    for ($k = 0; $k -lt $Probe; $k++) { if ($r1[$k] -ne $r2[$k]) { $d12++ }; if ($r1[$k] -ne $r3[$k]) { $d13++ } }
    Write-Host ("  {0} 区块#{1} 卡偏移 {2:N0}: 读1↔读2 差异 {3}，读1↔读3 差异 {4}" -f $name, $ei, $cardOff, $d12, $d13)
  }
} finally { $dev.Close() }
