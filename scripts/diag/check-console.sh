#!/bin/bash
# 检查 rootfs 的登录横幅/控制台相关内容
R=/home/hieq/alarm/rootfs
echo "=== rootfs: $R ==="
echo "--- /etc/os-release ---"
cat "$R/etc/os-release"
echo "--- /etc/issue（cat -A，看行尾）---"
cat -A "$R/etc/issue"
echo "--- /etc/issue 相关文件 ---"
ls -l "$R/etc/issue"* 2>/dev/null
echo "--- /etc/motd ---"
if [ -f "$R/etc/motd" ]; then wc -c "$R/etc/motd"; else echo "(无)"; fi
echo "--- agetty ---"
ls -l "$R/sbin/agetty" "$R/usr/bin/agetty" 2>/dev/null
echo "--- plymouth ---"
ls "$R/usr/bin/plymouth" 2>/dev/null || echo "(未安装，无图形启动画面)"
echo "--- pacman ---"
ls "$R/usr/bin/pacman" 2>/dev/null
echo "--- 已装包数 ---"
ls "$R/var/lib/pacman/local" 2>/dev/null | wc -l
echo "--- 控制台相关内核参数文件 ---"
ls -l "$R/etc/systemd/system/serial-getty@ttyPS0.service" 2>/dev/null
echo "--- systemd 版本 ---"
chroot "$R" /usr/bin/pacman -Q systemd 2>/dev/null || grep -m1 . "$R/usr/lib/systemd/systemd" >/dev/null 2>&1 && ls "$R/usr/lib/systemd/systemd"
