# 校验 p3（SHARE）里的离线源是否完好：与 cache 展开的 share\repo 逐文件比对 md5
#   用法： .\card-check-p3.ps1 [-Card F:\] [-Source ..\..\share\repo]
param(
  [string]$Card   = 'F:\',
  [string]$Source = ''
)
$ErrorActionPreference = 'Stop'
if (-not $Source) {
  $Source = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\share\repo'))
}
$dst = Join-Path $Card 'repo'

if (-not (Test-Path -LiteralPath $dst)) { Write-Host "  找不到 $dst" -ForegroundColor Red; exit 1 }
if (-not (Test-Path -LiteralPath $Source)) { Write-Host "  找不到 $Source" -ForegroundColor Red; exit 1 }

$sf = Get-ChildItem -LiteralPath $Source -File | Sort-Object Name
Write-Host ("  源: {0} 个文件，{1:N1} MiB" -f $sf.Count, (($sf | Measure-Object Length -Sum).Sum / 1MB))

$bad = 0
foreach ($f in $sf) {
  $t = Join-Path $dst $f.Name
  if (-not (Test-Path -LiteralPath $t)) { Write-Host ("  缺失: {0}" -f $f.Name) -ForegroundColor Red; $bad++; continue }
  $a = (Get-FileHash -LiteralPath $f.FullName -Algorithm MD5).Hash
  $b = (Get-FileHash -LiteralPath $t -Algorithm MD5).Hash
  if ($a -ne $b) { Write-Host ("  不一致: {0}" -f $f.Name) -ForegroundColor Red; $bad++ }
}

Write-Host ''
Write-Host ("  根目录内容: {0}" -f ((Get-ChildItem -LiteralPath $Card -Force | ForEach-Object { $_.Name }) -join ', '))
if ($bad -eq 0) {
  Write-Host ("  全部 {0} 个文件 md5 一致" -f $sf.Count) -ForegroundColor Green
} else {
  Write-Host ("  {0} 个文件有问题" -f $bad) -ForegroundColor Red
  exit 2
}
