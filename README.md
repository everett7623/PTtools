# PT Tools - PT工具一键安装脚本

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/everett7623/pttools)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

PT Tools 是一个为 PT (Private Tracker) 用户设计的一键安装脚本，简化了常用 PT 工具的安装和配置过程。

## 🚀 特性

- **一键安装**：简单命令即可安装各种 PT 工具
- **多版本支持**：支持 qBittorrent 4.3.8 和 4.3.9 版本
- **Docker 集成**：基于 Docker 的应用部署，易于管理
- **VPS 优化**：针对 PT 流量的系统优化
- **模块化设计**：易于扩展和维护
- **完整卸载**：支持选择性或完全卸载

## 📋 系统要求

- 操作系统：Ubuntu 18.04+ / Debian 10+ / CentOS 7+
- 内存：建议 2GB 以上
- 存储：建议 20GB 以上可用空间
- 权限：需要 root 权限运行

## 🛠️ 快速开始

### 一键安装

```bash
wget -O pttools.sh https://raw.githubusercontent.com/everett7623/pttools/main/pttools.sh && chmod +x pttools.sh && ./pttools.sh
```

### 基础使用

运行脚本后，您将看到主菜单：

1. **安装 qBittorrent 4.3.8** - 使用 iniwex5 脚本安装
2. **安装 qBittorrent 4.3.9** - 使用 Jerry 大佬的脚本安装
3. **安装 qBittorrent 4.3.8 + Vertex** - 组合安装
4. **安装 qBittorrent 4.3.9 + Vertex** - 组合安装
5. **选择安装应用** - 自定义选择要安装的应用
6. **VPS 优化** - 优化系统设置以提升 PT 性能
7. **卸载选项** - 卸载已安装的应用
8. **退出**

## 📦 支持的应用

### 下载管理
- **qBittorrent** - 强大的 BT 下载客户端
- **Transmission** - 轻量级 BT 客户端

### 自动化工具
- **IYUUPlus** - PT 站点自动化管理
- **MoviePilot** - 影视自动化下载管理
- **Vertex** - PT 专用辅助工具
- **NAS-Tools** - NAS 媒体库自动化管理工具

### 媒体服务器
- **Emby** - 强大的媒体服务器

### 文件管理
- **FileBrowser** - 网页文件管理器

### 特殊工具
- **MetaTube** - 元数据管理工具
- **Byte-Muse** - 字节缪斯工具

## 🔧 高级配置

### 配置文件位置

- 主配置：`/etc/pttools/config.conf`
- Docker 数据：`/opt/docker/`
- 下载目录：`/opt/downloads/`
- 日志文件：`/var/log/pttools-install.log`

### 自定义端口

编辑 `/etc/pttools/config.conf` 文件：

```bash
WEBUI_PORT=8080      # qBittorrent WebUI 端口
DAEMON_PORT=23333    # qBittorrent 守护进程端口
```

### Docker Compose 管理

```bash
cd /opt/docker
docker-compose ps      # 查看容器状态
docker-compose logs    # 查看日志
docker-compose restart # 重启所有服务
```

## 🚀 VPS 优化

脚本包含针对 PT 流量优化的系统设置：

- **网络优化**：TCP 缓冲区、连接数优化
- **BBR 加速**：启用 BBR 拥塞控制算法
- **文件系统**：提升文件描述符限制
- **磁盘 I/O**：针对 SSD/HDD 的调度器优化

运行优化：
```bash
./pttools.sh
# 选择 6 - VPS 优化
```

## 📝 常见问题

### 1. 安装失败怎么办？

检查日志文件：
```bash
tail -f /var/log/pttools-install.log
```

### 2. 如何更改下载目录？

编辑配置文件：
```bash
nano /etc/pttools/config.conf
# 修改 DOWNLOAD_PATH 变量
```

### 3. 端口被占用？

使用以下命令检查端口：
```bash
ss -tulnp | grep :8080
```

### 4. 如何完全卸载？

```bash
./pttools.sh
# 选择 7 - 卸载选项
# 选择 4 - 完全系统清理
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发指南

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- [iniwex5](https://github.com/iniwex5) - qBittorrent 4.3.8 安装脚本
- [jerry048](https://github.com/jerry048/Dedicated-Seedbox) - qBittorrent 4.3.9 优化脚本
- 所有 PT 工具的开发者们

## 📞 联系方式

- GitHub: [@everett7623](https://github.com/everett7623)
- Issues: [GitHub Issues](https://github.com/everett7623/pttools/issues)

---

**注意**：使用本脚本前请确保您了解相关工具的使用规则和您所在 PT 站点的规定。
