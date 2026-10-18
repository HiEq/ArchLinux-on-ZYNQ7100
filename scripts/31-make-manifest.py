#!/usr/bin/env python3
"""扫描分区镜像，输出写卡清单（1 MiB 粒度的非零区块）与各镜像内容 sha256。

清单格式：
    #HASH|<镜像>|<区块内容 sha256>|<总字节数>
    <镜像>|<镜像内偏移>|<长度>

FAT32 分区强制写入前缀，保证 FAT 表与根目录区的 0 也落到介质；
ext4 依赖 metadata_csum（每个元数据块都带校验和，必然非零），可安全跳零。
"""
import hashlib
import os

W = os.environ.get('W', '/home/hieq/alarm')
CHUNK = 1 << 20

JOBS = [
    ('mbr.img', 1 << 20),    # MBR 首扇区
    ('p1.img',  32 << 20),   # FAT32 BOOT
    ('p2.img',  0),          # ext4 ARCH
    ('p3.img',  64 << 20),   # FAT32 SHARE，FAT 表较大
]

out = open(os.path.join(W, 'manifest.txt'), 'w')
total = 0

for name, force in JOBS:
    path = os.path.join(W, name)
    size = os.path.getsize(path)

    h = hashlib.sha256()          # 整文件
    with open(path, 'rb') as f:
        for blk in iter(lambda: f.read(1 << 22), b''):
            h.update(blk)

    hx = hashlib.sha256()         # 写入区块内容
    extents = []
    with open(path, 'rb') as f:
        pos = 0
        while pos < size:
            n = min(CHUNK, size - pos)
            b = f.read(n)
            if len(b) < n:
                b += b'\0' * (n - len(b))
            if pos < force or any(b):
                hx.update(b)
                if extents and extents[-1][0] + extents[-1][1] == pos:
                    extents[-1] = (extents[-1][0], extents[-1][1] + n)
                else:
                    extents.append((pos, n))
            pos += n

    written = sum(l for _, l in extents)
    total += written
    print(f'{name:9s} size={size:>13,}  写入={written:>13,} ({written / 2**20:.0f} MiB)  '
          f'区块={len(extents)}  sha256={h.hexdigest()}')
    out.write(f'#HASH|{name}|{hx.hexdigest()}|{written}\n')
    for off, ln in extents:
        out.write(f'{name}|{off}|{ln}\n')

out.close()
print(f'合计需写入 {total / 2**30:.2f} GiB')
