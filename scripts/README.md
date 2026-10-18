# 脚本

默认工作目录 `/home/hieq/alarm`（WSL），rootfs 为 `/home/hieq/alarm/rootfs`，
可用环境变量 `W` 覆盖。`.ps1` 需保存为 UTF-8 with BOM，否则 Windows PowerShell 5.1
按 ANSI 解析中文会报错。

| 脚本 | 环境 | 作用 |
|---|---|---|
| `10-build-kernel.sh` | WSL | 交叉编译内核：同一份 `.config`，置空 `CONFIG_INITRAMFS_SOURCE`，固定 `CONFIG_LOCALVERSION` |
| `20-stage-rootfs.sh` | WSL | 解压 Arch Linux ARM armv7，删除自带内核，装入本项目模块，套用 `rootfs-overlay/` |
| `21-install-packages.sh` | WSL | `qemu-arm-static` 进 chroot，自离线源安装软件包 |
| `22-finish-rootfs.sh` | WSL | getty、时区、locale、pacman 源、清空 `machine-id`、清理临时文件 |
| `23-build-offline-repo.sh` | WSL | 修正 FAT32 非法文件名（`:` → `.`）并在 chroot 内重建数据库 |
| `30-build-images.sh` | WSL | 生成 `mbr.img`、`p1.img`、`p2.img`、`p3.img` 并自检 |
| `31-make-manifest.py` | WSL | 生成非零区块清单与各镜像内容 sha256 |
| `40-write-card.ps1` | Windows | 清分区表 → 按清单裸写 → 逐区块回读校验 |
| `90-make-cache.sh` | WSL | 打包整套文件到 `../cache/` |
| `serial-monitor.ps1` | Windows | 串口控制台，日志写入 `../logs/` |
| `watch-serial.bat` | Windows | `serial-monitor.ps1` 的包装 |

PetaLinux 工程路径由 `PLNX_WS`、`PLNX_IMAGES` 指定，默认指向
`$HOME/xilinx/petalinux-zynq7100/`。

## diag/

| 脚本 | 作用 |
|---|---|
| `check-rootfs.sh` | 根文件系统自检：`/boot` 为空、关键文件、单元链接、包数 |
| `check-vermagic.sh` | 核对全部 `.ko` 的 vermagic |
| `check-p1-contents.sh` | 打印 p1 内容与 `boot.scr` 脚本 |
| `check-devicetree.sh` | 打印设备树 model、chosen、aliases、串口节点 |
| `check-console.sh`、`check-getty.sh` | 登录横幅与 getty 单元核对 |
| `extract-overlay.sh` | 从 rootfs 抽取生效配置到 `rootfs-overlay/` |
| `dump-rootfs-config.sh` | 打印 rootfs 关键配置 |
| `card-check-p2.ps1` | 校验 p2 起始 4 MiB 与镜像一致 |
| `card-check-p3.ps1` | 校验 p3 的 `repo/` 包文件 md5 |
| `card-peek-old.ps1`、`card-backup-vendor.ps1` | 卡上原有内容查看与备份 |
| `card-test-*.ps1`、`card-diag-*.ps1` | 裸写路径、容量、回读差异定位 |
