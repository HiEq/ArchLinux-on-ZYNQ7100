#!/bin/bash
# 修正：FAT32 不支持文件名里的 ':'（pacman 的 epoch 写法），改名后重建离线源数据库
set -e
W=/home/hieq/alarm
R=$W/rootfs

echo "== 1. 清理卡住的进程 =="
pkill -f build_images.sh 2>/dev/null || true
pkill -x mcopy 2>/dev/null || true
sleep 1
echo "  剩余: $(pgrep -c -f build_images.sh 2>/dev/null || echo 0)"

echo "== 2. 改名（: -> .） =="
cd "$W/repo-stage"
n=0
for f in *; do
  case "$f" in
    *:*) new=$(echo "$f" | tr ':' '.'); mv -f "$f" "$new"; echo "  $f  ->  $new"; n=$((n+1));;
  esac
done
echo "  共改名 $n 个，共 $(ls | wc -l) 个包"

echo "== 3. 重建离线源数据库 =="
cp /usr/bin/qemu-arm-static "$R/usr/bin/"
for d in proc sys dev; do mountpoint -q "$R/$d" && umount -R "$R/$d" || true; done
mount --bind /proc "$R/proc"; mount --bind /sys "$R/sys"; mount --bind /dev "$R/dev"
rm -rf "$R/tmp/repogen"; mkdir -p "$R/tmp/repogen"
cp "$W/repo-stage/"*.pkg.tar.* "$R/tmp/repogen/"
chroot "$R" /bin/bash -c "cd /tmp/repogen && rm -f offline.db* online.db* && repo-add -q offline.db.tar.gz *.pkg.tar.* >/dev/null 2>&1 && echo '  repo-add ok' && ls -l offline.db.tar.gz"
cp -f "$R/tmp/repogen/offline.db.tar.gz" "$W/repo-stage/"
rm -rf "$R/tmp/repogen"
for d in proc sys dev; do mountpoint -q "$R/$d" && umount -R "$R/$d" || true; done
rm -f "$R/usr/bin/qemu-arm-static"

echo "== 4. 结果 =="
ls -l "$W/repo-stage/offline.db.tar.gz"
echo "  包数: $(ls "$W/repo-stage/"*.pkg.tar.* | wc -l)"
echo "  非法文件名: $(ls "$W/repo-stage" | grep -cE '[:"*?<>|]' || true)"
