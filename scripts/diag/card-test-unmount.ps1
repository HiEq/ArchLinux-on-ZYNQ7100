# 诊断：清零分区表后，Windows 是否放掉卷、能否裸写 1 MiB 处
$ErrorActionPreference = 'Stop'
$n = 2
$Disk = "\\.\PHYSICALDRIVE$n"
$Chunk = 1MB

function Test-Write([int64]$off) {
  $dev = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
          [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite,
          $Chunk, [System.IO.FileOptions]::WriteThrough)
  $buf = New-Object byte[] $Chunk
  try {
    $dev.Seek($off, 'Begin') | Out-Null
    $dev.Write($buf, 0, 512)
    $dev.Flush($true)
    return $true
  } catch {
    Write-Host ("    写入失败 @{0:N0}: {1}" -f $off, $_.Exception.Message)
    return $false
  } finally { $dev.Close() }
}

Write-Host '=== 写前状态 ==='
Get-Partition -DiskNumber $n -ErrorAction SilentlyContinue |
  Select-Object PartitionNumber,DriveLetter,IsOffline,@{n='OffMB';e={[math]::Round($_.Offset/1MB,2)}} | Format-Table -AutoSize | Out-String
Get-Volume -ErrorAction SilentlyContinue | Where-Object DiskNumber -eq $n |
  Select-Object DriveLetter,FileSystemLabel,FileSystem,HealthStatus,OperationalStatus | Format-Table -AutoSize | Out-String

Write-Host '=== 步骤 1：清零卡的第一个 1 MiB（清掉分区表和厂商 FAT32 引导扇区） ==='
$dev = New-Object System.IO.FileStream($Disk, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite,
        $Chunk, [System.IO.FileOptions]::WriteThrough)
try {
  $z = New-Object byte[] $Chunk
  $dev.Seek(0, 'Begin') | Out-Null
  $dev.Write($z, 0, $Chunk)
  $dev.Flush($true)
} finally { $dev.Close() }
Write-Host '  已清零'

Write-Host '=== 步骤 2：rescan 并等待 ==='
'rescan' | diskpart | Out-Null
Start-Sleep -Seconds 3
Get-Partition -DiskNumber $n -ErrorAction SilentlyContinue |
  Select-Object PartitionNumber,DriveLetter,@{n='OffMB';e={[math]::Round($_.Offset/1MB,2)}} | Format-Table -AutoSize | Out-String
$vols = Get-Volume -ErrorAction SilentlyContinue | Where-Object DiskNumber -eq $n
if ($vols) { $vols | Select-Object DriveLetter,FileSystemLabel,FileSystem | Format-Table -AutoSize | Out-String } else { Write-Host '  该磁盘已无卷被挂载' }

Write-Host '=== 步骤 3：试写 1 MiB 处 ==='
$ok = Test-Write 1048576
Write-Host ("  结果: {0}" -f $(if ($ok) { '成功 —— 清零分区表即可写' } else { '仍然失败 —— 需要 FSCTL 锁定/卸载' }))
