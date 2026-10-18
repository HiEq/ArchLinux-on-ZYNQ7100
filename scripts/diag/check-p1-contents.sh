#!/bin/bash
# 核对 p1 上的启动文件内容
W=/home/hieq/alarm
echo "=== p1 文件树 ==="
mdir -i $W/p1.img ::/
echo
echo "=== uEnv.txt（注意必须是 LF 换行） ==="
mtype -i $W/p1.img ::/uEnv.txt | cat -A | sed 's/\$$/<LF>/'
echo
echo "=== boot.scr 提取出的脚本 ==="
mcopy -o -i $W/p1.img ::/boot.scr /tmp/boot.scr
mkimage -l /tmp/boot.scr 2>/dev/null | grep -E 'Image Name|Created|Data Size|Type|Compression|Load Address'
dd if=/tmp/boot.scr bs=1 skip=64 status=none > /tmp/boot.scr.txt
head -60 /tmp/boot.scr.txt
echo
echo "=== system.dtb 头部信息 ==="
mcopy -o -i $W/p1.img ::/system.dtb /tmp/system.dtb
dtc -I dtb -O dts /tmp/system.dtb 2>/dev/null | grep -E 'model|compatible|chosen|stdout-path|bootargs' | head -12
