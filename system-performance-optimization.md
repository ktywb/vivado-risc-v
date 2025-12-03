# 系统性能全面优化方案

## 📊 系统配置诊断报告

### 硬件配置
- **CPU**: Intel Core i7-4770 (4核8线程, 3.4GHz, 最大3.9GHz)
- **内存**: 32GB
- **存储**: 6TB HDD (WDC WD60EZAZ, SATA 6.0Gb/s)
- **Swap**: 256MB zram (lz4 压缩)

### 当前系统状态分析

#### ⚠️ 发现的性能瓶颈

1. **磁盘性能严重瓶颈**
   - 使用机械硬盘 (HDD, 转速 ROTA=1)
   - HDD 的随机读写性能极差（~100 IOPS）
   - 对于 Vivado 等 I/O 密集型应用是主要瓶颈

2. **zram 配置过小**
   - 当前仅 256MB，对于 32GB 内存来说太小
   - swappiness=10，说明系统不愿意使用 swap
   - Vivado 进程占用 3GB+ 内存时可能导致性能问题

3. **桌面环境负载**
   - GNOME Shell 占用大量资源（~270MB 内存）
   - 有两个 GNOME Shell 实例运行（xrdp 会话）
   - 57 个服务在运行，部分可能不必要

4. **磁盘调度器**
   - 当前使用 `mq-deadline`，对 HDD 不是最优

5. **文件系统缓存压力**
   - vfs_cache_pressure = 50（较低，倾向保留缓存）
   - dirty_ratio = 20%（对 32GB 内存，可以调整）

6. **CPU 频率调节器**
   - 当前使用 `schedutil`，可以考虑 `performance` 模式

### 🎯 优化优先级

**立即见效（推荐优先执行）**：
1. 增加 zram 大小
2. 优化磁盘调度器和预读
3. 减少不必要的服务
4. 调整内核参数

**中期改进**：
5. 切换到轻量级桌面
6. 优化 tmpfs 使用
7. 禁用不必要的 GNOME 服务

**长期投资（硬件升级）**：
8. 添加 SSD（强烈推荐！）

---

## 🚀 立即优化方案

### 1. 增加 zram 大小（重要！）

对于 32GB 内存的系统，建议配置 4-8GB 的 zram。

```bash
# 方案 A：修改 zram 配置（推荐 4GB）
sudo nano /etc/default/zramswap

# 修改或添加以下内容：
ALGO=lz4
PERCENT=12.5    # 32GB * 12.5% = 4GB
SIZE=4096       # 或直接指定 4GB

# 重启 zram
sudo systemctl restart zramswap
如果没有 zramswap 服务，手动配置：

#!/bin/bash
# 停止当前 zram
sudo swapoff /dev/zram0
sudo rmmod zram

# 创建 4GB zram
sudo modprobe zram num_devices=1
echo lz4 | sudo tee /sys/block/zram0/comp_algorithm
echo 4G | sudo tee /sys/block/zram0/disksize
sudo mkswap /dev/zram0
sudo swapon -p 100 /dev/zram0

# 验证
cat /proc/swaps
zramctl
持久化配置：

创建 /etc/systemd/system/zram-config.service：

[Unit]
Description=Configure zram swap
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'modprobe zram num_devices=1 && \
  echo lz4 > /sys/block/zram0/comp_algorithm && \
  echo 4G > /sys/block/zram0/disksize && \
  mkswap /dev/zram0 && \
  swapon -p 100 /dev/zram0'
ExecStop=/bin/bash -c 'swapoff /dev/zram0 && rmmod zram'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
sudo systemctl daemon-reload
sudo systemctl enable zram-config
sudo systemctl start zram-config
2. 优化磁盘性能（重要！）
A. 调整磁盘调度器（HDD 使用 BFQ 更好）
# 检查当前调度器
cat /sys/block/sda/queue/scheduler

# 临时更改为 BFQ（更适合 HDD）
echo bfq | sudo tee /sys/block/sda/queue/scheduler

# 持久化：编辑 /etc/udev/rules.d/60-ioschedulers.rules
sudo nano /etc/udev/rules.d/60-ioschedulers.rules

# 添加以下内容：
# 为 HDD 设置 BFQ 调度器
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
B. 增加磁盘预读缓冲
# 当前预读：128KB，对大文件项目可以增加
# 临时设置为 2MB（对 Vivado 项目更好）
sudo blockdev --setra 4096 /dev/sda  # 4096 * 512B = 2MB

# 持久化：添加到 /etc/rc.local 或创建 systemd 服务
sudo nano /etc/rc.local
# 添加：
blockdev --setra 4096 /dev/sda
C. 优化文件系统挂载选项
# 检查当前挂载
mount | grep sda2

# 编辑 /etc/fstab 添加 noatime,commit=60
sudo nano /etc/fstab

# 将：
# /dev/sda2 / ext4 rw,relatime,errors=remount-ro 0 1
# 改为：
/dev/sda2 / ext4 rw,noatime,commit=60,errors=remount-ro 0 1

# noatime: 不更新访问时间，减少写操作
# commit=60: 每60秒提交一次（默认5秒），减少写操作

# 立即应用（不重启）
sudo mount -o remount,noatime,commit=60 /
3. 调整内核参数（立即生效）
创建优化脚本 /etc/sysctl.d/99-performance.conf：

sudo nano /etc/sysctl.d/99-performance.conf
添加以下内容：

# ===== 内存管理优化 =====

# Swappiness - 降低为 5（有 zram 时更积极使用）
vm.swappiness = 5

# VFS 缓存压力 - 保持 50（已经不错）
vm.vfs_cache_pressure = 50

# Dirty page 优化（减少突发写入对性能的影响）
vm.dirty_ratio = 10                    # 从 20 降至 10
vm.dirty_background_ratio = 3          # 从 5 降至 3
vm.dirty_expire_centisecs = 3000       # 从 6000 降至 3000
vm.dirty_writeback_centisecs = 1500    # 从 3000 降至 1500

# 增加文件句柄限制（Vivado 需要）
fs.file-max = 2097152

# ===== 网络性能优化 =====
# 增加网络缓冲区（改善 xrdp 性能）
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# TCP 优化
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1

# ===== 磁盘 I/O 优化 =====
# 增加 readahead（通过 udev 规则更好）
# vm.laptop_mode = 0
应用配置：

sudo sysctl -p /etc/sysctl.d/99-performance.conf
4. 调整 swappiness（配合 zram）
# 临时调整
sudo sysctl vm.swappiness=5

# 已包含在上面的 sysctl 配置中
5. 优化 CPU 性能模式
# 安装 cpufrequtils
sudo apt install cpufrequtils

# 设置为 performance 模式（高性能）
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# 或使用 cpufrequtils
sudo cpufreq-set -g performance

# 持久化：
sudo systemctl disable ondemand  # 禁用 ondemand 服务
sudo nano /etc/default/cpufrequtils
# 添加：
GOVERNOR="performance"
🔧 中期优化方案
6. 减少不必要的服务
# 查看所有启用的服务
systemctl list-unit-files --type=service --state=enabled

# 禁用不必要的服务（根据实际需求选择）
sudo systemctl disable cups-browsed    # 如果不需要打印机自动发现
sudo systemctl disable ModemManager    # 如果不使用移动宽带
sudo systemctl disable avahi-daemon    # 如果不需要 mDNS
sudo systemctl disable bluetooth       # 如果不使用蓝鲜
sudo systemctl disable kerneloops      # 内核错误报告

# 禁用不需要的网络服务
# sudo systemctl disable clash-verge-service  # 按需
# sudo systemctl disable mihomo              # 按需
# sudo systemctl disable fastgithub          # 按需
7. 禁用 GNOME 不必要的后台服务
# 禁用 GNOME Tracker（文件索引服务，很占资源）
systemctl --user mask tracker-store.service
systemctl --user mask tracker-miner-fs.service
systemctl --user mask tracker-miner-rss.service
systemctl --user mask tracker-extract.service
systemctl --user mask tracker-miner-apps.service
systemctl --user mask tracker-writeback.service

# 禁用 Evolution 数据服务器（如果不用 Evolution）
systemctl --user mask evolution-addressbook-factory.service
systemctl --user mask evolution-calendar-factory.service
systemctl --user mask evolution-source-registry.service

# 重启生效
systemctl --user daemon-reload
8. 优化 GNOME Shell
# 禁用动画（已在 xrdp 优化中做过）
gsettings set org.gnome.desktop.interface enable-animations false

# 禁用文件缩略图生成
gsettings set org.gnome.desktop.thumbnailers disable-all true

# 减少搜索提供者
gsettings set org.gnome.desktop.search-providers disabled "['org.gnome.Calculator.desktop', 'org.gnome.Calendar.desktop', 'org.gnome.Characters.desktop', 'org.gnome.Contacts.desktop', 'org.gnome.Nautilus.desktop']"

# 禁用透明效果
gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false
9. 优化 tmpfs 大小（根据需要）
你的 tmpfs 配置已经很好了：

/tmp: 1GB
/var/log: 100MB
/var/tmp: 512MB
如果 Vivado 项目需要更多临时空间：

# 临时增加 /tmp 大小到 2GB
sudo mount -o remount,size=2G /tmp

# 持久化：编辑 /etc/fstab
sudo nano /etc/fstab
# 修改 tmpfs 行：
tmpfs   /tmp        tmpfs   defaults,noatime,mode=1777,size=2G   0 0
tmpfs   /var/tmp    tmpfs   defaults,noatime,mode=1777,size=1G   0 0
10. 考虑切换到轻量级桌面环境（可选）
GNOME 很重，考虑使用 XFCE 或 LXQt：

# 安装 XFCE
sudo apt install xfce4 xfce4-goodies

# 设置为默认
echo "xfce4-session" > ~/.xsession
sudo update-alternatives --config x-session-manager

# 下次登录时选择 XFCE
💾 硬件升级建议（最有效！）
强烈推荐：添加 SSD
为什么 SSD 至关重要：

HDD 随机读写：~100 IOPS
SATA SSD 随机读写：~50,000 IOPS（500倍提升！）
NVMe SSD 随机读写：~500,000 IOPS（5000倍提升！）
推荐方案：

方案 A：小容量 SSD 作为系统盘 + 缓存（推荐！）
购买 256GB-512GB NVMe SSD
安装系统 + Vivado + 工作项目
HDD 作为数据存储
成本：~300-600 元
性能提升：10-20 倍
方案 B：使用 bcache 或 lvmcache
购买 128GB SSD 作为 HDD 缓存
透明加速 HDD 访问
成本：~150-300 元
性能提升：3-5 倍
# bcache 配置示例（需要重新格式化磁盘，谨慎！）
sudo apt install bcache-tools
# 将 SSD 设置为缓存设备
sudo make-bcache -C /dev/nvme0n1
# 将 HDD 设置为后端设备
sudo make-bcache -B /dev/sda2
# 附加缓存
sudo echo /dev/sda2 > /sys/fs/bcache/register
内存升级（可选）
当前 32GB 对大多数任务够用
如果运行超大 Vivado 项目，考虑升级到 64GB
📋 完整优化脚本
创建一键优化脚本 /home/name/system-optimize.sh：

#!/bin/bash
# 系统性能全面优化脚本

echo "开始系统性能优化..."

# 1. 备份当前配置
sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d)
sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d)

# 2. 创建 sysctl 优化配置
cat <<EOF | sudo tee /etc/sysctl.d/99-performance.conf
# Swappiness
vm.swappiness = 5
vm.vfs_cache_pressure = 50

# Dirty page
vm.dirty_ratio = 10
vm.dirty_background_ratio = 3
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 1500

# File handles
fs.file-max = 2097152

# Network
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
EOF

sudo sysctl -p /etc/sysctl.d/99-performance.conf

# 3. 磁盘调度器优化
cat <<EOF | sudo tee /etc/udev/rules.d/60-ioschedulers.rules
# HDD 使用 BFQ
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
# SSD 使用 mq-deadline 或 none
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF

echo bfq | sudo tee /sys/block/sda/queue/scheduler

# 4. 增加磁盘预读
sudo blockdev --setra 4096 /dev/sda

# 5. CPU 性能模式
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# 6. 禁用不必要的服务
for service in cups-browsed ModemManager avahi-daemon kerneloops; do
    sudo systemctl is-enabled $service 2>/dev/null && sudo systemctl disable $service
done

# 7. 禁用 GNOME tracker
for service in tracker-store tracker-miner-fs tracker-miner-rss tracker-extract tracker-miner-apps tracker-writeback; do
    systemctl --user mask ${service}.service 2>/dev/null
done

# 8. GNOME 优化
gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null
gsettings set org.gnome.desktop.thumbnailers disable-all true 2>/dev/null

echo "优化完成！建议重启系统以使所有更改生效。"
echo "执行: sudo reboot"
使其可执行并运行：

chmod +x /home/name/system-optimize.sh
./system-optimize.sh
🔍 性能监控工具
安装有用的监控工具：

# 安装系统监控工具
sudo apt install -y \
    htop \
    iotop \
    sysstat \
    dstat \
    glances \
    ncdu

# 使用方法：
htop           # CPU 和内存实时监控
sudo iotop     # 磁盘 I/O 监控
iostat -x 2    # 磁盘统计
dstat          # 综合系统统计
glances        # 全面系统监控
ncdu /home     # 磁盘使用分析
📈 预期性能提升
应用软件优化后：
整体响应速度: +20-30%
内存交换延迟: -50% (zram 扩容)
磁盘顺序读写: +15-20% (预读优化)
系统启动时间: -10-15% (减少服务)
GNOME 响应: +30-40% (禁用特效和服务)
如果添加 SSD：
Vivado 启动速度: +500-1000%
项目综合速度: +300-500%
文件操作: +1000%+
系统整体响应: +200-300%
✅ 优化检查清单
执行优化后，使用以下命令验证：

# 检查 zram
zramctl
cat /proc/swaps

# 检查 swappiness
cat /proc/sys/vm/swappiness

# 检查磁盘调度器
cat /sys/block/sda/queue/scheduler

# 检查预读
sudo blockdev --getra /dev/sda

# 检查 CPU 频率
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# 检查内存
free -h

# 检查磁盘挂载
mount | grep sda2

# 检查系统负载
uptime
🆘 故障恢复
如果优化后出现问题：

# 恢复 sysctl
sudo rm /etc/sysctl.d/99-performance.conf
sudo sysctl -p

# 恢复 fstab
sudo cp /etc/fstab.backup.YYYYMMDD /etc/fstab
sudo mount -o remount /

# 恢复服务
sudo systemctl enable <service_name>

# 恢复 zram
sudo swapoff /dev/zram0
sudo rmmod zram
# 然后重启系统使用默认配置
📞 性能问题诊断
如果系统仍然卡顿，运行以下诊断：

# 1. 检查当前负载
top -bn1 | head -20

# 2. 检查磁盘 I/O
sudo iotop -b -n 1

# 3. 检查内存压力
free -h
vmstat 1 10

# 4. 检查磁盘延迟
sudo hdparm -t /dev/sda  # 测试读取速度

# 5. 查找占用资源的进程
ps aux --sort=-%cpu | head -10
ps aux --sort=-%mem | head -10
创建日期: 2025-10-22
最后更新: 2025-10-22
系统: Ubuntu with GNOME, 32GB RAM, 6TB HDD, zram

注意:

所有涉及系统配置的更改都已做好备份说明
建议先在非关键时段测试优化效果
最有效的优化是添加 SSD，软件优化只能改善但无法根本解决 HDD 瓶颈
重启后验证所有优化是否生效