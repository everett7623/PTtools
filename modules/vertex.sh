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
# qb_version 在 Vertex 模块中可能未被使用，但保留以备将来扩展
# DOCKER_PATH 从主脚本传入 Docker 路径
QB_VERSION=${1:-"latest"}
DOCKER_BASE_PATH=${2:-"/opt/docker"} # 使用 DOCKER_BASE_PATH 来区分

log_info "正在安装 Vertex (Docker)..."
log_info "qBittorrent 版本 (参考): $QB_VERSION"
log_info "Docker 基础路径: $DOCKER_BASE_PATH"

# 根据您提供的参考，Vertex 的实际数据卷路径是 /opt/docker/vertex
# 所以这里定义 Vertex 应用的根目录
VERTEX_APP_DIR="$DOCKER_BASE_PATH/vertex"
VERTEX_HOST_PORT="3334" # 宿主机端口，用于外部访问
VERTEX_CONTAINER_PORT="3000" # 容器内部监听端口

# 检查 Docker 是否运行
if ! systemctl is-active --quiet docker; then
    log_error "Docker 服务未运行，请确保 Docker 已正确安装并启动。"
fi

# 1. 创建 Vertex 目录
log_info ">> (1/3) 创建 Vertex 容器目录: $VERTEX_APP_DIR"
# 根据您的配置，/opt/docker/vertex 既是宿主机的数据卷，也是 docker-compose.yml 所在目录
mkdir -p "$VERTEX_APP_DIR" || log_error "创建 Vertex 目录失败。"
chmod -R 777 "$VERTEX_APP_DIR" # 确保容器有权限写入

# 2. 生成 Docker Compose 文件
log_info ">> (2/3) 生成 Vertex Docker Compose 文件..."
cat <<DOCKER_COMPOSE > "$VERTEX_APP_DIR/docker-compose.yml"
version: '3.8'
services:
  vertex:
    image: lswl/vertex:stable # 使用您提供的镜像名称
    container_name: vertex     # 使用您提供的容器名称
    restart: unless-stopped    # 使用您提供的重启策略
    environment:
      - TZ=Asia/Shanghai       # 时区设置
      # 如果 Vertex 容器内部也需要知道它自己的端口，可以添加如下环境变量
      # - VERTEX_PORT=${VERTEX_CONTAINER_PORT} 
    volumes:
      - "${VERTEX_APP_DIR}:/vertex" # 宿主机路径:容器内部路径
    ports:
      - "${VERTEX_HOST_PORT}:${VERTEX_CONTAINER_PORT}" # 宿主机端口:容器内部端口
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
log_info "Vertex 将监听宿主机端口: ${VERTEX_HOST_PORT}"

# 3. 部署并启动 Vertex 容器
log_info ">> (3/3) 部署并启动 Vertex Docker 容器..."
cd "$VERTEX_APP_DIR" || log_error "无法进入 Vertex 容器目录: $VERTEX_APP_DIR"
docker compose up -d || log_error "启动 Vertex Docker 容器失败。请检查 Docker Compose 文件或日志。"

# ==== 添加 Vertex 登录信息提示 (直接打印密码版本) ====
echo
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}         Vertex 安装成功！重要提示           ${NC}"
echo -e "${GREEN}===============================================${NC}"
echo -e "${BLUE}Vertex WebUI 地址: ${YELLOW}http://您的服务器IP:${VERTEX_HOST_PORT}${NC}"
echo -e "${BLUE}默认登录用户名:     ${YELLOW}admin${NC}"

# 尝试读取并打印密码
PASSWORD_FILE="${VERTEX_APP_DIR}/data/password"
MAX_ATTEMPTS=10 # 尝试读取密码文件的最大次数
WAIT_SECONDS=3  # 每次尝试之间的等待时间

log_info "正在等待 Vertex 容器生成初始密码文件..."
for (( i=1; i<=MAX_ATTEMPTS; i++ )); do
    if [[ -f "$PASSWORD_FILE" ]]; then
        INITIAL_PASSWORD=$(cat "$PASSWORD_FILE")
        if [[ -n "$INITIAL_PASSWORD" ]]; then
            echo -e "${BLUE}您的初始登录密码是: ${RED}${INITIAL_PASSWORD}${NC}"
            echo -e "${YELLOW}警告: 此密码已直接显示在终端。请务必尽快登录 WebUI 修改密码！${NC}"
            break
        fi
    fi
    log_info "  (${i}/${MAX_ATTEMPTS}) 密码文件未生成或为空，等待 ${WAIT_SECONDS} 秒..."
    sleep "$WAIT_SECONDS"
done

if [[ ! -f "$PASSWORD_FILE" || -z "$INITIAL_PASSWORD" ]]; then
    log_warn "未能自动获取初始密码。这可能是由于容器仍在启动或密码文件生成延迟。"
    echo -e "${BLUE}请您手动查看初始登录密码，路径为:${YELLOW} ${PASSWORD_FILE}${NC}"
    echo -e "您可以使用以下命令查看:"
    echo -e "${YELLOW}  cat ${PASSWORD_FILE}${NC}"
    echo -e "如果文件不存在，请稍等片刻，等待容器完全启动并生成密码文件。"
fi

echo -e "${GREEN}===============================================${NC}"
echo
# ==================================
