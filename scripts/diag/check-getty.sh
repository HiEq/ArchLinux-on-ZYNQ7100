#!/bin/bash
R=/home/hieq/alarm/rootfs
echo "--- /etc/systemd/system 下的单元链接 ---"
ls -l "$R/etc/systemd/system/" 2>&1
echo "--- 目标文件是否存在 ---"
ls -l "$R/usr/lib/systemd/system/serial-getty@.service" 2>&1
echo "--- getty.target.wants / multi-user.target.wants ---"
ls -l "$R/etc/systemd/system/getty.target.wants/" "$R/etc/systemd/system/multi-user.target.wants/" 2>&1
echo "--- 是否有 mylogin/console 相关 ---"
ls "$R/etc/systemd/system/"*.service 2>&1
echo "--- default.target ---"
ls -l "$R/etc/systemd/system/default.target" "$R/etc/systemd/system/multi-user.target" 2>&1
