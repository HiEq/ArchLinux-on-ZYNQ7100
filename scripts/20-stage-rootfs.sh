#!/bin/bash
# Arch Linux ARM rootfs 落地配置（在 WSL 里对 staging 目录操作）
set -e
R=/home/hieq/alarm/rootfs
IMG=${PLNX_IMAGES:-$HOME/xilinx/petalinux-zynq7100/images/linux}
WS=${PLNX_WS:-$HOME/xilinx/petalinux-zynq7100/build/tmp/work-shared/zynq-generic-7z100}
KREL=6.18.10-xilinx-g4f7afe14f724

echo "== 1. 删除 ALARM 自带内核/模块 =="
rm -rf "$R"/boot/* "$R"/lib/modules/*

echo "== 2. 放入本项目内核模块 ($KREL) =="
tar -xzf "$IMG/rootfs.tar.gz" -C "$R" "./lib/modules/$KREL" 2>/dev/null || \
  tar -xzf "$IMG/rootfs.tar.gz" -C "$R" --wildcards "lib/modules/$KREL/*" 2>/dev/null || \
  tar -xzf "$IMG/rootfs.tar.gz" -C "$R" --wildcards "*/lib/modules/$KREL/*"
ls "$R/lib/modules/"
echo "  模块数: $(find "$R/lib/modules/$KREL" -name '*.ko' | wc -l)"

echo "== 3. fstab =="
cat > "$R/etc/fstab" <<'EOF'
# <file system>       <dir>        <type>  <options>                       <dump> <pass>
/dev/mmcblk0p1        /boot        vfat    defaults,noatime,umask=022      0      2
/dev/mmcblk0p2        /            ext4    defaults,noatime                0      1
/dev/mmcblk0p3        /mnt/share   vfat    defaults,noatime,umask=000      0      0
EOF
mkdir -p "$R/mnt/share"

echo "== 4. hostname / hosts =="
echo "zynq7100" > "$R/etc/hostname"
cat > "$R/etc/hosts" <<'EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   zynq7100.localdomain zynq7100
EOF

echo "== 5. 串口控制台 getty (ttyPS0) =="
mkdir -p "$R/etc/systemd/system/getty.target.wants"
ln -sf /usr/lib/systemd/system/serial-getty@.service \
       "$R/etc/systemd/system/getty.target.wants/serial-getty@ttyPS0.service"
ls -l "$R/etc/systemd/system/getty.target.wants/"

echo "== 6. 屏蔽与网络相关的等待（板上无网口） =="
for u in systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service; do
  ln -sf /dev/null "$R/etc/systemd/system/$u"
done
rm -f "$R/etc/systemd/system/dbus-org.freedesktop.network1.service"
rm -f "$R/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service"
ls -l "$R/etc/systemd/system/" | grep -E 'networkd|wait-online' || true

echo "== 7. 时区与 locale =="
ln -sf /usr/share/zoneinfo/Asia/Shanghai "$R/etc/localtime"
echo "en_US.UTF-8 UTF-8" > "$R/etc/locale.gen"
echo "zh_CN.UTF-8 UTF-8" >> "$R/etc/locale.gen"
echo "LANG=en_US.UTF-8" > "$R/etc/locale.conf"

echo "== 8. pacman：离线本地源 + 关闭网络镜像 =="
printf 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxarm/$arch/$repo\n' > "$R/etc/pacman.d/mirrorlist"
python3 - "$R/etc/pacman.conf" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
if '[offline]' not in t:
    t = t.replace('[options]', '[options]', 1)
    t = t.rstrip('\n') + '''

[offline]
SigLevel = Optional TrustAll
Server = file:///mnt/share/repo
'''
open(p, 'w').write(t)
PY
tail -8 "$R/etc/pacman.conf"

echo "== 9. qemu-user-static =="
cp /usr/bin/qemu-arm-static "$R/usr/bin/"

echo "== 10. 内核参考文件（System.map / config） =="
B=/mnt/c/Users/wwwmt/Desktop/LINUX-FPGA/boot
cp "$WS/kernel-build-artifacts/System.map-$KREL" "$B/System.map-$KREL"
cp /home/hieq/alarm/kbuild/.config "$B/config-$KREL"
ls -l "$B" | tail -4

echo "== 完成，rootfs 大小 =="
du -sh "$R"
