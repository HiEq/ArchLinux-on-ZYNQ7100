# 诊断 p2/p3 回读不一致的原因
$ErrorActionPreference = 'Stop'
$Disk    = '\\.\PHYSICALDRIVE2'
$WslDir  = '\\wsl.localhost\Ubuntu-22.04\home\hieq\alarm'
$Base    = @{ 'p1.img' = 1048576; 'p2.img' = 537919488; 'p3.img' = 17717788672 }
$Block   = 64KB

function ReadFull($fs, [int64]$off, [int]$len) {
  $fs.Seek($off, 'Begin') | Out-Null
  $b = New-Object byte[] $len
  $got = 0
  while ($got -lt $len) {
    $n = $fs.Read($b, $got, $len - $got)
    if ($n -le 0) { break }
    $got += $n
  }
  if ($got -lt $len) { throw ("读取不足: 需要 $len 实际 $got @$off") }
  return $b
}

# ---- 清单 ----
$plan = @{}
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $WslDir 'manifest.txt'))) {
  if ($line.StartsWith('#') -or $line.Trim() -eq '') { continue }
  $p = $line.Split('|')
  if (-not $plan.ContainsKey($p[0])) { $plan[$p[0]] = New-Object System.Collections.ArrayList }
  [void]$plan[$p[0]].Add(@([int64]$p[1], [int64]$p[2]))
}

Write-Host '=== 当前卷/盘符状态 ==='
Get-Partition -DiskNumber 2 | Select-Object PartitionNumber,DriveLetter,Type,@{n='MB';e={[math]::Round($_.Size/1MB)}} | Format-Table -AutoSize | Out-String
Get-Volume -ErrorAction SilentlyContinue | Where-Object DiskNumber -eq 2 |
  Select-Object DriveLetter,FileSystemLabel,FileSystem,OperationalStatus,HealthStatus | Format-Table -AutoSize | Out-String
foreach ($d in 'E:','F:') {
  if (Test-Path "$d\") {
    Write-Host "=== $d 根目录 ==="
    Get-ChildItem -LiteralPath "$d\" -Force -ErrorAction SilentlyContinue |
      Select-Object Mode,Length,LastWriteTime,Name | Format-Table -AutoSize | Out-String
  }
}

$dev = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, $Block)

try {
  foreach ($name in 'p2.img','p3.img') {
    $exts = $plan[$name]
    Write-Host ("=== {0}：{1} 个区块 ===" -f $name, $exts.Count)
    foreach ($e in $exts) { Write-Host ("    off={0,13:N0}  len={1,11:N0}" -f $e[0], $e[1]) }

    $in = New-Object System.IO.FileStream((Join-Path $WslDir $name), [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, $Block)
    try {
      # 首 / 中 / 尾 三个区块各取前 256 KiB 逐字节比对
      $pickIdx = @(0, [int]($exts.Count / 2), $exts.Count - 1) | Select-Object -Unique
      foreach ($i in $pickIdx) {
        $e = $exts[$i]
        $len = [int][Math]::Min(262144, $e[1])
        $src = ReadFull $in  $e[0]                $len
        $card = ReadFull $dev ([int64]($Base[$name] + $e[0])) $len
        $diff = -1
        for ($k = 0; $k -lt $len; $k++) { if ($src[$k] -ne $card[$k]) { $diff = $k; break } }
        if ($diff -lt 0) {
          Write-Host ("    区块#{0} off={1:N0}: 前 {2:N0} B 一致" -f $i, $e[0], $len)
        } else {
          $s = ($src[$diff..([Math]::Min($diff+15, $len-1))] | ForEach-Object { $_.ToString('x2') }) -join ' '
          $c = ($card[$diff..([Math]::Min($diff+15, $len-1))] | ForEach-Object { $_.ToString('x2') }) -join ' '
          Write-Host ("    区块#{0} off={1:N0}: 首个差异 @+{2:N0} (卡上 {3:N0})" -f $i, $e[0], $diff, ($e[0]+$diff)) -ForegroundColor Yellow
          Write-Host ("        镜像: {0}" -f $s)
          Write-Host ("        卡上: {0}" -f $c)
          $ndiff = 0; for ($k = 0; $k -lt $len; $k++) { if ($src[$k] -ne $card[$k]) { $ndiff++ } }
          Write-Host ("        该 256 KiB 内差异字节数: {0:N0}" -f $ndiff)
        }
      }
    } finally { $in.Close() }
  }
} finally { $dev.Close() }
