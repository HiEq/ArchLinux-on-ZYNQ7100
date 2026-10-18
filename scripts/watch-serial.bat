@echo off
rem ---------------------------------------------------------------------------
rem  Serial console monitor: receive output + forward keyboard, log to ..\logs
rem  Usage:
rem    watch-serial.bat                  COM3 115200
rem    watch-serial.bat COM5             other port
rem    watch-serial.bat -Port COM5 -Baud 921600
rem    watch-serial.bat -TimeStamp       prefix each line with [+seconds]
rem    watch-serial.bat -NoInput         receive only
rem    watch-serial.bat -Log D:\x.log    custom log file
rem  Keys:  Ctrl+C is sent to the board (0x03);  Ctrl+] quits this program.
rem ---------------------------------------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serial-monitor.ps1" %*
if errorlevel 1 pause
