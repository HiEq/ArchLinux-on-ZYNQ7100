#!/bin/bash
# 把 WSL 里准备好的整套文件打包缓存到 Windows 侧 LINUX-FPGA/cache/
set -e
W=/home/hieq/alarm
C=/mnt/c/Users/wwwmt/Desktop/LINUX-FPGA/cache
mkdir -p "$C"

pack() {                       # pack <输出名> <工作目录> <要打包的路径...>
  local out="$1"; shift
  local dir="$1"; shift
  echo "-> $out"
  tar -C "$dir" -cf - "$@" | xz -T0 -3 -c > "$C/$out"
  ls -l --block-size=M "$C/$out" | awk '{print "   "$5"  "$9}'
}

echo "== 1/5  rootfs（231 个包，已装好内核模块）=="
pack rootfs.tar.xz "$W" rootfs

echo "== 2/5  离线 pacman 源 =="
pack repo.tar.xz "$W" repo-stage

echo "== 3/5  三个分区镜像 + MBR（保留稀疏）=="
pack images.tar.xz "$W" --sparse mbr.img p1.img p2.img p3.img

echo "== 4/5  内核构建产物 =="
pack kernel.tar.xz "$W" kbuild/.config kbuild/System.map kbuild/Module.symvers \
     kbuild/arch/arm/boot/zImage kbuild/arch/arm/boot/Image \
     kbuild/include/config/auto.conf 2>/dev/null || \
pack kernel.tar.xz "$W" kbuild/.config kbuild/System.map kbuild/arch/arm/boot/zImage

echo "== 5/5  ALARM 原始 tarball =="
cp -f "$W/ArchLinuxARM-armv7-latest.tar.gz" "$C/"
ls -l --block-size=M "$C/ArchLinuxARM-armv7-latest.tar.gz" | awk '{print "   "$5"  "$9}'
md5sum "$W/ArchLinuxARM-armv7-latest.tar.gz" | sed 's/^/   md5 /'

echo
echo "== 生成校验和 =="
cd "$C"
sha256sum *.tar.xz ArchLinuxARM-armv7-latest.tar.gz > SHA256SUMS.txt
cat SHA256SUMS.txt
echo
echo "== 缓存目录 =="
ls -l --block-size=M "$C"
echo "总计: $(du -sh "$C" | cut -f1)"
