# 受控实验：FileStream 缓冲 + Seek 组合下，写入是否真的落到正确位置
$ErrorActionPreference = 'Stop'
$Disk = '\\.\PHYSICALDRIVE2'
$A = 64MB      # 卡偏移（位于 p1 空闲区，随便写，之后反正会重写整卡）
$B = 96MB

function Pattern([int]$len, [byte]$tag) {
  $b = New-Object byte[] $len
  for ($i = 0; $i -lt $len; $i++) { $b[$i] = [byte](($tag + $i) % 251) }
  return ,$b
}
function ReadAt([int64]$off, [int]$len) {
  $fs = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
          [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, 4096)
  try {
    $fs.Seek($off, 'Begin') | Out-Null
    $b = New-Object byte[] $len; $got = 0
    while ($got -lt $len) { $n = $fs.Read($b, $got, $len - $got); if ($n -le 0) { break }; $got += $n }
    return ,$b
  } finally { $fs.Close() }
}
function Compare([byte[]]$a, [byte[]]$b) {
  $n = [Math]::Min($a.Length, $b.Length)
  $d = 0; for ($i = 0; $i -lt $n; $i++) { if ($a[$i] -ne $b[$i]) { $d++ } }
  return $d
}

$Len = 1MB
$pa = Pattern $Len 0x11
$pb = Pattern $Len 0x77

function Case([string]$name, [int]$bufSize, [bool]$flushBetween, [bool]$writeThrough) {
  $opts = if ($writeThrough) { [System.IO.FileOptions]::WriteThrough } else { [System.IO.FileOptions]::None }
  $fs = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
          [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite, $bufSize, $opts)
  try {
    $fs.Seek($A, 'Begin') | Out-Null; $fs.Write($pa, 0, $Len)
    if ($flushBetween) { $fs.Flush($true) }
    $fs.Seek($B, 'Begin') | Out-Null; $fs.Write($pb, 0, $Len)
    $fs.Flush($true)
  } finally { $fs.Close() }

  Start-Sleep -Milliseconds 300
  $ra = ReadAt $A $Len
  $rb = ReadAt $B $Len
  $da = Compare $pa $ra
  $db = Compare $pb $rb
  Write-Host ("  {0,-46} A(64MiB) 差异 {1,8:N0}   B(96MiB) 差异 {2,8:N0}   {3}" -f `
    $name, $da, $db, $(if ($da -eq 0 -and $db -eq 0) { '通过' } else { '失败' }))
}

Write-Host '=== 写入路径实验（每次写 1 MiB，位置 64 MiB / 96 MiB）==='
Case '缓冲4MiB + WriteThrough，两次写之间不刷'   4MB   $false $true
Case '缓冲4MiB + WriteThrough，两次写之间刷'     4MB   $true  $true
Case '缓冲4MiB，无 WriteThrough，最后刷'         4MB   $false $false
Case '缓冲4KiB + WriteThrough'                   4096  $false $true
Case '缓冲4MiB + WriteThrough，只写 A 一处'      4MB   $true  $true
