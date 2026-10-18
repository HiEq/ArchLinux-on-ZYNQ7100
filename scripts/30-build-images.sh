#!/bin/bash
# 生成 Arch 单系统的三个分区镜像与 MBR
#   p1 BOOT(512 MiB FAT32) / p2 ARCH(16 GiB ext4) / p3 SHARE(FAT32)
# 默认按 116.58 GB 卡（244,482,048 扇区）布局，p3 取剩余空间；换卡改 CARD_SECTORS。
# 若指定 P3_SIZE，则 p3 使用固定扇区数（Release 镜像即固定为 8 GiB）。
set -e

W=${W:-/home/hieq/alarm}
B=${B:-$PWD/boot}
CARD_SECTORS=${CARD_SECTORS:-244482048}

P1_START=2048;      P1_SIZE=1048576
P2_START=1050624;   P2_SIZE=33554432
P3_START=34605056
P3_SIZE=${P3_SIZE:-$((CARD_SECTORS - P3_START))}

echo "== 布局 =="
echo "  p1 ${P1_START}+${P1_SIZE}   512 MiB FAT32 BOOT"
echo "  p2 ${P2_START}+${P2_SIZE}   16 GiB ext4 ARCH"
echo "  p3 ${P3_START}+${P3_SIZE}   FAT32 SHARE"

echo "== MBR =="
rm -f "$W/layout.img" "$W/mbr.img"
truncate -s $(((P3_START + P3_SIZE) * 512)) "$W/layout.img"
sfdisk "$W/layout.img" >/dev/null <<EOF
label: dos
label-id: 0x5A4C5053
unit: sectors
start=$P1_START, size=$P1_SIZE, type=c, bootable
start=$P2_START, size=$P2_SIZE, type=83
start=$P3_START, size=$P3_SIZE, type=c
EOF
sfdisk -d "$W/layout.img"
dd if="$W/layout.img" of="$W/mbr.img" bs=1M count=1 status=none
rm -f "$W/layout.img"

echo "== p1 BOOT =="
rm -f "$W/p1.img"; truncate -s $((P1_SIZE * 512)) "$W/p1.img"
mkfs.vfat -F 32 -n BOOT "$W/p1.img" >/dev/null
mcopy -o -i "$W/p1.img" "$B/BOOT.BIN"   ::/BOOT.BIN
mcopy -o -i "$W/p1.img" "$B/zImage"     ::/zImage
mcopy -o -i "$W/p1.img" "$B/system.dtb" ::/system.dtb
mcopy -o -i "$W/p1.img" "$B/boot-ps.cmd" ::/boot-ps.cmd
mcopy -o -i "$W/p1.img" "$B/boot-petalinux.scr" ::/boot-petalinux.scr
mcopy -o -i "$W/p1.img" "$B/System.map-6.18.10-xilinx-g4f7afe14f724" ::/
mcopy -o -i "$W/p1.img" "$B/config-6.18.10-xilinx-g4f7afe14f724"     ::/
mkimage -A arm -T script -C none -n "Arch Linux ARM boot" -d "$B/boot-ps.cmd" "$W/boot.scr" >/dev/null
mcopy -o -i "$W/p1.img" "$W/boot.scr" ::/boot.scr
rm -f "$W/boot.scr"
mcopy -o -i "$W/p1.img" "$B/p1-README.TXT" ::/README.TXT
mdir -i "$W/p1.img" ::/

echo "== p2 ARCH =="
cd "$W"; rm -f p2.img
truncate -s $((P2_SIZE * 512)) p2.img
mke2fs -t ext4 -F -L ARCH -m 1 -d "$W/rootfs" p2.img >/tmp/mke2fs.log 2>&1
tail -1 /tmp/mke2fs.log
e2fsck -fn p2.img 2>&1 | grep -E 'ARCH:' || true

echo "== p3 SHARE =="
rm -f "$W/p3.img"; truncate -s $((P3_SIZE * 512)) "$W/p3.img"
mkfs.vfat -F 32 -s 64 -n SHARE "$W/p3.img" >/dev/null
mmd -i "$W/p3.img" ::/repo 2>/dev/null || true
for f in "$W/share/repo"/*; do [ -f "$f" ] && mcopy -o -i "$W/p3.img" "$f" ::/repo/; done
mcopy -o -i "$W/p3.img" "$B/p3-README.TXT" ::/README.TXT
mdir -i "$W/p3.img" ::/ | head -6

echo "== 自检 =="
fsck.vfat -n "$W/p1.img" | tail -1
fsck.vfat -n "$W/p3.img" | tail -1
ls -l --block-size=M "$W/mbr.img" "$W/p1.img" "$W/p2.img" "$W/p3.img"
