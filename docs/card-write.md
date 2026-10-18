# 卡写入记录

记录 32 GB 卡（29.1 GiB）写入失败与 116.58 GB 卡写入成功的过程，以及 Windows 侧裸写的
两个前置条件。

## 1. 写入方式

WSL 无法挂载读卡器（`wsl --mount --bare \\.\PHYSICALDRIVE2` 返回
`HCS/ERROR_INVALID_DRIVE`；该读卡器经 SCSI 接入，不是 USB 设备，`usbipd` 无法转发）。
因此采用：

1. WSL 内生成分区镜像，不使用 loop 设备：`mbr.img`、`p1.img`、`p2.img`、`p3.img`。
2. `scripts/31-make-manifest.py` 扫描镜像，输出非零区块清单与内容 sha256。
   FAT32 分区强制写入前缀以保证 FAT 表与根目录区的 0 落到介质；ext4 依赖
   `metadata_csum`，每个元数据块都带校验和，可安全跳零。
3. `scripts/40-write-card.ps1` 在 Windows 侧按清单 seek + write 到
   `\\.\PHYSICALDRIVE2`，再逐区块回读计算 sha256 比对。

## 2. Windows 裸写的前置条件

| 现象 | 原因 | 处理 |
|---|---|---|
| 写偏移 0 成功，写偏移 1 MiB 起返回 `ERROR_ACCESS_DENIED` | 分区表更新后 Windows 自动挂载了 p1，对属于已挂载卷的扇区禁止裸写 | 写卡前清零卡首 1 MiB，`diskpart rescan` 使 mountmgr 卸载卷 |
| `mountvol <卷GUID> /p` 返回参数错误，`diskpart offline disk` 不支持可移动介质 | 该卷进入"已卸载未释放"状态，后续写入返回 `设备未就绪` | 不使用 `mountvol /p`，单独补写时重新执行完整写入流程 |

因此 `40-write-card.ps1` 的写入顺序为：清分区表 → p1 → p2 → p3 → 最后写 MBR。
写入过程中拔出卡会导致设备掉线（`设备硬件出现严重错误`），需重新插拔恢复。

## 3. 32 GB 卡（29.1 GiB）

卡为 GL PCI-e Reader，31,247,564,800 B（61,030,400 扇区）。

| 镜像 | 写入量 | 回读校验 |
|---|---|---|
| `mbr.img` | 1 MiB | 通过 |
| `p1.img` | 32 MiB | 通过 |
| `p2.img` | 2,249 MiB | 不通过 |
| `p3.img` | 131 MiB | 不通过 |

只读比对：p2 的 20 个区块中 18 个的前 64 KiB 与镜像不一致，p3 整段不一致；逐字节查看
卡上对应位置为 `0x00`（原值），同一位置连续读三次结果一致。p1 与 MBR 所在位置内容正确。

单点实验：卡偏移 100 MiB 处写入 64 KiB 后立即回读仍为原值；该批实验的比对函数返回值异常，
结论需重做。该卡疑似扩容盘，已停用。

## 4. 116.58 GB 卡

| 镜像 | 写入量 | 写入速率 | 回读速率 |
|---|---|---|---|
| `mbr.img` | 1 MiB | — | 16 MB/s |
| `p1.img` | 32 MiB | 17.3 MB/s | 109 MB/s |
| `p2.img` | 2,249 MiB | 16.8 MB/s | 87 MB/s |
| `p3.img` | 131 MiB | 19.1 MB/s | 91 MB/s |

p1/p2 与 MBR 校验一致；p3 为 FAT32，MBR 写入后 Windows 立即挂载并创建
`System Volume Information`，整分区哈希不一致，`repo/` 下 74 个包 md5 全部一致。
