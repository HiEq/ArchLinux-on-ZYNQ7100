# 手工写完 p2 后自检：把卡上 p2 起始的前 4 MiB 与 p2.img 比对，并检查 ext4 特征
#   用法： .\card-check-p2.ps1                      （默认 p2 起始 = 537,919,488）
#          .\card-check-p2.ps1 -Offset 12345678      （你自己定的 p2 起始字节偏移）
param(
  [string]$Disk   = '\\.\PHYSICALDRIVE2',
  [int64] $Offset = 537919488,
  [string]$Image  = '\\wsl.localhost\Ubuntu-22.04\home\hieq\alarm\p2.img',
  [int]   $LengthMiB = 4
)

$ErrorActionPreference = 'Stop'
$len = $LengthMiB * 1MB

function ReadAt([string]$path, [int64]$off, [int]$len) {
  $fs = New-Object System.IO.FileStream($path, [System.IO.FileMode]::Open,
          [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, 1MB)
  try {
    $fs.Seek($off, 'Begin') | Out-Null
    $b = New-Object byte[] $len; $got = 0
    while ($got -lt $len) { $n = $fs.Read($b, $got, $len - $got); if ($n -le 0) { break }; $got += $n }
    if ($got -lt $len) { throw "读取不足：需要 $len，实际 $got（$path @ $off）" }
    return ,$b
  } finally { $fs.Close() }
}

Write-Host ("=== 读取卡上 p2 起始 {0:N0} 处前 {1} MiB ===" -f $Offset, $LengthMiB)
$card = ReadAt $Disk $Offset $len

Write-Host '=== 读取镜像同段 ==='
if (-not (Test-Path -LiteralPath $Image)) { throw "找不到镜像: $Image" }
$img = ReadAt $Image 0 $len

# ext4 特征：块大小在偏移 0x18，魔数 0xEF53 在超级块偏移 0x38（即 1024+0x38）
$magic = [BitConverter]::ToUInt16($card, 1024 + 0x38)
$logbs = [BitConverter]::ToUInt32($card, 1024 + 0x18)
$bsz   = [int](1024 * [Math]::Pow(2, $logbs))
$uuid  = ($card[1024+0x68..1024+0x77] | ForEach-Object { $_.ToString('x2') }) -join ''
Write-Host ("  超级块魔数: 0x{0:X4}  {1}" -f $magic, $(if ($magic -eq 0xEF53) { 'ext4 ✓' } else { '不是 ext4 ✗' }))
Write-Host ("  块大小: {0} B   UUID: {1}" -f $bsz, $uuid)

$diff = 0
for ($i = 0; $i -lt $len; $i++) { if ($card[$i] -ne $img[$i]) { $diff++ } }
Write-Host ''
if ($diff -eq 0) {
  Write-Host ("  前 {0} MiB 与 p2.img 完全一致 ✓" -f $LengthMiB) -ForegroundColor Green
} else {
  Write-Host ("  前 {0} MiB 有 {1:N0} 字节不一致 ✗ —— 写入未生效或偏移不对" -f $LengthMiB, $diff) -ForegroundColor Yellow
  $first = -1
  for ($i = 0; $i -lt $len; $i++) { if ($card[$i] -ne $img[$i]) { $first = $i; break } }
  $s = ($img[$first..([Math]::Min($first + 15, $len - 1))] | ForEach-Object { $_.ToString('x2') }) -join ' '
  $c = ($card[$first..([Math]::Min($first + 15, $len - 1))] | ForEach-Object { $_.ToString('x2') }) -join ' '
  Write-Host ("  首个差异 @+{0:N0}：镜像 {1}" -f $first, $s)
  Write-Host ("                    卡上 {0}" -f $c)
}

Write-Host ''
Write-Host '说明：完整校验需比对 16 GiB，过慢；本脚本比对前 4 MiB（含超级块/组描述符/位图/日志超级块），'
Write-Host '      足以判断写入是否生效。p2.img 整文件 sha256 见 docs/manual-partition.md。'
