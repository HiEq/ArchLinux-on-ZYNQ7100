# 按清单把分区镜像裸写到 TF 卡并回读校验（Windows PowerShell 5.1）
#   清单由 WSL 侧 make_manifest.py 生成：非零区块（1 MiB 粒度）+ 每镜像的区块内容 sha256
param(
  [string]$Disk    = '\\.\PHYSICALDRIVE2',
  [string]$WslDir  = '\\wsl.localhost\Ubuntu-22.04\home\hieq\alarm',
  [switch]$NoVerify,
  [string[]]$Only            # 只写指定镜像（如 p1.img），此时不清分区表
)
$ErrorActionPreference = 'Stop'
$Chunk = 4MB
$n     = [int]($Disk -replace '\D', '')

# 镜像在卡上的起始偏移（字节），必须与 build_images.sh 一致
# 分区起始字节偏移（与 30-build-images.sh 一致）
$Base = @{
  'mbr.img' = 0
  'p1.img'  = 1048576
  'p2.img'  = 537919488
  'p3.img'  = 17717788672
}

$manifestPath = Join-Path $WslDir 'manifest.txt'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "缺少清单: $manifestPath" }

$plan = @{}      # 文件名 -> List of (off,len)
$hashes = @{}    # 文件名 -> @{ sha = ...; bytes = ... }
foreach ($line in [System.IO.File]::ReadAllLines($manifestPath)) {
  if ($line.StartsWith('#HASH|')) {
    $p = $line.Split('|')
    $hashes[$p[1]] = @{ sha = $p[2]; bytes = [int64]$p[3] }
  } elseif ($line.Trim() -ne '') {
    $p = $line.Split('|')
    if (-not $plan.ContainsKey($p[0])) { $plan[$p[0]] = New-Object System.Collections.ArrayList }
    [void]$plan[$p[0]].Add(@([int64]$p[1], [int64]$p[2]))
  }
}
Write-Host "清单：$(($plan.Keys | Sort-Object) -join ', ')"

$selected = @('p1.img','p2.img','p3.img','mbr.img')
if ($Only) { $selected = $selected | Where-Object { $Only -contains $_ } }

# ---- 先清掉分区表，逼 Windows 放掉已挂载的卷 ----
# Windows 对「已挂载卷」所在扇区拒绝裸写（ERROR_ACCESS_DENIED）；
# 分区表清空后 mountmgr 会卸载该卷，之后整卡可任意位置写入。
# 只补写部分镜像时跳过此步，否则会清掉已写好的分区表。
if (-not $Only) {
  Write-Host ''
  Write-Host '=== 清零分区表（释放卷） ==='
  $zero = New-Object byte[] 1MB
  $tmp = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
          [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite,
          1MB, [System.IO.FileOptions]::WriteThrough)
  try {
    $tmp.Seek(0, 'Begin') | Out-Null
    $tmp.Write($zero, 0, 1MB)
    $tmp.Flush($true)
  } finally { $tmp.Close() }
  'rescan' | diskpart | Out-Null
  Start-Sleep -Seconds 3
  $vols = Get-Volume -ErrorAction SilentlyContinue | Where-Object DiskNumber -eq $n
  if ($vols) {
    Write-Host '  仍有卷被挂载：' -ForegroundColor Yellow
    $vols | Select-Object DriveLetter,FileSystemLabel,FileSystem | Format-Table -AutoSize | Out-String
  } else {
    Write-Host '  该磁盘已无卷被挂载 ✓'
  }
}

$dev = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite,
        $Chunk, [System.IO.FileOptions]::WriteThrough)
$buf = New-Object byte[] $Chunk

try {
  Write-Host ''
  Write-Host '=== 写入 ==='
  # 注意：MBR 必须最后写，否则分区表变动会让 Windows 立刻重新挂载卷
  foreach ($name in $selected) {
    if (-not $plan.ContainsKey($name)) { continue }
    $src = Join-Path $WslDir $name
    if (-not (Test-Path -LiteralPath $src)) { throw "缺少镜像: $src" }
    $in = New-Object System.IO.FileStream($src, [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite,
            $Chunk, [System.IO.FileOptions]::SequentialScan)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $done = 0L
    try {
      foreach ($ext in $plan[$name]) {
        $off = $ext[0]; $len = $ext[1]
        $in.Seek($off, 'Begin') | Out-Null
        $dev.Seek([int64]($Base[$name] + $off), 'Begin') | Out-Null
        $left = $len
        while ($left -gt 0) {
          $want = [int][Math]::Min([int64]$Chunk, $left)
          $got = $in.Read($buf, 0, $want)
          if ($got -le 0) { throw "读取 $name 失败于偏移 $off" }
          $dev.Write($buf, 0, $got)
          $left -= $got; $done += $got
        }
      }
      $dev.Flush($true)
      $sw.Stop()
      Write-Host ("  {0,-8} 写入 {1,10:N1} MB   {2,6:N1} MB/s" -f $name, ($done/1MB), ($done/1MB/$sw.Elapsed.TotalSeconds))
    } finally { $in.Close() }
  }
} finally { $dev.Close() }

if ($NoVerify) { Write-Host '（跳过校验）'; return }

Write-Host ''
Write-Host '=== 回读校验（只比对写入过的区块） ==='
$rd = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, $Chunk)
try {
  $ok = $true
  foreach ($name in $selected) {
    $want = $hashes[$name]
    if (-not $want) { Write-Host "  $name : 清单无哈希，跳过"; continue }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($ext in $plan[$name]) {
      $off = $ext[0]; $len = $ext[1]
      $rd.Seek([int64]($Base[$name] + $off), 'Begin') | Out-Null
      $left = $len
      while ($left -gt 0) {
        $want2 = [int][Math]::Min([int64]$Chunk, $left)
        $got = $rd.Read($buf, 0, $want2)
        if ($got -le 0) { throw "回读 $name 失败" }
        $sha.TransformBlock($buf, 0, $got, $null, 0) | Out-Null
        $left -= $got
      }
    }
    $sha.TransformFinalBlock(@(), 0, 0) | Out-Null
    $gotHash = ($sha.Hash | ForEach-Object { $_.ToString('x2') }) -join ''
    $sha.Dispose()
    $sw.Stop()
    $pass = ($gotHash -eq $want.sha)
    if (-not $pass) { $ok = $false }
    Write-Host ("  {0,-8} {1}  {2,10:N1} MB 回读  {3,6:N1} MB/s" -f $name, $(if ($pass) { 'OK  ' } else { 'FAIL' }), ($want.bytes/1MB), ($want.bytes/1MB/$sw.Elapsed.TotalSeconds))
    if (-not $pass) {
      Write-Host ("      期望 {0}" -f $want.sha)
      Write-Host ("      实际 {0}" -f $gotHash)
    }
  }
  Write-Host $(if ($ok) { '  校验通过：卡上数据与镜像一致' } else { '  校验失败！' })
} finally { $rd.Close() }

Write-Host ''
Write-Host '=== 重新扫描磁盘 ==='
'rescan' | diskpart | Out-Null
$n = [int]($Disk -replace '\D', '')
Get-Disk -Number $n | Select-Object Number,FriendlyName,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},PartitionStyle | Format-Table -AutoSize | Out-String
Get-Partition -DiskNumber $n | Select-Object PartitionNumber,DriveLetter,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},Type,Offset | Format-Table -AutoSize | Out-String
