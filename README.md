# PTtools - PT工具一键安装脚本 (VPS优化版)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/release/everett7623/PTtools.svg)](https://github.com/everett7623/PTtools/releases)
[![GitHub stars](https://img.shields.io/github/stars/everett7623/PTtools.svg)](https://github.com/everett7623/PTtools/stargazers)

🚀 **专为PT用户设计的VPS优化脚本，针对刷流场景深度优化**

适合小白用户快速部署，同时为高级用户提供极致性能调优。

## 🎯 核心特性

### ⚡ VPS性能优化
- **BBR拥塞控制算法** - 显著提升网络吞吐量
- **TCP参数调优** - 专为大量并发连接优化
- **文件描述符优化** - 支持数万并发连接
- **磁盘I/O优化** - SSD/HDD自动识别优化
- **内存缓存调优** - 根据服务器配置自动调整

### 🏆 核心安装选项

| 选项 | 说明 | 推荐场景 |
|------|------|----------|
| **qBittorrent 4.3.8** | 经典稳定版 + VPS优化 | 稳定性优先 |
| **qBittorrent 4.3.9** | 最新版本 + VPS优化 | ⭐ **推荐选择** |
| **qB 4.3.8 + Vertex** | 刷流组合配置 | 高级用户 |
| **qB 4.3.9 + Vertex** | 🔥 **最强组合** | 刷流专业用户 |

## 🚀 快速开始

### 一键安装命令

```bash
# 方式1：下载后执行 (推荐)
wget -O pttools.sh https://raw.githubusercontent.com/everett7623/PTtools/main/pttools.sh && chmod +x pttools.sh && ./pttools.sh

# 方式2：直接执行
bash <(wget -qO- https://raw.githubusercontent.com/everett7623/PTtools/main/pttools.sh)
```

### 菜单导航

```
PTtools 主菜单
├── 1. qBittorrent 4.3.8
├── 2. qBittorrent 4.3.9 (推荐) ⭐
├── 3. qBittorrent 4.3.8 + Vertex (刷流组合)
├── 4. qBittorrent 4.3.9 + Vertex (最强组合) 🔥
├── 5. 选择安装应用 (功能分类与工具列表)
│   ├── 下载工具 (Transmission/Vertex)
│   ├── 媒体服务器 (Emby/Jellyfin/Plex)
│   ├── 索引器 (Jackett/Prowlarr)
│   └── 自动化工具 (*arr套件)
├── 6. 系统优化 (VPS性能调优)
├── 7. 卸载应用
└── 0. 退出脚本
```

## 📦 支持的应用

### 🏆 核心下载工具
- **qBittorrent 4.3.8/4.3.9** - 编译版本，深度优化
- **Transmission** - 轻量级BT客户端 (Docker版)
- **Vertex** - 专业刷流工具 (Docker版)

### 🎬 媒体服务器
- **Emby** - 功能丰富的媒体服务器
- **Jellyfin** - 开源免费媒体服务器
- **Plex** - 专业级媒体服务器

### 🔍 索引器/搜索
- **Jackett** - 传统索引器代理
- **Prowlarr** - 新一代索引器管理 ⭐

### 🤖 自动化工具
- **Sonarr** - 电视剧自动下载管理
- **Radarr** - 电影自动下载管理
- **Lidarr** - 音乐自动下载管理
- **Bazarr** - 字幕自动下载管理

## 🗂️ 项目结构

```
PTtools/
├── pttools.sh                          # 主安装脚本
├── scripts/
│   └── install/
│       ├── qb438.sh                    # qBittorrent 4.3.8 安装脚本
│       ├── qb439.sh                    # qBittorrent 4.3.9 安装脚本
│       └── applications/
│           └── vertex.sh               # Vertex PT高级优化脚本
└── configs/
    └── docker-compose/
        ├── qbittorrent.yml             # qBittorrent Docker配置
        ├── transmission.yml            # Transmission Docker配置
        ├── emby.yml                    # Emby Docker配置
        ├── jellyfin.yml                # Jellyfin Docker配置
        ├── plex.yml                    # Plex Docker配置
        ├── jackett.yml                 # Jackett Docker配置
        ├── prowlarr.yml                # Prowlarr Docker配置
        ├── sonarr.yml                  # Sonarr Docker配置
        ├── radarr.yml                  # Radarr Docker配置
        ├── lidarr.yml                  # Lidarr Docker配置
        └── bazarr.yml                  # Bazarr Docker配置
```

## 📍 默认路径

| 项目 | 路径 | 说明 |
|------|------|------|
| Docker应用目录 | `/opt/docker` | 所有Docker应用的配置和数据 |
| 下载目录 | `/opt/downloads` | 统一下载目录 |
| qBittorrent目录 | `/home/qbittorrent` | qB用户主目录 |
| 脚本目录 | `/opt/pttools` | PTtools脚本存放目录 |

## 🛠️ 系统优化功能

PTtools内置强大的系统优化功能（主菜单选项6），包括：

### 🚀 VPS性能优化
- **BBR拥塞控制** - 提升网络吞吐量
- **TCP参数调优** - 针对大量并发连接优化  
- **文件描述符优化** - 支持数万并发连接

### 💿 磁盘I/O优化
- **调度器优化** - 自动设置最优I/O调度器
- **读前瞻设置** - 提升磁盘读取性能
- **缓存策略** - 智能磁盘缓存管理

### 🌐 网络连接优化
- **连接数优化** - 提升并发连接能力
- **缓冲区调优** - 优化网络缓冲区大小
- **协议优化** - TCP/UDP协议栈优化

### 💾 内存管理优化
- **交换设置** - 优化虚拟内存使用
- **缓存策略** - 智能内存缓存管理
- **页面回收** - 优化内存页面回收策略

### 📊 优化状态监控
- 实时查看系统优化状态
- BBR状态检查
- 文件描述符限制检查
- 磁盘调度器状态
- 内存使用情况

使用方法：主菜单选择 **6. 系统优化** 进入优化菜单

## ⚡ PTBoost & Vertex 工具

### PTBoost优化器（qBittorrent性能优化）
```bash
# 性能监控
ptboost-monitor

# 服务管理  
ptboost-manage

# 性能调优
ptboost-tune
```

### Vertex刷流工具管理
```bash
# 启动/停止服务
vertex-ctl start|stop|restart

# 查看状态和日志
vertex-ctl status|logs

# 更新容器
vertex-ctl update
```

### 📊 监控指标
- 系统负载和资源使用
- qBittorrent进程状态
- 网络连接数统计
- 磁盘I/O性能
- TCP连接状态分析

## 🎛️ 系统优化详情

### 🌐 网络优化
```bash
# BBR拥塞控制
net.ipv4.tcp_congestion_control = bbr

# TCP缓冲区优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# 连接优化
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65536
```

### 💾 内存优化
```bash
# 文件描述符
* soft nofile 1000000
* hard nofile 1000000

# 虚拟内存
vm.swappiness = 10
vm.dirty_ratio = 15
vm.vfs_cache_pressure = 50
```

### 💿 磁盘I/O优化
- **I/O调度器**: 自动设置为 `mq-deadline` 或 `deadline`
- **读前瞻**: 优化为 4MB
- **缓存策略**: 根据内存大小动态调整

## 🔧 使用指南

### 🎯 推荐配置

| 服务器配置 | 推荐选项 | 预期性能 |
|-----------|----------|----------|
| 1C1G | 选项2 (qB 4.3.9) | 200+ 种子 |
| 2C2G | 选项4 (qB 4.3.9 + Vertex) | 500+ 种子 |
| 4C4G+ | 选项4 (qB 4.3.9 + Vertex) | 1000+ 种子 |

### 📋 安装步骤

1. **执行脚本**
   ```bash
   bash <(wget -qO- https://raw.githubusercontent.com/everett7623/PTtools/main/pttools.sh)
   ```

2. **选择核心选项** (推荐选项2或4)

3. **配置qBittorrent**
   - 访问: `http://你的IP:8080`
   - 用户名: `admin`
   - 密码: `adminadmin`

4. **性能监控** (可选)
   ```bash
   vertex-monitor  # 查看性能状态
   vertex-manage   # 管理服务
   ```

### 🔍 故障排除

```bash
# 检查服务状态
systemctl status qbittorrent

# 查看实时日志
journalctl -u qbittorrent -f

# 重启服务
systemctl restart qbittorrent

# 系统优化状态检查
# 在PTtools主菜单选择 "6. 系统优化" -> "9. 查看当前优化状态"

# Vertex管理
vertex-ctl status    # 查看Vertex状态
vertex-ctl logs      # 查看Vertex日志
```

## 📈 性能优化建议

### 🎯 刷流场景优化

1. **连接数设置**
   - 小内存VPS: 200-400连接
   - 中等配置: 400-800连接  
   - 高配置: 800-1500连接

2. **上传策略**
   - 最大上传数: 50-100
   - 单种子上传: 5-10
   - 上传限速: 不限制 (让带宽跑满)

3. **磁盘优化**
   - 启用预分配
   - 使用临时下载目录
   - 定期清理日志文件

### ⚡ 极致优化

选择 **选项4** (qBittorrent 4.3.9 + Vertex) 可获得：

- **专业刷流**: qBittorrent + Vertex双重加持
- **网络性能提升**: 30-50%
- **连接数增加**: 支持1000+并发
- **智能策略**: Vertex专业刷流算法
- **完整生态**: qB下载 + Vertex刷流完美结合

## 🆘 技术支持

### 📞 获取帮助

- **GitHub Issues**: [提交问题](https://github.com/everett7623/PTtools/issues)
- **性能问题**: 使用主菜单选项6进行系统优化
- **配置问题**: 使用 `vertex-ctl` 或 `ptboost-manage` 管理服务

### 🔄 更新脚本

```bash
# 更新到最新版本
wget -O pttools.sh https://raw.githubusercontent.com/everett7623/PTtools/main/pttools.sh
chmod +x pttools.sh
./pttools.sh
```

### 🗑️ 完全卸载

脚本提供完整的卸载功能，包括：
- 停止所有服务
- 删除用户和配置
- 清理Docker容器
- 恢复系统设置

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- qBittorrent 开发团队
- Docker 社区
- 所有贡献者和用户反馈

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给个星标支持！⭐**

**🚀 让PT刷流更简单，让VPS性能更极致！🚀**

</div>
