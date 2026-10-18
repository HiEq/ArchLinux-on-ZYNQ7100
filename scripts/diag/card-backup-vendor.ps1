# 备份 TF 卡原厂 BOOT.BIN 到 BACKUP\，然后移除盘符
$n = 2
Add-PartitionAccessPath -DiskNumber $n -PartitionNumber 1 -AccessPath 'E:' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$src = 'E:\BOOT.BIN'
$dstDir = 'C:\Users\wwwmt\Desktop\BACKUP\vendor-card'
if (-not (Test-Path -LiteralPath $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
$dst = Join-Path $dstDir 'BOOT.BIN'

$md5 = (Get-FileHash -LiteralPath $src -Algorithm MD5).Hash
Copy-Item -LiteralPath $src -Destination $dst -Force
$md5b = (Get-FileHash -LiteralPath $dst -Algorithm MD5).Hash
"  源  : {0}  {1:N0} B  md5={2}" -f $src, (Get-Item $src).Length, $md5
"  备份: {0}  {1:N0} B  md5={2}" -f $dst, (Get-Item $dst).Length, $md5b
if ($md5 -ne $md5b) { throw '备份校验不一致' }
Write-Host '  备份校验一致 ✓'

Remove-PartitionAccessPath -DiskNumber $n -PartitionNumber 1 -AccessPath 'E:' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Get-Partition -DiskNumber $n | Select-Object PartitionNumber,DriveLetter | Format-Table -AutoSize | Out-String
