# PTtools - PT工具一键安装脚本

[![GitHub](https://img.shields.io/github/license/everett7623/PTtools)](https://github.com/everett7623/PTtools/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/everett7623/PTtools)](https://github.com/everett7623/PTtools/stargazers)

## 简介

PTtools 是一个为 PT (Private Tracker) 用户设计的一键安装脚本，旨在帮助新手快速部署常用的 PT 工具。脚本针对 VPS 环境进行了优化，特别适合用于 PT 刷流。

## 功能特点

- 🚀 一键安装常用 PT 工具
- 🔧 针对 VPS 优化配置
- 🐳 基于 Docker 的应用管理
- 📦 模块化设计，易于扩展
- 🛡️ 自动配置防火墙规则
- 🔄 支持应用卸载和更新

## 快速开始

### 一键安装

```bash
wget -O pttools.sh https://raw.githubusercontent.com/everett7623/PTtools/main/pttools.sh && chmod +x pttools.sh && ./pttools.sh
```

或者：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/everett7623/PTtools/main/pttools.sh)
```

### 系统要求

- 操作系统：Ubuntu 18.04+, Debian 9+, CentOS 7+
- 权限：需要 root 权限
- 架构：x86_64
- 内存：建议 2GB 以上
- 硬盘：建议 20GB 以上

## 目录结构

```
PTtools/
├── pttools.sh                    # 主脚本
├── scripts/
│   └── install/
│       ├── qb438.sh             # qBittorrent 4.3.8 安装脚本
│       ├── qb439.sh             # qBittorrent 4.3.9 安装脚本
│       └── applications/
│           └── vertex.sh        # Vertex 安装脚本
└── configs/
    └── docker-compose/
        └── vertex.yml           # Vertex Docker Compose 配置
```

## 当前支持的应用

### 核心项目（已完成）

1. **qBittorrent 4.3.8** - 经典稳定版本（配合 libtorrent 1.2.20）
2. **qBittorrent 4.3.9** - 最新稳定版本（配合 libtorrent 1.2.20）
3. **qBittorrent 4.3.8 + Vertex** - 组合安装
4. **qBittorrent 4.3.9 + Vertex** - 组合安装

### 计划支持的应用

- 下载管理：Transmission
- 自动化管理：IYUUPlus, MoviePilot, Sonarr, Radarr
- 媒体服务器：Emby, Jellyfin, Plex
- 更多工具正在开发中...

## 使用说明

### 安装应用

1. 运行主脚本：`./pttools.sh`
2. 选择要安装的应用（输入对应数字）
3. 按照提示完成安装
4. 记录显示的访问地址和登录信息

### 默认配置

- Docker 安装路径：`/opt/docker`
- qBittorrent 配置路径：`/root/.config/qBittorrent`
- 下载目录：`/opt/downloads`
- qBittorrent Web UI 端口：8080
- qBittorrent BT 端口：25000
- Vertex 端口：3334
- 默认缓存大小：3072 MB

### 默认登录信息

- qBittorrent
  - 用户名：admin
  - 密码：adminadmin
  
- Vertex
  - 默认无需认证

**⚠️ 重要：请在首次登录后立即修改默认密码！**

### 管理命令

#### qBittorrent
```bash
systemctl start qbittorrent    # 启动
systemctl stop qbittorrent     # 停止
systemctl restart qbittorrent  # 重启
systemctl status qbittorrent   # 查看状态
journalctl -u qbittorrent -f   # 查看实时日志
```

#### Vertex
```bash
cd /opt/docker/vertex
docker-compose up -d           # 启动
docker-compose down            # 停止
docker-compose restart         # 重启
docker logs -f vertex          # 查看日志
```

### 服务诊断

脚本内置了服务诊断功能，可以快速检查服务状态：

1. 运行主脚本：`./pttools.sh`
2. 选择 "7. 服务诊断"
3. 查看各项服务状态和系统信息

## VPS 优化说明

脚本会自动应用以下优化：

1. **系统优化**
   - 启用 BBR 拥塞控制
   - 优化 TCP 参数
   - 增加文件描述符限制

2. **qBittorrent 优化**
   - 禁用不必要的功能
   - 优化缓存设置
   - 配置适合刷流的参数

3. **网络优化**
   - 自动配置防火墙规则
   - 优化连接数限制

## 技术细节

### 版本信息
- **libtorrent-rasterbar**: 1.2.20
- **qBittorrent**: 4.3.8 / 4.3.9
- **编译优化**: 启用加密，禁用调试

### 安装方式
本脚本采用了优化的安装方式：
1. **优先使用预编译版本**：大幅减少安装时间
2. **自动降级到编译安装**：当预编译版本不可用时
3. **优化的编译参数**：`-O3 -march=native` 提升性能

### 编译参数
- libtorrent: `--disable-debug --enable-encryption`
- qBittorrent: `--disable-gui --disable-debug`
- 编译优化: `CXXFLAGS="-O3 -march=native -pipe"`

### 性能优化
- **缓存优化**：默认 3GB 缓存，可根据内存调整
- **连接优化**：异步 IO 线程数设为 8
- **文件池**：500 个文件句柄
- **BBR 拥塞控制**：自动启用

## 卸载应用

1. 运行主脚本：`./pttools.sh`
2. 选择 "6. 卸载管理"
3. 选择要卸载的应用或全部卸载

## 故障排除

### 快速修复

如果遇到服务无法启动的问题，可以使用快速修复脚本：

```bash
wget -O fix.sh https://raw.githubusercontent.com/everett7623/PTtools/main/fix.sh && chmod +x fix.sh && ./fix.sh
```

### 常见问题

#### 1. 502 Bad Gateway 错误
- **原因**：qBittorrent 服务未正常启动
- **解决方案**：
  ```bash
  # 检查服务状态
  systemctl status qbittorrent
  
  # 查看错误日志
  journalctl -u qbittorrent -f
  
  # 重启服务
  systemctl restart qbittorrent
  ```

#### 2. Vertex 安装失败（404错误）
- **原因**：配置文件路径错误
- **解决方案**：使用最新版本的脚本（已修复）

#### 3. 提示权限不足
- 确保使用 root 用户或使用 sudo 运行脚本

#### 4. Docker 安装失败
- 检查网络连接
- 尝试使用阿里云镜像安装

#### 5. 无法访问 Web UI
- 检查防火墙设置
- 确认服务是否正常运行：`./pttools.sh` 选择 "7. 服务诊断"
- 检查端口是否被占用：`netstat -tuln | grep 8080`

#### 6. qBittorrent 编译失败
- 确保系统有足够的内存（至少 2GB）
- 检查是否安装了所有依赖
- 尝试使用预编译版本（新版脚本默认使用）

### 服务管理命令

## 贡献指南

欢迎提交 Issue 和 Pull Request！

### 开发新的安装脚本

1. 在 `scripts/install/` 目录下创建脚本
2. 在 `configs/docker-compose/` 目录下创建配置文件（如果需要）
3. 更新主脚本 `pttools.sh` 添加新选项
4. 测试并提交 PR

## 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。

## 免责声明

- 本脚本仅供学习和研究使用
- 使用本脚本造成的任何后果由使用者自行承担
- 请遵守当地法律法规和 PT 站点规则

## 致谢

- 感谢 [jerry048](https://github.com/jerry048/Dedicated-Seedbox) 的优秀脚本提供参考
- 感谢所有贡献者和使用者的支持！

---

**作者：** everett7623  
**GitHub：** https://github.com/everett7623/PTtools
