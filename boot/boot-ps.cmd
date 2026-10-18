setenv bootargs console=ttyPS0,115200 root=/dev/mmcblk0p2 rw rootwait rootfstype=ext4
echo "booting Arch Linux ARM: root=/dev/mmcblk0p2"
load mmc 0:1 0x2000000 zImage
load mmc 0:1 0x1000000 system.dtb
bootz 0x2000000 - 0x1000000
