# ArchLinux-on-ZYNQ7100

在 OS-ZYNQ7100 Lite（XC7Z100-FFG900）上以纯 PS 方式运行 Arch Linux ARM（armv7h）：
不使用 PL、不加载比特流，根文件系统位于 TF 卡，离线软件源位于卡内 FAT32 分区。

## 1. 可用接口

底板 OS-ZYNQ7100_Dock_Lite 无以太网口，其余接口或无线缆、或未出料。

| 接口 | 状态 | 用途 |
|---|---|---|
| JTAG | 可用 | 调试、烧写 |
| UART0（MIO14/15 → CH340） | 可用 | 唯一控制台，115200 8N1 |
| TF 卡槽（SD0，MIO40~45） | 可用 | 启动、根文件系统、文件交换 |
| 以太网（RTL8211F + PS GEM） | 未引出 | 不可用 |
| USB Host | 未引出 | 不可用 |
| HDMI | PL 侧 RGB2DVI | 纯 PS 不可用 |

无网络、无显示、无 USB 存储，软件经 TF 卡离线带入。

## 2. 硬件

| 项 | 器件 | 说明 |
|---|---|---|
| SoC | XC7Z100-FFG900-2 | 双核 Cortex-A9 @ 666.67 MHz |
| PS DDR3 | MT41K256M16 ×2 | 1 GB，32-bit，1066 MT/s |
| PL DDR3 | MT41K256M16 ×2 | 1 GB，仅 PL |
| QSPI | W25Q256FV ×2 | 64 MB |
| eMMC | KLM8G1GETF-B041 | 8 GB，纯 PS 不可用，见 `docs/emmc.md` |
| SD/TF | SD0，MIO40~45 | 底板卡槽 |
| UART0 | MIO14/15 | CH340 |

## 3. 启动链

```
BOOT.BIN（FSBL + U-Boot，不含比特流）
  → p1 FAT32 BOOT：boot.scr → zImage + system.dtb
  → p2 ext4 ARCH：root=/dev/mmcblk0p2 rootwait rootfstype=ext4
```

- FSBL 必需，DDR3/MIO/PLL 初始化在 `ps7_init` 内。
- `boot.scr` 由 `boot/boot-ps.cmd` 经 `mkimage -C none` 编译。
- PetaLinux 原版脚本保留为 `boot-petalinux.scr`，不参与启动：其 `if test -n $uenvcmd`
  在变量含空格时解析失败，实测落入 U-Boot 命令行。
- 控制台仅串口，`serial-getty@ttyPS0.service` 已启用。

## 4. 启动件

`boot/` 目录：

| 文件 | 字节 | 说明 |
|---|---|---|
| `BOOT.BIN` | 1,166,324 | FSBL + U-Boot + `system.dtb`，无比特流；md5 `4D1FFDE59B6BA0E2034AD3F8216BFC2A` |
| `zImage` | 5,168,448 | Linux 6.18.10-xilinx，无内嵌 initramfs |
| `system.dtb` | 18,547 | 设备树 |
| `boot.scr` | 301 | 启动脚本 |
| `boot-ps.cmd` | 229 | `boot.scr` 源文本 |
| `boot-petalinux.scr` | 3,830 | 原版脚本，备查 |
| `System.map-6.18.10-xilinx-g4f7afe14f724` | 2,202,005 | 符号表 |
| `config-6.18.10-xilinx-g4f7afe14f724` | 167,193 | 内核配置 |

内核由同一份 `.config` 重编：置 `CONFIG_INITRAMFS_SOURCE=""`（原 `zImage` 43 MB 内嵌
93 MB PetaLinux rootfs，无法引导 ext4 根），`CONFIG_LOCALVERSION` 固定为
`-xilinx-g4f7afe14f724`、关闭 `LOCALVERSION_AUTO`，使 172 个既有 `.ko` 的 vermagic
`6.18.10-xilinx-g4f7afe14f724 SMP preempt mod_unload modversions ARMv7 p2v8` 保持匹配。

## 5. 根文件系统

来源 Arch Linux ARM armv7：`ArchLinuxARM-armv7-latest.tar.gz`，770,429,322 B，
md5 `04b2f42c710748480f2dcf5115badc43`。

| 项 | 值 |
|---|---|
| 软件包 | 231 |
| 文件数 | 59,646 |
| 占用 | 2.3 GB |
| 内核模块 | 172 个 `.ko` |
| 主机名 | `zynq7100` |
| 时区 / locale | Asia/Shanghai；en_US.UTF-8、zh_CN.UTF-8 |
| 屏蔽单元 | `systemd-networkd{,-wait-online}.{service,socket}` |

已装软件包含 gcc 16.1.1、gdb、python 3.14、git、vim、nano、htop、tmux、rsync、curl、
wget、less、man-db、tree、unzip、zip、usbutils、dtc、lsof、bc、time、strace、dosfstools、
mtools、bash-completion。

`rootfs-overlay/` 保存生效的配置文件与 `apply.sh`。登录横幅为 Arch logo 加
`Arch Linux ARM <内核版本> (ttyPS0)`，ALARM 原文件见 `rootfs-overlay/issue.alarm-default`。

## 6. 离线软件源

板端 pacman 仅启用卡内本地源：

```
[offline]
SigLevel = Optional TrustAll
Server   = file:///mnt/share/repo
```

含 71 个 `.pkg.tar.xz` 与 `offline.db.tar.gz`，约 127 MB。FAT32 不支持 `:`，
epoch 包名已改为 `.` 并据此重建数据库。pacman 7 的 Landlock 沙箱在本内核不可用
（`CONFIG_SECURITY_LANDLOCK` 未设置），`/etc/pacman.conf` 已置
`DisableSandboxFilesystem`、`DisableSandboxSyscalls`。

## 7. 分区布局

以 116.58 GB 卡（244,482,048 扇区）为例：

| 分区 | 起始扇区 | 扇区数 | 大小 | 文件系统 | 内容 |
|---|---|---|---|---|---|
| p1 | 2,048 | 1,048,576 | 512 MiB | FAT32 `BOOT` | 启动文件 |
| p2 | 1,050,624 | 33,554,432 | 16 GiB | ext4 `ARCH` | 根文件系统 |
| p3 | 34,605,056 | 209,876,992 | 约 100 GiB | FAT32 `SHARE` | 离线源、文件交换 |

换卡改 `scripts/30-build-images.sh` 的 `CARD_SECTORS`。p2/p3 按整分区生成，板上无需
`resize2fs`。MBR 磁盘标识固定为 `0x5A4C5053`。Release 中的镜像使用可移植尺寸
（p1 512 MiB、p2 16 GiB、p3 8 GiB），可直接写入不小于 25 GB 的卡。

## 8. 脚本

| 脚本 | 作用 |
|---|---|
| `scripts/10-build-kernel.sh` | 交叉编译内核 |
| `scripts/20-stage-rootfs.sh` | 解压 ALARM、替换模块、套用 overlay |
| `scripts/21-install-packages.sh` | chroot 内自离线源装包 |
| `scripts/22-finish-rootfs.sh` | getty、时区、locale、pacman 源、machine-id |
| `scripts/23-build-offline-repo.sh` | 修正 FAT32 非法文件名并重建数据库 |
| `scripts/30-build-images.sh` | 生成 `mbr.img` / `p1.img` / `p2.img` / `p3.img` |
| `scripts/31-make-manifest.py` | 生成非零区块清单与内容 sha256 |
| `scripts/40-write-card.ps1` | Windows 侧裸写 TF 卡并回读校验 |
| `scripts/90-make-cache.sh` | 打包整套文件到 `cache/` |
| `scripts/serial-monitor.ps1`、`watch-serial.bat` | 串口控制台 |
| `scripts/diag/` | 诊断与自检脚本 |

## 9. 目录

| 目录 | 内容 |
|---|---|
| `boot/` | 启动件与内核参考文件 |
| `rootfs-overlay/` | 配置覆盖层与 `apply.sh` |
| `scripts/` | 构建、写卡、串口脚本 |
| `docs/` | 过程与实测记录 |
| `cache/`、`logs/` | 本地生成，不纳入版本库 |

## 10. 写卡

`scripts/40-write-card.ps1` 先清零分区表使 Windows 释放已挂载卷，再按清单跳零写入，
最后逐区块回读校验。116.58 GB 卡实测：

| 镜像 | 写入量 | 写入速率 | 回读校验 |
|---|---|---|---|
| `mbr.img` | 1 MiB | — | 通过 |
| `p1.img` | 32 MiB | 17.3 MB/s | 通过 |
| `p2.img` | 2,249 MiB | 16.8 MB/s | 通过 |
| `p3.img` | 131 MiB | 19.1 MB/s | 整分区哈希不符，包文件 md5 一致 |

p3 为 FAT32，MBR 写入后 Windows 立即挂载并创建 `System Volume Information`，
故整分区哈希不符；以 `scripts/diag/card-check-p3.ps1` 核对包文件。

注意事项：对已挂载卷所在扇区的裸写会被拒绝（`ERROR_ACCESS_DENIED`），清零分区表后
`diskpart rescan` 可释放卷；`mountvol <盘符> /p` 会使卷进入已卸载未释放状态，写入返回
`设备未就绪`。写入过程中拔出卡会导致设备掉线，需重新插拔。

## 11. 上板

串口 115200 8N1，登录 `root`，密码 `root`（ALARM 默认，上板后应修改）。

```
mmc0: SDHCI controller on e0100000.mmc
mmcblk0: mmc0:0001 SD128 117 GiB  p1 p2 p3
EXT4-fs (mmcblk0p2): mounted filesystem ...
[  OK  ] Started Serial Getty on ttyPS0.
Arch Linux ARM 6.18.10-xilinx-g4f7afe14f724 (ttyPS0)
zynq7100 login:
```

离线源验证：`pacman -Sy` 仅同步 `offline`；`pacman -S dtc` 可安装。

## 12. 后续

- `BOOT.BIN` 写入 QSPI（64 MB），不使用 TF 卡；需确认底板启动模式跳线。
- 纯上游引导链：上游 `linux-xlnx`、标准 armv7 工具链、U-Boot SPL 替代 FSBL、
  `device-tree-xlnx` 从 `system.xsa` 重建设备树。

## 许可

MIT，见 `LICENSE`。
