#!/bin/bash
# 检查设备树关键节点
W=/home/hieq/alarm
mcopy -o -i $W/p1.img ::/system.dtb /tmp/system.dtb 2>/dev/null
echo "=== model / compatible ==="
dtc -I dtb -O dts /tmp/system.dtb 2>/dev/null | grep -E '^\s*(model|compatible) =' | head -6
echo
echo "=== chosen ==="
dtc -I dtb -O dts /tmp/system.dtb 2>/dev/null | sed -n '/chosen {/,/};/p' | head -12
echo
echo "=== aliases ==="
dtc -I dtb -O dts /tmp/system.dtb 2>/dev/null | sed -n '/aliases {/,/};/p' | head -20
echo
echo "=== 串口节点 ==="
dtc -I dtb -O dts /tmp/system.dtb 2>/dev/null | grep -B2 -A6 'xlnx,xuartps' | head -30
echo
echo "=== SD 控制器 ==="
dtc -I dtb -O dts /tmp/system.dtb 2>/dev/null | grep -A8 'xlnx,zynq-sdhci' | head -30
