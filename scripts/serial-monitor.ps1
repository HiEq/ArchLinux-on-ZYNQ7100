<#
  串口控制台：收 + 发 + 落盘日志（Windows PowerShell 5.1）

  用法：
    watch-serial.bat                      默认 COM3 115200
    watch-serial.bat COM5                 指定端口
    watch-serial.bat -Port COM5 -Baud 921600
    watch-serial.bat -TimeStamp           每行加 [+秒] 时间戳（测启动耗时）
    watch-serial.bat -NoInput             只看不发（防止误触打断启动）
    watch-serial.bat -Log D:\x.log        自定义日志路径

  键盘：
    普通字符直接发到板子；Enter=CR；Backspace=BS；方向键=ESC[A/B
    Ctrl+C 作为 0x03 发给板子（用于打断 U-Boot / 内核日志）
    退出本程序：Ctrl+]

  日志默认写到 ..\logs\serial-<时间>.log
#>
param(
  [Parameter(Position = 0)]
  [string]$Port = 'COM3',
  [Parameter(Position = 1)]
  [int]   $Baud = 115200,
  [string]$Log,
  [switch]$TimeStamp,
  [switch]$NoInput,
  [switch]$Echo,
  [switch]$Append,
  [int]   $Duration = 0
)

$ErrorActionPreference = 'Stop'

if (-not $Log) {
  $logDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\logs'))
  if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
  $Log = Join-Path $logDir ("serial-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
} else {
  $logDir = Split-Path -Parent ([System.IO.Path]::GetFullPath($Log))
  if ($logDir -and -not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
}

$sp = New-Object System.IO.Ports.SerialPort
$sp.PortName  = $Port
$sp.BaudRate  = $Baud
$sp.Parity    = [System.IO.Ports.Parity]::None
$sp.DataBits  = 8
$sp.StopBits  = [System.IO.Ports.StopBits]::One
$sp.Handshake = [System.IO.Ports.Handshake]::None
$sp.DtrEnable = $false
$sp.RtsEnable = $false
$sp.ReadTimeout = 200
$sp.Encoding  = New-Object System.Text.UTF8Encoding $false

try {
  $sp.Open()
} catch {
  Write-Host "无法打开 $Port : $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "检查是否有其它程序占用该串口（putty / SecureCRT 等）。" -ForegroundColor Yellow
  exit 1
}

$sw = New-Object System.IO.StreamWriter($Log, $Append.IsPresent, (New-Object System.Text.UTF8Encoding $false))
$sw.AutoFlush = $true

# Ctrl+C 交给目标板，不杀本脚本；退出用 Ctrl+]
$ctrlCAsInput = $false
if (-not $NoInput) {
  try { [Console]::TreatControlCAsInput = $true; $ctrlCAsInput = $true } catch { }
}

Write-Host ("串口 {0} @ {1} 8N1 已打开" -f $Port, $Baud) -ForegroundColor DarkGray
Write-Host ("日志: {0}" -f $Log) -ForegroundColor DarkGray
if ($NoInput) {
  Write-Host "模式: 只收（Ctrl+C 退出）" -ForegroundColor DarkGray
} else {
  Write-Host "模式: 收发（Ctrl+C 发给板子，Ctrl+] 退出）" -ForegroundColor DarkGray
}
Write-Host ('-' * 72) -ForegroundColor DarkGray

$clock    = [System.Diagnostics.Stopwatch]::StartNew()
$lineBuf  = New-Object System.Text.StringBuilder
$canInput = $true
$quit     = $false

try {
  while (-not $quit) {
    if ($Duration -gt 0 -and $clock.Elapsed.TotalSeconds -ge $Duration) { break }

    $chunk = $sp.ReadExisting()
    if ($chunk.Length -gt 0) {
      if ($TimeStamp) {
        foreach ($c in $chunk.ToCharArray()) {
          if ($c -eq "`n" -or $c -eq "`r") {
            if ($lineBuf.Length -gt 0) {
              $ts = ('[+{0,8:N3}s] ' -f $clock.Elapsed.TotalSeconds)
              [Console]::Write($ts + $lineBuf.ToString() + "`r`n")
              $sw.Write($ts + $lineBuf.ToString() + "`n")
              [void]$lineBuf.Clear()
            }
          } else { [void]$lineBuf.Append($c) }
        }
      } else {
        [Console]::Write($chunk)
        $sw.Write($chunk)
      }
    }

    if (-not $NoInput -and $canInput) {
      try {
        while ([Console]::KeyAvailable) {
          $k = [Console]::ReadKey($true)

          if ($k.KeyChar -eq [char]0x1D) { $quit = $true; break }   # Ctrl+]

          switch ($k.Key) {
            'Enter'     { $sp.Write("`r");  if ($Echo) { [Console]::Write("`r`n") } }
            'Backspace' { $sp.Write([string][char]8); if ($Echo) { [Console]::Write("`b `b") } }
            'Escape'    { $sp.Write([string][char]27) }
            'UpArrow'   { $sp.Write("`e[A"); if ($Echo) { [Console]::Write('<up>') } }
            'DownArrow' { $sp.Write("`e[B"); if ($Echo) { [Console]::Write('<down>') } }
            'LeftArrow' { $sp.Write("`e[D") }
            'RightArrow'{ $sp.Write("`e[C") }
            'Tab'       { $sp.Write([string][char]9); if ($Echo) { [Console]::Write("`t") } }
            default {
              if ($k.KeyChar -ne [char]0) {
                $sp.Write([string]$k.KeyChar)
                if ($Echo) { [Console]::Write($k.KeyChar) }
              }
            }
          }
        }
      } catch [System.InvalidOperationException] { $canInput = $false }
    }

    Start-Sleep -Milliseconds 12
  }
} finally {
  if ($lineBuf.Length -gt 0) {
    [Console]::Write($lineBuf.ToString() + "`r`n")
    $sw.Write($lineBuf.ToString() + "`n")
  }
  $sw.Flush(); $sw.Close()
  if ($sp.IsOpen) { $sp.Close() }
  if ($ctrlCAsInput) { try { [Console]::TreatControlCAsInput = $false } catch { } }
  Write-Host ''
  Write-Host ("串口已关闭，日志: {0}" -f $Log) -ForegroundColor DarkGray
  $sp.Dispose()
}
