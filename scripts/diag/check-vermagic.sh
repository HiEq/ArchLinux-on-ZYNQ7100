#!/bin/bash
R=/home/hieq/alarm/rootfs
k=$(find $R/lib/modules -name '*.ko' | head -1)
echo "样例模块: ${k#$R}"
modinfo -F vermagic "$k"
echo
echo "各模块 vermagic 统计:"
find $R/lib/modules -name '*.ko' -exec modinfo -F vermagic {} \; 2>/dev/null | sort | uniq -c
echo
echo "内核模块目录: $(ls $R/lib/modules)"
echo "内核 System.map/配置在 boot 分区，版本: $(grep -m1 '^VERSION' /home/hieq/alarm/kbuild/Makefile) $(grep -m1 '^PATCHLEVEL' /home/hieq/alarm/kbuild/Makefile) (CONFIG_LOCALVERSION=$(grep '^CONFIG_LOCALVERSION=' /home/hieq/alarm/kbuild/.config))"
