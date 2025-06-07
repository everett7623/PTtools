#!/bin/bash
# PT 工具安装脚本
# 作者: everett7623
# 版本: 1.0.0

set -e

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_RAW="https://raw.githubusercontent.com/everett7623/PTtools/main"

DEFAULT_DOCKER_PATH="/opt/docker"
DEFAULT_DOWNLOAD_PATH="/opt/downloads"
INSTALLATION_LOG="/var/log/pttools-install.log"
CONFIG_FILE="/etc/pttools/config.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$(dirname "$INSTALLATION_LOG")"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$INSTALLATION_LOG"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$INSTALLATION_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$INSTALLATION_LOG"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=${VERSION_ID:-}
        log_info "检测到操作系统: $OS $VER"
    else
        log_error "无法确定操作系统版本"
        exit 1
    fi
}

install_dependencies() {
    log_info "检查基础依赖..."
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y wget curl iproute2
    elif command -v yum >/dev/null 2>&1; then
        yum install -y wget curl iproute
    else
        log_warn "未知的包管理器，请手动安装 wget curl"
    fi
}

install_docker() {
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker已安装"
        systemctl start docker || true
        return 0
    fi
    
    log_info "正在安装Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        local ARCH=$(uname -m)
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-${ARCH}" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    log_info "Docker安装完成"
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "加载配置文件: $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log_info "创建默认配置"
        create_default_config
    fi
}

create_default_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << 'EOF'
DOCKER_PATH="/opt/docker"
DOWNLOAD_PATH="/opt/downloads"
SEEDBOX_USER="admin"
SEEDBOX_PASSWORD="adminadmin"
WEBUI_PORT=8080
DAEMON_PORT=23333
PASSKEY=""
EOF
    log_info "默认配置已创建: $CONFIG_FILE"
}

prompt_user() {
    local prompt="$1"
    local default="${2:-}"
    local response
    
    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " response
        echo "${response:-$default}"
    else
        read -p "$prompt: " response
        echo "$response"
    fi
}

prompt_password() {
    local prompt="$1"
    local password
    read -s -p "$prompt: " password
    echo
    echo "$password"
}

validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1024 ]] && [[ $port -le 65535 ]]; then
        return 0
    else
        return 1
    fi
}

setup_docker_environment() {
    log_info "设置Docker环境..."
    mkdir -p "$DOCKER_PATH"
    mkdir -p "$DOWNLOAD_PATH"
    chmod 755 "$DOCKER_PATH" "$DOWNLOAD_PATH"
    
    local apps=("qbittorrent" "transmission" "emby" "iyuuplus" "moviepilot" "vertex")
    for app in "${apps[@]}"; do
        mkdir -p "$DOCKER_PATH/$app"
    done
    
    log_info "Docker环境设置完成"
}

show_banner() {
    clear
    echo "=============================="
    echo "    PTtools v${SCRIPT_VERSION}"
    echo "    PT工具一键安装脚本"
    echo "    作者: everett7623"
    echo "=============================="
}

show_main_menu() {
    show_banner
    echo
    echo "主菜单:"
    echo "1. 安装 qBittorrent 4.3.8"
    echo "2. 安装 qBittorrent 4.3.9"
    echo "3. 安装 qBittorrent 4.3.8 + Vertex"
    echo "4. 安装 qBittorrent 4.3.9 + Vertex"
    echo "5. 安装应用程序 (Docker)"
    echo "6. VPS 优化"
    echo "7. 系统状态"
    echo "8. 退出"
    echo
    
    read -p "请选择 [1-8]: " choice
    
    case "$choice" in
        1) install_qb_438 ;;
        2) install_qb_439 ;;
        3) install_qb_438_vertex ;;
        4) install_qb_439_vertex ;;
        5) install_docker_apps ;;
        6) optimize_vps ;;
        7) show_status ;;
        8) exit_script ;;
        *) 
            log_error "无效选择"
            sleep 2
            show_main_menu
            ;;
    esac
}

install_qb_438() {
    log_info "安装 qBittorrent 4.3.8..."
    
    local username=$(prompt_user "qBittorrent用户名" "${SEEDBOX_USER:-admin}")
    local password=$(prompt_password "qBittorrent密码")
    while [[ -z "$password" ]]; do
        log_warn "密码不能为空"
        password=$(prompt_password "qBittorrent密码")
    done
    
    local webui_port=$(prompt_user "WebUI端口" "${WEBUI_PORT:-8080}")
    while ! validate_port "$webui_port"; do
        webui_port=$(prompt_user "请输入有效端口(1024-65535)" "8080")
    done
    
    local daemon_port=$(prompt_user "BT监听端口" "${DAEMON_PORT:-23333}")
    while ! validate_port "$daemon_port"; do
        daemon_port=$(prompt_user "请输入有效端口(1024-65535)" "23333")
    done
    
    log_info "开始安装qBittorrent 4.3.8..."
    
    if [[ -f "${SCRIPT_DIR}/scripts/install/qb438.sh" ]]; then
        log_info "使用本地脚本"
        bash "${SCRIPT_DIR}/scripts/install/qb438.sh" "$username" "$password" "$webui_port" "$daemon_port"
    else
        log_info "下载远程脚本"
        bash <(wget -qO- "$GITHUB_RAW/scripts/install/qb438.sh") "$username" "$password" "$webui_port" "$daemon_port"
    fi
    
    log_info "qBittorrent 4.3.8 安装完成"
    read -p "按Enter继续..."
    show_main_menu
}

install_qb_439() {
    log_info "安装 qBittorrent 4.3.9..."
    
    local username=$(prompt_user "qBittorrent用户名" "${SEEDBOX_USER:-admin}")
    local password=$(prompt_password "qBittorrent密码")
    while [[ -z "$password" ]]; do
        log_warn "密码不能为空"
        password=$(prompt_password "qBittorrent密码")
    done
    
    local cache_size=$(prompt_user "缓存大小(MiB)" "2048")
    local custom_port=$(prompt_user "自定义端口(可选)" "")
    
    log_info "开始安装qBittorrent 4.3.9..."
    
    if [[ -f "${SCRIPT_DIR}/scripts/install/qb439.sh" ]]; then
        log_info "使用本地脚本"
        bash "${SCRIPT_DIR}/scripts/install/qb439.sh" "$username" "$password" "$cache_size" "$custom_port"
    else
        log_info "使用Jerry's Script"
        local cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh)"
        cmd+=" -u $username -p $password -c $cache_size -q 4.3.9 -l v1.2.20"
        if [[ -n "$custom_port" ]]; then
            cmd+=" -o $custom_port"
        fi
        eval "$cmd"
    fi
    
    log_info "qBittorrent 4.3.9 安装完成"
    read -p "按Enter继续..."
    show_main_menu
}

install_vertex() {
    log_info "安装Vertex..."
    setup_docker_environment
    
    mkdir -p "${DOCKER_PATH}/vertex"
    
    local vertex_port=3334
    if ss -tulnp | grep ":3334 " >/dev/null 2>&1; then
        vertex_port=3335
        log_warn "端口3334被占用，使用3335"
    fi
    
    cat > "${DOCKER_PATH}/vertex/docker-compose.yml" << EOF
version: '3.8'
services:
  vertex:
    image: lswl/vertex:stable
    container_name: vertex
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ${DOCKER_PATH}/vertex:/vertex
    ports:
      - "${vertex_port}:3000"
    restart: unless-stopped
EOF
    
    cd "${DOCKER_PATH}/vertex"
    docker-compose up -d
    
    if docker ps | grep vertex >/dev/null; then
        log_info "Vertex安装成功，端口: $vertex_port"
    else
        log_error "Vertex安装失败"
    fi
}

install_qb_438_vertex() {
    install_qb_438
    install_vertex
}

install_qb_439_vertex() {
    install_qb_439
    install_vertex
}

install_docker_apps() {
    log_info "Docker应用安装功能开发中..."
    read -p "按Enter继续..."
    show_main_menu
}

optimize_vps() {
    log_info "开始VPS优化..."
    
    if ! lsmod | grep -q bbr; then
        echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
        echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
        sysctl -p
    fi
    
    cat >> /etc/sysctl.conf << 'EOF'

net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
fs.file-max = 2097152
EOF
    
    sysctl -p
    
    cat >> /etc/security/limits.conf << 'EOF'

* soft nofile 65536
* hard nofile 65536
EOF
    
    log_info "VPS优化完成"
    read -p "按Enter继续..."
    show_main_menu
}

show_status() {
    clear
    echo "系统状态："
    echo "===================="
    
    if command -v docker >/dev/null 2>&1; then
        echo "✓ Docker已安装"
        if systemctl is-active --quiet docker; then
            echo "✓ Docker服务运行中"
        else
            echo "✗ Docker服务未运行"
        fi
    else
        echo "✗ Docker未安装"
    fi
    
    if command -v qbittorrent-nox >/dev/null 2>&1; then
        echo "✓ qBittorrent已安装"
    else
        echo "✗ qBittorrent未安装"
    fi
    
    if command -v docker >/dev/null 2>&1; then
        echo
        echo "运行中的容器："
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "无运行容器"
    fi
    
    echo
    read -p "按Enter返回主菜单..."
    show_main_menu
}

exit_script() {
    log_info "退出PTtools"
    exit 0
}

main() {
    check_root
    check_os
    install_dependencies
    load_config
    install_docker
    show_main_menu
}

main "$@"
