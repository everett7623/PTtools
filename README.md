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
│       └── applications
