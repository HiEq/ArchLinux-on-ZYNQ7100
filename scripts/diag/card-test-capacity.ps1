# 容量/写入路径测试：在若干偏移各写 64 KiB 独有的图案，再逐点回读
$ErrorActionPreference = 'Stop'
$Disk = '\\.\PHYSICALDRIVE2'
$Blk  = 64KB

function Pat([int64]$off) {
  $b = New-Object byte[] $Blk
  $o = [BitConverter]::GetBytes([int64]$off)
  [Array]::Copy($o, 0, $b, 0, 8)
  for ($i = 8; $i -lt $Blk; $i++) { $b[$i] = [byte]((($off * 31 + $i * 7) % 251)) }
  return ,$b
}
function DevWrite([int64]$off, [byte[]]$data) {
  $fs = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
          [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite, 4096)
  try { $fs.Seek($off, 'Begin') | Out-Null; $fs.Write($data, 0, $data.Length); $fs.Flush($true) }
  finally { $fs.Close() }
}
function DevRead([int64]$off, [int]$len) {
  $fs = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
          [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, 4096)
  try {
    $fs.Seek($off, 'Begin') | Out-Null
    $b = New-Object byte[] $len; $got = 0
    while ($got -lt $len) { $n = $fs.Read($b, $got, $len - $got); if ($n -le 0) { break }; $got += $n }
    return ,$b
  } finally { $fs.Close() }
}
function Diff([byte[]]$a, [byte[]]$b) {
  $n = [Math]::Min($a.Length, $b.Length); $d = 0
  for ($i = 0; $i -lt $n; $i++) { if ($a[$i] -ne $b[$i]) { $d++ } }
  return $d
}

# 先清分区表，释放 Windows 已挂载的卷（否则 1 MiB–513 MiB 区间禁止裸写）
Write-Host '=== 清分区表（释放卷）==='
$zero = New-Object byte[] 1MB
$fs = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite, 1MB)
try { $fs.Seek(0, 'Begin') | Out-Null; $fs.Write($zero, 0, 1MB); $fs.Flush($true) } finally { $fs.Close() }
'rescan' | diskpart | Out-Null
Start-Sleep -Seconds 3
if (Get-Volume -ErrorAction SilentlyContinue | Where-Object DiskNumber -eq 2) {
  Write-Host '  警告：仍有卷被挂载'
}

$offsets = @(100MB, 300MB, 500MB, 600MB, 1GB, 2GB, 3GB, 4GB, 5GB, 6GB, 7GB, 8GB, 10GB, 12GB, 14GB, 16GB, 17GB, 18GB, 20GB, 22GB, 24GB, 26GB, 28GB, 29GB)

Write-Host ''
Write-Host '=== 逐点写入 64 KiB → 回读比对 ==='
$results = @()
foreach ($o in $offsets) {
  $p = Pat $o
  DevWrite $o $p
  $r = DevRead $o $Blk
  $d = Diff $p $r
  $results += [pscustomobject]@{ Offset = $o; Diff = $d; OK = ($d -eq 0) }
  $mark = if ($d -eq 0) { 'OK  ' } else { 'FAIL' }
  $color = if ($d -eq 0) { 'Gray' } else { 'Yellow' }
  Write-Host ("  {0,10:N0} MiB ({1,5:N2} GiB)  {2}  差异字节 {3,7:N0}" -f ($o/1MB), ($o/1GB), $mark, $d) -ForegroundColor $color
}

Write-Host ''
$okList  = ($results | Where-Object OK   | ForEach-Object { "{0:N0}" -f ($_.Offset/1MB) }) -join ', '
$badList = ($results | Where-Object { -not $_.OK } | ForEach-Object { "{0:N0}" -f ($_.Offset/1MB) }) -join ', '
Write-Host ("  成功偏移(MiB): {0}" -f $okList)
Write-Host ("  失败偏移(MiB): {0}" -f $badList)

if ($badList) {
  Write-Host ''
  Write-Host '=== 对第一个失败点重写一次再看（区分“写被丢弃”与“读到旧数据”）==='
  $first = ($results | Where-Object { -not $_.OK } | Select-Object -First 1).Offset
  $p = Pat ($first + 1)
  DevWrite $first $p
  Start-Sleep -Milliseconds 500
  $r = DevRead $first $Blk
  Write-Host ("  重写 {0:N0} MiB 后差异 {1:N0}" -f ($first/1MB), (Diff $p $r))
}

Write-Host ''
Write-Host '=== 首点复查（检测写入是否被回绕覆盖到低地址）==='
$p0 = Pat $offsets[0]
$r0 = DevRead $offsets[0] $Blk
Write-Host ("  {0:N0} MiB 差异 {1:N0}" -f ($offsets[0]/1MB), (Diff $p0 $r0))
