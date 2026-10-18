#!/bin/bash
# 第二步：完成 chroot 安装 + 生成离线源 + 收尾清理
set -e
R=/home/hieq/alarm/rootfs
W=/home/hieq/alarm

echo "== 关闭 CheckSpace（chroot 里无法判定根挂载点） =="
sed -i 's/^CheckSpace/#CheckSpace/' "$R/etc/pacman-offline.conf"
grep -E 'CheckSpace|SigLevel|DownloadUser' "$R/etc/pacman-offline.conf"

for d in proc sys dev; do mountpoint -q "$R/$d" && umount -R "$R/$d" || true; done
mount --bind /proc "$R/proc"; mount --bind /sys "$R/sys"; mount --bind /dev "$R/dev"

chroot "$R" /bin/bash -c "
set -e
PKGS='base-devel python python-pip git vim nano htop tmux rsync curl wget less man-db tree unzip zip usbutils dtc lsof bc time strace dosfstools mtools bash-completion'
echo '-- 从缓存安装 --'
pacman --config /etc/pacman-offline.conf -S --needed --noconfirm \$PKGS
echo '-- 移除自带内核包 linux-armv7 --'
pacman --config /etc/pacman-offline.conf -Rdd --noconfirm linux-armv7 || true
echo '-- locale-gen --'
locale-gen
echo '-- depmod --'
depmod -a 6.18.10-xilinx-g4f7afe14f724 && echo '   depmod ok'
echo '-- 生成离线 pacman 源 --'
rm -rf /repo-stage && mkdir -p /repo-stage
cp /var/cache/pacman/pkg/*.pkg.tar.* /repo-stage/
cd /repo-stage
repo-add -q offline.db.tar.gz *.pkg.tar.* >/dev/null
rm -f offline.db online.db 2>/dev/null || true
ls -l /repo-stage | head -5
echo \"   repo 内包数: \$(ls /repo-stage/*.pkg.tar.* | wc -l)\"
"
echo
echo "== 收尾 =="
# 离线源搬到 host
rm -rf "$W/repo-stage"; mkdir -p "$W/repo-stage"
cp "$R/repo-stage/"* "$W/repo-stage/"
rm -rf "$R/repo-stage"

# pacman.conf 只留离线源
python3 - "$R/etc/pacman.conf" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p).read()
t = re.sub(r'\n\[(core|extra|alarm|aur)\][^\[]*', '\n', t)
t = re.sub(r'\n\[offline\][^\[]*', '\n', t)
t = t.rstrip('\n') + """

# 板上没有网络：只启用卡片上的离线本地源（/mnt/share/repo, 见 p3 分区）
# 若以后接上网络（例如 USB 网卡），把下面的注释去掉并填入镜像地址
#[core]
#Include = /etc/pacman.d/mirrorlist
#[extra]
#Include = /etc/pacman.d/mirrorlist
#[alarm]
#Include = /etc/pacman.d/mirrorlist

[offline]
SigLevel = Optional TrustAll
Server = file:///mnt/share/repo
"""
open(p, 'w').write(t)
PY
tail -6 "$R/etc/pacman.conf"

# resolv.conf 恢复成 systemd-resolved 的符号链接
rm -f "$R/etc/resolv.conf"
ln -sf /run/systemd/resolve/stub-resolv.conf "$R/etc/resolv.conf"

# 去掉 chroot 专用文件
rm -f "$R/etc/pacman-offline.conf" "$R/usr/bin/qemu-arm-static" "$R/tmp/pkgurls.txt" "$R/tmp/pkgurls.err"
: > "$R/etc/machine-id"
rm -rf "$R"/var/cache/pacman/pkg/*.sig "$R"/tmp/* "$R"/var/tmp/* 2>/dev/null || true
find "$R" -name '.wh.*' -delete 2>/dev/null || true

for d in proc sys dev; do mountpoint -q "$R/$d" && umount -R "$R/$d" || true; done

echo
echo "== 结果 =="
echo "  rootfs: $(du -sh "$R" | cut -f1)"
echo "  repo:   $(du -sh "$W/repo-stage" | cut -f1), $(ls "$W/repo-stage"/*.pkg.tar.* | wc -l) 个包"
echo "  内核模块: $(find "$R/lib/modules" -name '*.ko' | wc -l)"
echo "  已装包: $(chroot "$R" /bin/bash -c 'true' 2>/dev/null; ls "$R/var/lib/pacman/local" | wc -l)"
