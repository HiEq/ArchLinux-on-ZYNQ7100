BOOT 分区
=========

BOOT.BIN            FSBL + U-Boot，不含比特流
zImage              Linux 6.18.10-xilinx，无内嵌 initramfs
system.dtb          设备树
boot.scr            启动脚本，由 boot-ps.cmd 编译
boot-ps.cmd         启动脚本源文本
boot-petalinux.scr  PetaLinux 原版脚本，备查，不执行
System.map-*        内核符号表
config-*            内核配置

分区：p1 BOOT(FAT32) / p2 ARCH(ext4) / p3 SHARE(FAT32)
串口控制台 ttyPS0 115200 8N1；登录 root / root。
