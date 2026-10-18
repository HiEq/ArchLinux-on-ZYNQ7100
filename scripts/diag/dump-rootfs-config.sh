#!/bin/bash
# 输出 rootfs 里的关键配置文件内容，用于整理成 LINUX-FPGA 里的 overlay
R=/home/hieq/alarm/rootfs
for f in etc/fstab etc/hostname etc/hosts etc/locale.conf etc/pacman.conf etc/vconsole.conf; do
  echo "=== $f ==="
  cat "$R/$f" 2>/dev/null
  echo
done
echo "=== locale.gen (非注释行) ==="
grep -vE '^\s*#|^\s*$' "$R/etc/locale.gen" 2>/dev/null
echo
echo "=== systemd 单元符号链接 ==="
ls -l "$R/etc/systemd/system/"*.service "$R/etc/systemd/system/"*.socket "$R/etc/systemd/system/multi-user.target.wants/" 2>/dev/null
echo
echo "=== 内核模块目录 ==="
ls "$R/lib/modules/6.18.10-xilinx-g4f7afe14f724/" 2>/dev/null
echo "updates/: $(ls "$R/lib/modules/6.18.10-xilinx-g4f7afe14f724/updates/" 2>/dev/null | wc -l) 个"
