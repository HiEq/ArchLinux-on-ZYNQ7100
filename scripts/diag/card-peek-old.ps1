# 记录 TF 卡（磁盘 2）原厂内容，随后移除盘符
$n = 2
$part = Get-Partition -DiskNumber $n -PartitionNumber 1
if (-not $part.DriveLetter) {
  Add-PartitionAccessPath -DiskNumber $n -PartitionNumber 1 -AccessPath 'E:' -ErrorAction Stop
  Start-Sleep -Seconds 2
}

Write-Host '=== 原厂分区内容 ==='
$root = 'E:\'
Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue |
  Select-Object Mode,Length,LastWriteTime,Name | Format-Table -AutoSize | Out-String

Write-Host '=== 目录总用量 ==='
$files = Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue
"  文件数: {0}   合计: {1:N1} MiB" -f $files.Count, (($files | Measure-Object Length -Sum).Sum / 1MB)

Write-Host '=== 移除盘符 E: ==='
Remove-PartitionAccessPath -DiskNumber $n -PartitionNumber 1 -AccessPath 'E:' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Get-Partition -DiskNumber $n | Select-Object PartitionNumber,DriveLetter,@{n='GB';e={[math]::Round($_.Size/1GB,2)}} | Format-Table -AutoSize | Out-String
