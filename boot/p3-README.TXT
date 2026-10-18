SHARE 分区
==========

repo/   Arch Linux ARM 离线软件源，板端以 file:///mnt/share/repo 访问
        用法：pacman -Sy && pacman -S <包名>

包文件名不得含 ":"（FAT32 限制）。新增包后需在板端重建数据库：
    cd /mnt/share/repo && repo-add offline.db.tar.gz *.pkg.tar.*
