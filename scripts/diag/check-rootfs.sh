#!/bin/bash
R=/home/hieq/alarm/rootfs
echo "=== /boot 内容（应为空，内核在 p1 上） ==="
ls -la $R/boot/
echo "=== /dev 内容 ==="
ls -A $R/dev/ | head
echo "=== 关键文件 ==="
for f in etc/fstab etc/hostname etc/locale.conf etc/localtime etc/pacman.conf etc/resolv.conf usr/bin/qemu-arm-static; do
  printf '  %-28s %s\n' "$f" "$(test -e $R/$f && echo 存在 || echo 不存在)"
done
echo "  机器码: $(wc -c < $R/etc/machine-id) 字节（应为 0）"
echo "=== systemd 单元 ==="
ls -l $R/etc/systemd/system/getty.target.wants/ 2>/dev/null | tail -2
ls -l $R/etc/systemd/system/ | grep -E 'networkd' 
echo "=== 模块与内核版本 ==="
ls $R/lib/modules/
echo "  vermagic: $(modinfo -F vermagic $R/lib/modules/*/kernel/drivers/mmc/host/*.ko 2>/dev/null | head -1)"
echo "=== 已装包数 / 大小 ==="
echo "  local db: $(ls $R/var/lib/pacman/local | wc -l)   rootfs: $(du -sh $R | cut -f1)"
echo "=== 重要可执行 ==="
for b in usr/bin/pacman usr/bin/repo-add usr/bin/gcc usr/bin/python usr/bin/git bin/bash usr/bin/dd usr/sbin/mkfs.vfat usr/bin/resize2fs; do
  printf '  %-24s %s\n' "$b" "$(test -x $R/$b && echo ok || echo '缺失')"
done
