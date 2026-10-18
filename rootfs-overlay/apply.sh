#!/bin/bash
# 把 rootfs-overlay/ 应用到目标 rootfs 目录（默认 /home/hieq/alarm/rootfs）
#   - 覆盖 etc/ 下的配置文件
#   - 建立 systemd 单元符号链接、时区、machine-id
# 需以 root 运行。
set -e

ROOT="${1:-/home/hieq/alarm/rootfs}"
HERE="$(cd "$(dirname "$0")" && pwd)"

[ -d "$ROOT/usr/lib/systemd" ] || { echo "不是 rootfs: $ROOT" >&2; exit 1; }

echo "== 复制 etc 配置 =="
cp -f "$HERE/etc/"* "$ROOT/etc/"
chmod 644 "$ROOT/etc/fstab" "$ROOT/etc/hostname" "$ROOT/etc/hosts" \
           "$ROOT/etc/locale.conf" "$ROOT/etc/locale.gen" "$ROOT/etc/pacman.conf" \
           "$ROOT/etc/issue" "$ROOT/etc/arch-logo"

echo "== 安装附加 systemd 单元 =="
if [ -d "$HERE/units" ]; then
  for u in "$HERE/units/"*.service; do
    [ -f "$u" ] || continue
    n=$(basename "$u")
    cp -f "$u" "$ROOT/etc/systemd/system/$n"
    chmod 644 "$ROOT/etc/systemd/system/$n"
    case "$n" in
      arch-logo.service)
        # 默认不启用：启动阶段的 logo 由用户按需开启
        #   systemctl enable arch-logo.service
        ;;
    esac
    echo "  $n"
  done
fi

echo "== 时区 =="
ln -sf /usr/share/zoneinfo/Asia/Shanghai "$ROOT/etc/localtime"

echo "== 串口控制台 =="
ln -sf /usr/lib/systemd/system/serial-getty@.service \
       "$ROOT/etc/systemd/system/serial-getty@ttyPS0.service"

echo "== 屏蔽网络等待（板上无网络设备） =="
for u in systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service; do
  ln -sf /dev/null "$ROOT/etc/systemd/system/$u"
done

echo "== machine-id 清空（首启由 systemd 生成） =="
: > "$ROOT/etc/machine-id"

echo "== 完成 =="
