#!/bin/bash
# 把 rootfs 里实际生效的配置文件抽到 LINUX-FPGA/rootfs-overlay/etc/
set -e
D=/mnt/c/Users/wwwmt/Desktop/LINUX-FPGA/rootfs-overlay/etc
R=/home/hieq/alarm/rootfs
mkdir -p "$D"
for f in fstab hostname hosts locale.conf locale.gen pacman.conf; do
  cp -f "$R/etc/$f" "$D/$f"
done
ls -l "$D"
echo "--- localtime ---"
ls -l "$R/etc/localtime"
echo "--- vconsole.conf ---"
ls -l "$R/etc/vconsole.conf" 2>/dev/null || echo "(无)"
echo "--- machine-id 字节数 ---"
wc -c "$R/etc/machine-id"
