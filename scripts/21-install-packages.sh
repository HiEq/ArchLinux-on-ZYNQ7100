#!/bin/bash
# 在 qemu chroot 里装包：绕开 pacman 7 的 Landlock 下载沙箱
#   1) 用 host curl 手动取数据库   2) chroot 里用 pacman -Sp 列出 URL
#   3) host curl 下载到 pacman 缓存  4) chroot 里 pacman -S 从缓存安装
set -e
R=/home/hieq/alarm/rootfs
TUNA=https://mirrors.tuna.tsinghua.edu.cn/archlinuxarm/armv7h
PKGS="base-devel python python-pip git vim nano htop tmux rsync curl wget less man-db tree unzip zip usbutils dtc lsof bc time strace dosfstools mtools bash-completion"

echo "== 1. 取仓库数据库 =="
mkdir -p "$R/var/lib/pacman/sync" "$R/var/cache/pacman/pkg"
for r in core extra alarm aur; do
  curl -sL -o "$R/var/lib/pacman/sync/$r.db" "$TUNA/$r/$r.db"
done
ls -l "$R/var/lib/pacman/sync/"

echo "== 2. chroot 里解析依赖，列出下载 URL =="
for d in proc sys dev; do mountpoint -q "$R/$d" && umount -R "$R/$d" || true; done
mount --bind /proc "$R/proc"; mount --bind /sys "$R/sys"; mount --bind /dev "$R/dev"
chroot "$R" /bin/bash -c "pacman --config /etc/pacman-offline.conf -Sp --needed --print-format '%l' --noconfirm $PKGS" \
  > "$R/tmp/pkgurls.txt" 2> "$R/tmp/pkgurls.err" || true
echo "  需要下载: $(wc -l < "$R/tmp/pkgurls.txt") 个包"
head -3 "$R/tmp/pkgurls.txt"
head -5 "$R/tmp/pkgurls.err" || true

echo "== 3. 下载到 pacman 缓存 =="
n=0
while read -r u; do
  [ -z "$u" ] && continue
  f=$(basename "$u")
  if [ ! -s "$R/var/cache/pacman/pkg/$f" ]; then
    curl -sL -o "$R/var/cache/pacman/pkg/$f" "$u" &
    n=$((n+1))
  fi
done < "$R/tmp/pkgurls.txt"
wait
echo "  已下载/缓存: $(ls "$R/var/cache/pacman/pkg"/*.pkg.tar.zst 2>/dev/null | wc -l) 个包，大小 $(du -sh "$R/var/cache/pacman/pkg" | cut -f1)"

echo "== 4. chroot 安装（$(date +%T)） =="
chroot "$R" /bin/bash -c "
set -e
pacman --config /etc/pacman-offline.conf -S --needed --noconfirm $PKGS
echo '-- 移除自带内核包 --'
pacman --config /etc/pacman-offline.conf -Rdd --noconfirm linux-armv7 || true
echo '-- locale-gen --'
locale-gen
echo '-- depmod --'
depmod -a 6.18.10-xilinx-g4f7afe14f724 && echo '   depmod ok'
echo '-- 缓存包数 --'
ls /var/cache/pacman/pkg/*.pkg.tar.zst | wc -l
"
echo "== 完成（$(date +%T)） =="
for d in proc sys dev; do mountpoint -q "$R/$d" && umount -R "$R/$d" || true; done
du -sh "$R"
