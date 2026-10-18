# 手工分区与写入

卡容量 125,174,808,576 B（244,482,048 扇区）。以下为默认布局，p3 取剩余空间。

## 1. 分区表

MBR（DOS），不使用 GPT。

| # | 起始扇区 | 扇区数 | 大小 | 类型 | 卷标 | 标志 |
|---|---|---|---|---|---|---|
| p1 | 2,048 | 1,048,576 | 512 MiB | FAT32 | `BOOT` | bootable |
| p2 | 1,050,624 | 33,554,432 | 16 GiB | ext4 | `ARCH` | — |
| p3 | 34,605,056 | 209,876,992 | 约 100 GiB | FAT32 | `SHARE` | — |

约束：

- p1 必须是第一个 FAT32 分区，Zynq BootROM 在分区表中查找 FAT 分区并读取根目录下的
  `BOOT.BIN`；
- p2 必须是第二个分区，`root=/dev/mmcblk0p2`；
- p2 不小于 16 GiB 才能容纳本文的 ext4 镜像，容量更大的分区可在板端 `resize2fs`；
- p3 可用任意剩余容量，Release 镜像为 8 GiB。

## 2. p1（FAT32 `BOOT`）

文件置于分区根目录，来源见 `boot/`：

| 文件 | 字节 | 必需 |
|---|---|---|
| `BOOT.BIN` | 1,166,324 | 是 |
| `zImage` | 5,168,448 | 是 |
| `system.dtb` | 18,547 | 是 |
| `boot.scr` | 301 | 是 |
| `boot-petalinux.scr` | 3,830 | 否 |
| `System.map-6.18.10-xilinx-g4f7afe14f724` | 2,202,005 | 否 |
| `config-6.18.10-xilinx-g4f7afe14f724` | 167,193 | 否 |

`boot.scr` 由 `boot/boot-ps.cmd` 经 `mkimage -A arm -T script -C none` 编译，
内容为：

```
setenv bootargs console=ttyPS0,115200 root=/dev/mmcblk0p2 rw rootwait rootfstype=ext4
echo "booting Arch Linux ARM: root=/dev/mmcblk0p2"
load mmc 0:1 0x2000000 zImage
load mmc 0:1 0x1000000 system.dtb
bootz 0x2000000 - 0x1000000
```

## 3. p2（ext4 `ARCH`）

16 GiB ext4 镜像，`sha256` 见 Release 的 `SHA256SUMS.txt`。写入方式任选：

1. 分区镜像恢复到 p2：DiskGenius「从镜像文件还原分区」、`dd for Windows`
   （`dd if=p2.img of=\\.\PHYSICALDRIVE<N> bs=1M seek=513`），或 HxD 按偏移写入。
2. Linux 下展开文件：`mount /dev/sdX2 /mnt && tar -xJf rootfs.tar.xz -C /mnt --strip-components=1`。

写入后 Windows 会提示格式化，必须取消，ext4 不被识别。

写入后自检（比对 p2 起始处前 4 MiB 与镜像，检查 ext4 魔数、块大小、UUID）：

```powershell
.\scripts\diag\card-check-p2.ps1
.\scripts\diag\card-check-p2.ps1 -Offset <p2 起始字节>
```

## 4. p3（FAT32 `SHARE`）

将离线源放入分区的 `repo` 目录：

```
p3/
└── repo/
    ├── offline.db
    ├── offline.db.tar.gz
    └── <71 个 .pkg.tar.xz>
```

板端 pacman 配置：

```
[offline]
SigLevel = Optional TrustAll
Server   = file:///mnt/share/repo
```

包文件名不得含 `:`（FAT32 限制）；epoch 包名已改为 `.` 并据此重建数据库，不要手工改名。
p3 可省略，仅影响板端安装软件。

## 5. 启动参数与登录

由 `boot.scr` 提供，无需修改：

```
console=ttyPS0,115200 root=/dev/mmcblk0p2 rw rootwait rootfstype=ext4
```

串口 115200 8N1，登录 `root`，密码 `root`（ALARM 默认，上板后应修改）。
登录横幅来自 `/etc/issue`，为 Arch logo 加 `Arch Linux ARM <内核版本> (ttyPS0)`。
