#!/bin/bash
# Vertex (Docker) 安装模块

# 确保脚本以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo "错误：此脚本必须以 root 权限运行。"
   exit 1
fi

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 日志函数，与主脚本保持一致
log_info() {
    echo -e "${GREEN}[信息]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}
log_warn() {
    echo -e "${YELLOW}[警告]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}
log_error() {
    echo -e "${RED}[错误]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
    exit 1 # 模块内部错误直接退出
}

# 参数: (qBittorrent版本, Docker基础路径)
# 目前 qb_version 在 Vertex 模块中可能未被使用，但保留以备将来扩展
QB_VERSION=${1:-"latest"}
DOCKER_PATH=${2:-"/opt/docker"} # 从主脚本传入 Docker 路径

log_info "正在安装 Vertex (Docker)..."
log_info "qBittorrent 版本 (参考): $QB_VERSION"
log_info "Docker 基础路径: $DOCKER_PATH"

VERTEX_APP_DIR="$DOCKER_PATH/vertex"
VERTEX_PORT="8000" # 默认 Vertex WebUI 端口

# 检查 Docker 是否运行
if ! systemctl is-active --quiet docker; then
    log_error "Docker 服务未运行，请确保 Docker 已正确安装并启动。"
fi

# 1. 创建 Vertex 目录
log_info ">> (1/3) 创建 Vertex 容器目录: $VERTEX_APP_DIR"
mkdir -p "$VERTEX_APP_DIR/config" || log_error "创建 Vertex 目录失败。"
chmod -R 777 "$VERTEX_APP_DIR" # 确保容器有权限写入

# 2. 生成 Docker Compose 文件
log_info ">> (2/3) 生成 Vertex Docker Compose 文件..."
cat <<DOCKER_COMPOSE > "$VERTEX_APP_DIR/docker-compose.yml"
version: '3.8'
services:
  vertex:
    image: everett7623/vertex:latest # 请确保此镜像存在且可访问
    container_name: vertex_app
    restart: always
    ports:
      - "${VERTEX_PORT}:${VERTEX_PORT}" # 映射 Vertex WebUI 端口
    volumes:
      - "${VERTEX_APP_DIR}/config:/app/config" # 配置文件持久化
      # 如果 Vertex 需要存储其他数据，可以添加更多卷映射
      # - "${VERTEX_APP_DIR}/data:/app/data"
    environment:
      # 根据 Vertex 镜像需求添加环境变量，例如：
      - TZ=Asia/Shanghai # 设置时区
      - VERTEX_PORT=${VERTEX_PORT} # 传递端口给容器内部
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
DOCKER_COMPOSE

if [ $? -ne 0 ]; then
    log_error "创建 Vertex Docker Compose 文件失败。"
fi
log_info "Vertex Docker Compose 文件已创建在: $VERTEX_APP_DIR/docker-compose.yml"

# 3. 部署并启动 Vertex 容器
log_info ">> (3/3) 部署并启动 Vertex Docker 容器..."
cd "$VERTEX_APP_DIR" || log_error "无法进入 Vertex 容器目录。"
docker compose up -d || log_error "启动 Vertex Docker 容器失败。请检查 Docker Compose 文件或日志。"

log_info "Vertex (Docker) 安装完成。您可以通过 http://您的服务器IP:$VERTEX_PORT 访问。"
