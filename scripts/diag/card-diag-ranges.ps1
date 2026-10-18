# 按区块只读比对：定位卡上哪些偏移量数据不对
$ErrorActionPreference = 'Stop'
$Disk   = '\\.\PHYSICALDRIVE2'
$WslDir = '\\wsl.localhost\Ubuntu-22.04\home\hieq\alarm'
$Base   = @{ 'p1.img' = 1048576; 'p2.img' = 537919488; 'p3.img' = 17717788672 }
$Probe  = 64KB

function ReadFull($fs, [int64]$off, [int]$len) {
  $fs.Seek($off, 'Begin') | Out-Null
  $b = New-Object byte[] $len
  $got = 0
  while ($got -lt $len) {
    $n = $fs.Read($b, $got, $len - $got)
    if ($n -le 0) { break }
    $got += $n
  }
  return ,$b
}

function Cmp($a, $b) { for ($i = 0; $i -lt $a.Length; $i++) { if ($a[$i] -ne $b[$i]) { return $i } }; return -1 }

# 清单
$plan = @{}
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $WslDir 'manifest.txt'))) {
  if ($line.StartsWith('#') -or $line.Trim() -eq '') { continue }
  $p = $line.Split('|')
  if (-not $plan.ContainsKey($p[0])) { $plan[$p[0]] = New-Object System.Collections.ArrayList }
  [void]$plan[$p[0]].Add(@([int64]$p[1], [int64]$p[2]))
}

$dev = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, $Probe)
try {
  foreach ($name in 'p2.img','p3.img') {
    $exts = @($plan[$name])
    $cnt  = $exts.Count
    Write-Host ("=== {0}：{1} 个区块，逐个取前 64 KiB 比对 ===" -f $name, $cnt)
    $in = New-Object System.IO.FileStream((Join-Path $WslDir $name), [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, $Probe)
    try {
      $bad = 0
      for ($i = 0; $i -lt $cnt; $i++) {
        $off = [int64]$exts[$i][0]; $len = [int64]$exts[$i][1]
        $probe = [int][Math]::Min([int64]$Probe, $len)
        $a = ReadFull  $in  $off $probe
        $b = ReadFull  $dev ([int64]($Base[$name] + $off)) $probe
        $d = Cmp $a $b
        $cardOff = [int64]($Base[$name] + $off)
        if ($d -lt 0) {
          Write-Host ("  #{0,-2} 镜像 {1,13:N0}  卡 {2,13:N0} ({3,5:N2} GiB)  OK" -f $i, $off, $cardOff, ($cardOff/1GB))
        } else {
          $bad++
          Write-Host ("  #{0,-2} 镜像 {1,13:N0}  卡 {2,13:N0} ({3,5:N2} GiB)  差异@+{4}" -f $i, $off, $cardOff, ($cardOff/1GB), $d) -ForegroundColor Yellow
        }
      }
      Write-Host ("  → {0} / {1} 个区块不一致" -f $bad, $cnt)
    } finally { $in.Close() }
  }

  # p3 的单区块再细分 8 段
  Write-Host '=== p3 单区块细分 8 段（覆盖 17.72–17.85 GiB）==='
  $e = @($plan['p3.img'])[0]
  $in = New-Object System.IO.FileStream((Join-Path $WslDir 'p3.img'), [System.IO.FileMode]::Open,
          [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, $Probe)
  try {
    $step = [int64]([int64]$e[1] / 8)
    for ($k = 0; $k -lt 8; $k++) {
      $off = [int64]($e[0] + $k * $step)
      $a = ReadFull $in $off $Probe
      $b = ReadFull $dev ([int64]($Base['p3.img'] + $off)) $Probe
      $d = Cmp $a $b
      $cardOff = [int64]($Base['p3.img'] + $off)
      if ($d -lt 0) { Write-Host ("  段{0} 卡 {1,13:N0} ({2,5:N2} GiB)  OK" -f $k, $cardOff, ($cardOff/1GB)) }
      else { Write-Host ("  段{0} 卡 {1,13:N0} ({2,5:N2} GiB)  差异@+{3}" -f $k, $cardOff, ($cardOff/1GB), $d) -ForegroundColor Yellow }
    }
  } finally { $in.Close() }
} finally { $dev.Close() }
