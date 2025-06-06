# PTtools 项目结构

```
pttools/
├── pttools.sh                  # 主安装脚本
├── check_requirements.sh       # 系统需求检查脚本
├── README.md                   # 项目说明文档
├── LICENSE                     # MIT 许可证
├── .gitignore                 # Git 忽略文件
│
├── modules/                    # 功能模块目录
│   ├── install_vertex.sh      # Vertex 安装模块
│   ├── generate_compose.sh    # Docker Compose 生成模块
│   ├── vps_optimize.sh        # VPS 优化模块
│   └── uninstall.sh           # 卸载模块
│
├── configs/                    # 配置文件模板
│   ├── qbittorrent.conf       # qBittorrent 配置模板
│   ├── vertex.yml             # Vertex 配置模板
│   └── docker-compose.yml     # Docker Compose 模板
│
├── scripts/                    # 辅助脚本
│   ├── backup.sh              # 备份脚本
│   ├── restore.sh             # 恢复脚本
│   └── update.sh              # 更新脚本
│
└── docs/                       # 文档目录
    ├── installation.md         # 安装指南
    ├── configuration.md        # 配置指南
    ├── troubleshooting.md      # 故障排除
    └── development.md          # 开发指南
```

## 运行时目录结构

安装后会创建以下目录：

```
/opt/docker/                    # Docker 应用主目录
├── qbittorrent/               # qBittorrent 数据
│   ├── config/                # 配置文件
│   └── data/                  # 应用数据
├── transmission/              # Transmission 数据
├── emby/                      # Emby 数据
├── vertex/                    # Vertex 数据
├── downloads/                 # 统一下载目录
└── docker-compose.yml         # Docker Compose 配置

/etc/pttools/                  # PTtools 配置目录
├── config.conf                # 主配置文件
├── installed.list             # 已安装应用列表
└── backups/                   # 配置备份

/var/log/                      # 日志目录
└── pttools-install.log        # 安装日志
```

## 配置文件说明

### /etc/pttools/config.conf
```bash
# PTtools 主配置文件
DOCKER_PATH="/opt/docker"
DOWNLOAD_PATH="/opt/downloads"
SEEDBOX_USER="admin"
SEEDBOX_PASSWORD="adminadmin"
WEBUI_PORT=8080
DAEMON_PORT=23333
```

### /etc/pttools/installed.list
```
# 格式：应用名|版本|安装路径|安装时间
qbittorrent|4.3.8|/opt/docker/qbittorrent|2024-01-01 12:00:00
vertex|latest|/opt/docker/vertex|2024-01-01 12:05:00
```

## 模块接口规范

每个模块脚本应该：
1. 接受标准参数
2. 返回标准退出码（0=成功，非0=失败）
3. 输出日志到标准输出
4. 支持独立运行

示例：
```bash
# 模块调用
bash modules/install_vertex.sh "4.3.8" "/opt/docker"
```

## 开发规范

1. **脚本头部**：包含描述、作者、版本信息
2. **错误处理**：使用 `set -euo pipefail`
3. **日志记录**：统一使用 log_info/log_warn/log_error
4. **回滚机制**：所有修改操作需要注册回滚
5. **配置管理**：使用统一的配置文件格式
