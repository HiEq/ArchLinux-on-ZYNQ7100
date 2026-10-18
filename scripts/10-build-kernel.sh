#!/bin/bash
# 重新构建内核：去掉内嵌 initramfs（原镜像把 PetaLinux rootfs 内嵌在 zImage 里）
# 只改 CONFIG_INITRAMFS_SOURCE / LOCALVERSION，其余沿用 PetaLinux 生成的 .config
set -e

source /home/hieq/petalinux_sdk/environment-setup-cortexa9t2hf-neon-amd-linux-gnueabi
WS=${PLNX_WS:-$HOME/xilinx/petalinux-zynq7100/build/tmp/work-shared/zynq-generic-7z100}
SRC=$WS/kernel-source
ART=$WS/kernel-build-artifacts
OUT=/home/hieq/alarm/kbuild

echo "cores: $(nproc)"
echo "cross: $CROSS_COMPILE"
echo "source: $SRC"

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$ART/.config" "$OUT/.config"

"$SRC/scripts/config" --file "$OUT/.config" \
  --set-str INITRAMFS_SOURCE "" \
  --set-str LOCALVERSION "-xilinx-g4f7afe14f724" \
  --disable LOCALVERSION_AUTO

grep -E '^CONFIG_INITRAMFS_SOURCE|^CONFIG_LOCALVERSION' "$OUT/.config"

make -C "$SRC" O="$OUT" ARCH=arm olddefconfig > "$OUT/olddefconfig.log" 2>&1
tail -3 "$OUT/olddefconfig.log"

echo "=== 开始编译 Image（$(date +%T)） ==="
make -C "$SRC" O="$OUT" ARCH=arm -j"$(nproc)" Image > "$OUT/build.log" 2>&1
echo "=== 编译结束（$(date +%T)） ==="
ls -l "$OUT/arch/arm/boot/Image"
grep -E 'Kernel: arch/arm/boot/Image is ready|Error|error:' "$OUT/build.log" | tail -5
