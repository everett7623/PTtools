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

ROLLBACK_STACK=()

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

print_separator() {
    echo "========================================"
}

rb() {
    ROLLBACK_STACK+=("$*")
}

execute_rollback() {
    if [[ ${#ROLLBACK_STACK[@]} -gt 0 ]]; then
        log_info "正在执行回滚操作..."
        for (( i=${#ROLLBACK_STACK[@]}-1; i>=0; i-- )); do
            log_info "回滚: ${ROLLBACK_STACK[i]}"
            eval "${ROLLBACK_STACK[i]}" || true
        done
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行。"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=${VERSION_ID:-}
    else
        log_error "无法确定操作系统版本。"
        exit 1
    fi
    
    case "$OS" in
        ubuntu|debian)
            log_info "检测到操作系统: $OS $VER"
            ;;
        centos|rhel|fedora)
            log_info "检测到操作系统: $OS $VER"
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

check_dependencies() {
    local deps=("wget" "curl" "ss")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "缺少以下依赖: ${missing[*]}"
        install_apt_dependencies "${missing[@]}"
    fi

    if ! command -v docker &> /dev/null; then
        log_info "检测到 Docker 未安装，正在安装 Docker..."
        curl -fsSL https://get.docker.com | bash
        systemctl enable docker || log_warn "未能启用 Docker 服务。"
        systemctl start docker || log_warn "未能启动 Docker 服务。"
        rb "systemctl stop docker && systemctl disable docker && apt-get remove -y docker-ce docker-ce-cli containerd.io || true"
    else
        log_info "Docker 已安装。"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_info "检测到 Docker Compose 未安装，正在安装 Docker Compose..."
        local ARCH=$(uname -m)
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-${ARCH}" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        rb "rm -f /usr/local/bin/docker-compose"
    else
        log_info "Docker Compose 已安装。"
    fi
}

install_apt_dependencies() {
    log_info "正在安装 APT 依赖包: $*"
    case "$OS" in
        ubuntu|debian)
            apt-get update
            apt-get install -y "$@"
            ;;
        *)
            log_warn "当前操作系统不支持 APT 包管理器，跳过特定依赖安装。"
            ;;
    esac
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "正在加载配置文件: $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log_info "配置文件 $CONFIG_FILE 不存在，正在创建默认配置。"
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
    log_info "已在 $CONFIG_FILE 创建默认配置文件。"
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
DOCKER_PATH="${DOCKER_PATH}"
DOWNLOAD_PATH="${DOWNLOAD_PATH}"
SEEDBOX_USER="${SEEDBOX_USER}"
SEEDBOX_PASSWORD="${SEEDBOX_PASSWORD}"
WEBUI_PORT=${WEBUI_PORT}
DAEMON_PORT=${DAEMON_PORT}
PASSKEY="${PASSKEY}"
EOF
    log_info "配置已保存到 $CONFIG_FILE"
}

prompt_user() {
    local prompt="$1"
    local default="${2:-}"
    local response
    
    if [[ -n "$default" ]]; then
        read -p "$(echo -e "${BLUE}$prompt${NC} [${YELLOW}$default${NC}]: ")" response
        echo "${response:-$default}"
    else
        read -p "$(echo -e "${BLUE}$prompt${NC}: ")" response
        echo "$response"
    fi
}

prompt_password() {
    local prompt="$1"
    local password
    
    read -s -p "$(echo -e "${BLUE}$prompt${NC}: ")" password
    echo
    echo "$password"
}

validate_port() {
    local port="$1"
    local port_name="$2"

    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1024 || port > 65535 )); then
        log_error "无效的 ${port_name} 端口号: $port。端口必须是 1024 到 65535 之间的数字。"
        return 1
    fi
    
    if ss -tulwn | grep -q ":$port "; then
        log_warn "警告: ${port_name} 端口 $port 已经被占用。"
        read -p "您确定要使用此端口吗？(y/n): " confirm_port
        if [[ "$confirm_port" != "y" ]]; then
            return 1
        fi
    fi
    
    return 0
}

setup_docker_environment() {
    log_info "正在设置 Docker 环境目录..."
    
    mkdir -p "$DOCKER_PATH"
    chmod -R 777 "$DOCKER_PATH"

    mkdir -p "$DOWNLOAD_PATH"
    chmod -R 777 "$DOWNLOAD_PATH"
    
    local apps=("qbittorrent" "transmission" "emby" "iyuuplus" "moviepilot" "vertex" "nas-tools" "filebrowser" "metatube" "byte-muse")
    for app in "${apps[@]}"; do
        mkdir -p "$DOCKER_PATH/$app"
        log_info "已创建 Docker 应用目录: $DOCKER_PATH/$app"
    done
    
    log_info "Docker 环境设置完成。"
}

show_banner() {
    clear
    cat << 'EOF'
 ____  _____   _____         _    
|  _ \|_  __| |_  __|___  ___ | |___ 
| |_) | | |     | | / _ \/ _ \| / __|
|  __/  | |     | || (_) | (_) | \__ \
|_|     |_|     |_| \___/ \___/|_|___/
                                     
EOF
    echo -e "${BLUE}版本: ${NC}${SCRIPT_VERSION}"
    echo -e "${BLUE}作者: ${NC}everett7623"
    print_separator
}

show_main_menu() {
    show_banner
    echo "主菜单:"
    echo "1. 安装 qBittorrent 4.3.8"
    echo "2. 安装 qBittorrent 4.3.9"
    echo "3. 安装 qBittorrent 4.3.8 + Vertex"
    echo "4. 安装 qBittorrent 4.3.9 + Vertex"
    echo "5. 安装选定应用程序 (Docker Compose)"
    echo "6. VPS 优化 (针对 PT 流量)"
    echo "7. 卸载选项"
    echo "8. 退出"
    print_separator
    
    local choice
    read -p "请输入您的选择 [1-8]: " choice
    
    case "$choice" in
        1) install_qb_438 ;;
        2) install_qb_439 ;;
        3) install_qb_438_vertex_combo ;;
        4) install_qb_439_vertex_combo ;;
        5) show_app_selection_menu ;;
        6) optimize_vps ;;
        7) show_uninstall_menu ;;
        8) exit_script ;;
        *) 
            log_error "无效的选择，请重新输入。"
            sleep 2
            show_main_menu
            ;;
    esac
}

install_qb_438() {
    log_info "正在安装 qBittorrent 4.3.8..."
    
    SEEDBOX_USER=$(prompt_user "请输入 qBittorrent WebUI 用户名" "${SEEDBOX_USER}")
    SEEDBOX_PASSWORD=$(prompt_password "请输入 qBittorrent WebUI 密码")
    echo
    while [ -z "$SEEDBOX_PASSWORD" ]; do
        log_warn "密码不能为空，请重新输入。"
        SEEDBOX_PASSWORD=$(prompt_password "请输入 qBittorrent WebUI 密码")
    done
    
    WEBUI_PORT=$(prompt_user "请输入 qBittorrent WebUI 端口" "${WEBUI_PORT}")
    while ! validate_port "$WEBUI_PORT" "WebUI"; do
        WEBUI_PORT=$(prompt_user "请重新输入 qBittorrent WebUI 端口" "${WEBUI_PORT}")
    done

    DAEMON_PORT=$(prompt_user "请输入 qBittorrent BT 监听端口" "${DAEMON_PORT}")
    while ! validate_port "$DAEMON_PORT" "BT 监听"; do
        DAEMON_PORT=$(prompt_user "请重新输入 qBittorrent BT 监听端口" "${DAEMON_PORT}")
    done
    
    save_config
    
    log_info "正在下载并运行 qBittorrent 4.3.8 安装脚本..."
    if [[ -f "${SCRIPT_DIR}/scripts/install/qb438.sh" ]]; then
        log_info "使用本地脚本..."
        bash "${SCRIPT_DIR}/scripts/install/qb438.sh" "$SEEDBOX_USER" "$SEEDBOX_PASSWORD" "$WEBUI_PORT" "$DAEMON_PORT"
    else
        log_info "下载远程脚本..."
        bash <(wget -qO- "$GITHUB_RAW/scripts/install/qb438.sh") "$SEEDBOX_USER" "$SEEDBOX_PASSWORD" "$WEBUI_PORT" "$DAEMON_PORT"
    fi
    
    register_installation "qbittorrent" "4.3.8"
    log_info "qBittorrent 4.3.8 安装完成。"
    
    read -p "安装完成。按 Enter 返回主菜单..."
    show_main_menu
}

install_qb_439() {
    log_info "正在使用 Jerry's Script 安装 qBittorrent 4.3.9..."
    
    local username=$(prompt_user "请输入 qBittorrent 用户名" "${SEEDBOX_USER}")
    local password=$(prompt_password "请输入 qBittorrent 密码")
    while [ -z "$password" ]; do
        log_warn "密码不能为空，请重新输入。"
        password=$(prompt_password "请输入 qBittorrent 密码")
    done

    local cache_size=$(prompt_user "请输入缓存大小 (MiB)" "2048")
    local custom_port=$(prompt_user "请输入自定义 WebUI 端口 (留空使用默认)" "${WEBUI_PORT}")

    if [[ -f "${SCRIPT_DIR}/scripts/install/qb439.sh" ]]; then
        log_info "使用本地脚本..."
        bash "${SCRIPT_DIR}/scripts/install/qb439.sh" "$username" "$password" "$cache_size" "$custom_port"
    else
        local cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh)"
        cmd+=" -u $username -p $password -c $cache_size -q 4.3.9 -l v1.2.20"
        
        if [[ -n "$custom_port" ]]; then
            cmd+=" -o $custom_port"
        fi
        
        log_info "正在运行 Jerry's qBittorrent 4.3.9 安装脚本..."
        eval "$cmd"
    fi
    
    register_installation "qbittorrent" "4.3.9"
    log_info "qBittorrent 4.3.9 安装完成。"
    
    read -p "安装完成。按 Enter 返回主菜单..."
    show_main_menu
}

install_qb_438_vertex_combo() {
    log_info "正在安装 qBittorrent 4.3.8 + Vertex 组合..."
    
    SEEDBOX_USER=$(prompt_user "请输入 qBittorrent WebUI 用户名" "${SEEDBOX_USER}")
    SEEDBOX_PASSWORD=$(prompt_password "请输入 qBittorrent WebUI 密码")
    while [ -z "$SEEDBOX_PASSWORD" ]; do
        log_warn "密码不能为空，请重新输入。"
        SEEDBOX_PASSWORD=$(prompt_password "请输入 qBittorrent WebUI 密码")
    done
    WEBUI_PORT=$(prompt_user "请输入 qBittorrent WebUI 端口" "${WEBUI_PORT}")
    while ! validate_port "$WEBUI_PORT" "WebUI"; do
        WEBUI_PORT=$(prompt_user "请重新输入 qBittorrent WebUI 端口" "${WEBUI_PORT}")
    done
    DAEMON_PORT=$(prompt_user "请输入 qBittorrent BT 监听端口" "${DAEMON_PORT}")
    while ! validate_port "$DAEMON_PORT" "BT 监听"; do
        DAEMON_PORT=$(prompt_user "请重新输入 qBittorrent BT 监听端口" "${DAEMON_PORT}")
    done
    
    save_config
    setup_docker_environment

    log_info "正在安装 Vertex (Docker 版)..."
    install_vertex_builtin
    register_installation "vertex" "latest"

    log_info "正在安装 qBittorrent 4.3.8..."
    if [[ -f "${SCRIPT_DIR}/scripts/install/qb438.sh" ]]; then
        bash "${SCRIPT_DIR}/scripts/install/qb438.sh" "$SEEDBOX_USER" "$SEEDBOX_PASSWORD" "$WEBUI_PORT" "$DAEMON_PORT"
    else
        bash <(wget -qO- "$GITHUB_RAW/scripts/install/qb438.sh") "$SEEDBOX_USER" "$SEEDBOX_PASSWORD" "$WEBUI_PORT" "$DAEMON_PORT"
    fi
    register_installation "qbittorrent" "4.3.8"
    
    log_info "qBittorrent 4.3.8 + Vertex 组合安装完成。"
    read -p "安装完成。按 Enter 返回主菜单..."
    show_main_menu
}

install_qb_439_vertex_combo() {
    log_info "正在安装 qBittorrent 4.3.9 (Jerry's) + Vertex 组合..."
    
    local username=$(prompt_user "请输入 qBittorrent 用户名" "${SEEDBOX_USER}")
    local password=$(prompt_password "请输入 qBittorrent 密码")
    while [ -z "$password" ]; do
        log_warn "密码不能为空，请重新输入。"
        password=$(prompt_password "请输入 qBittorrent 密码")
    done
    local cache_size=$(prompt_user "请输入缓存大小 (MiB)" "2048")
    local custom_port=$(prompt_user "请输入自定义 WebUI 端口 (留空使用默认)" "${WEBUI_PORT}")

    SEEDBOX_USER="$username"
    SEEDBOX_PASSWORD="$password"
    if [[ -n "$custom_port" ]]; then WEBUI_PORT="$custom_port"; fi
    save_config
    setup_docker_environment

    log_info "正在安装 Vertex (Docker 版)..."
    install_vertex_builtin
    register_installation "vertex" "latest"

    log_info "正在安装 qBittorrent 4.3.9..."
    if [[ -f "${SCRIPT_DIR}/scripts/install/qb439.sh" ]]; then
        bash "${SCRIPT_DIR}/scripts/install/qb439.sh" "$username" "$password" "$cache_size" "$custom_port"
    else
        local cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh)"
        cmd+=" -u $username -p $password -c $cache_size -q 4.3.9 -l v1.2.20"
        if [[ -n "$custom_port" ]]; then
            cmd+=" -o $custom_port"
        fi
        eval "$cmd"
    fi
    register_installation "qbittorrent" "4.3.9"

    log_info "qBittorrent 4.3.9 + Vertex 组合安装完成。"
    read -p "安装完成。按 Enter 返回主菜单..."
    show_main_menu
}

install_vertex_builtin() {
    log_info "使用内置方法安装 Vertex..."
    mkdir -p "${DOCKER_PATH}/vertex"
    
    if ss -tulnp | grep ":3334 " > /dev/null 2>&1; then
        VERTEX_PORT=3335
        log_warn "端口3334被占用，使用3335端口"
    else
        VERTEX_PORT=3334
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
      - "${VERTEX_PORT}:3000"
    restart: unless-stopped
EOF
    
    cd "${DOCKER_PATH}/vertex"
    if docker-compose up -d; then
        sleep 5
        if docker ps | grep vertex > /dev/null; then
            log_info "Vertex安装成功，访问地址: http://your-server-ip:${VERTEX_PORT}"
        else
            log_error "Vertex容器启动失败"
        fi
    else
        log_error "Vertex安装失败"
    fi
}

show_app_selection_menu() {
    show_banner
    echo "选择要安装的应用程序 (Docker Compose):"
    echo
    echo "下载管理:"
    echo "  1. qBittorrent (Docker)"
    echo "  2. Transmission (Docker)"
    echo
    echo "自动化工具:"
    echo "  3. IYUUPlus (Docker)"
    echo "  4. MoviePilot (Docker)"
    echo "  5. Vertex (Docker)"
    echo "  6. NAS-Tools (Docker)"
    echo
    echo "媒体服务器:"
    echo "  7. Emby (Docker)"
    echo
    echo "文件管理:"
    echo "  8. FileBrowser (Docker)"
    echo
    echo "特殊工具:"
    echo "  9. MetaTube (Docker)"
    echo "  10. Byte-Muse (Docker)"
    echo
    echo "0. 返回主菜单"
    print_separator
    
    echo "请输入用空格分隔的数字 (例如: 1 3 5): "
    read -a selections
    
    if [[ "${selections[0]}" == "0" ]]; then
        show_main_menu
        return
    fi
    
    local selected_apps=()
    for sel in "${selections[@]}"; do
        case "$sel" in
            1) selected_apps+=("qbittorrent") ;;
            2) selected_apps+=("transmission") ;;
            3) selected_apps+=("iyuuplus") ;;
            4) selected_apps+=("moviepilot") ;;
            5) selected_apps+=("vertex") ;;
            6) selected_apps+=("nas-tools") ;;
            7) selected_apps+=("emby") ;;
            8) selected_apps+=("filebrowser") ;;
            9) selected_apps+=("metatube") ;;
            10) selected_apps+=("byte-muse") ;;
            *) log_warn "无效的选择: $sel，已忽略。" ;;
        esac
    done
    
    if [[ ${#selected_apps[@]} -gt 0 ]]; then
        install_docker_apps "${selected_apps[@]}"
    else
        log_error "没有进行有效的应用程序选择。"
    fi
    
    read -p "按 Enter 键继续..."
    show_main_menu
}

install_docker_apps() {
    local apps=("$@")
    
    log_info "正在安装选定的 Docker 应用程序: ${apps[*]}"
    
    setup_docker_environment
    
    log_info "正在生成 docker-compose.yml 文件..."
    create_basic_compose "${apps[@]}"
    
    log_info "正在启动 Docker 容器..."
    cd "$DOCKER_PATH" || log_error "无法进入 Docker 目录 $DOCKER_PATH"
    docker-compose up -d
    
    for app in "${apps[@]}"; do
        register_installation "$app" "latest"
    done
    
    log_info "Docker 应用程序安装完成。"
}

create_basic_compose() {
    local apps=("$@")
    
    cat > "$DOCKER_PATH/docker-compose.yml" << 'EOF'
version: '3.8'
services:
EOF
    
    for app in "${apps[@]}"; do
        case "$app" in
            "vertex")
                cat >> "$DOCKER_PATH/docker-compose.yml" << 'EOF'
  vertex:
    image: lswl/vertex:stable
    container_name: vertex
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - /opt/docker/vertex:/vertex
    ports:
      - "3334:3000"
    restart: unless-stopped
EOF
                ;;
        esac
    done
}

optimize_vps() {
    log_info "正在开始 VPS 优化 (针对 PT 流量)..."
    
    if ! lsmod | grep -q bbr; then
        echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
        echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
        sysctl -p
    fi
    
    cat >> /etc/sysctl.conf << 'EOF'

net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
fs.file-max = 2097152
EOF
    
    sysctl -p
    
    cat >> /etc/security/limits.conf << 'EOF'

* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF
    
    log_info "VPS 优化完成。"
    read -p "按 Enter 键继续..."
    show_main_menu
}

show_uninstall_menu() {
    show_banner
    echo "卸载选项:"
    echo "1. 移除特定应用程序"
    echo "2. 移除所有 PT 工具"
    echo "3. 移除所有 Docker 容器"
    echo "4. 完整系统清理 (慎用！)"
    echo "5. 返回主菜单"
    print_separator
    
    local choice
    read -p "请输入您的选择 [1-5]: " choice
    
    case "$choice" in
        1) selective_uninstall ;;
        2) remove_all_pt_tools ;;
        3) remove_docker_environment ;;
        4) complete_system_cleanup ;;
        5) show_main_menu ;;
        *) 
            log_error "无效的选择，请重新输入。"
            sleep 2
            show_uninstall_menu
            ;;
    esac
}

selective_uninstall() {
    list_installed_tools
    read -p "请输入要卸载的应用名称: " app_name
    if [[ -n "$app_name" ]]; then
        docker stop "$app_name" 2>/dev/null || true
        docker rm "$app_name" 2>/dev/null || true
        rm -rf "${DOCKER_PATH}/$app_name" 2>/dev/null || true
        log_info "$app_name 卸载完成"
    fi
    read -p "按 Enter 键继续..."
    show_uninstall_menu
}

remove_all_pt_tools() {
    log_warn "此操作将移除所有 PT 工具，包括 qBittorrent、Vertex 等。"
    read -p "您确定要继续吗？(yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        log_info "使用内置清理方式..."
        docker stop $(docker ps -q) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        rm -rf "$DOCKER_PATH" 2>/dev/null || true
        log_info "PT工具清理完成"
    else
        log_info "已取消移除所有 PT 工具。"
    fi
    
    read -p "按 Enter 键继续..."
    show_uninstall_menu
}

remove_docker_environment() {
    log_warn "此操作将移除所有 Docker 容器、镜像和网络。谨慎操作！"
    read -p "您确定要继续吗？(yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        log_info "使用内置Docker清理..."
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        docker rmi $(docker images -aq) 2>/dev/null || true
        docker network prune -f 2>/dev/null || true
        docker volume prune -f 2>/dev/null || true
        log_info "Docker环境清理完成"
    else
        log_info "已取消移除 Docker 环境。"
    fi
    
    read -p "按 Enter 键继续..."
    show_uninstall_menu
}

complete_system_cleanup() {
    log_warn "此操作将移除所有工具、Docker 环境，并尝试还原系统更改。这是最终清理选项，请务必谨慎！"
    read -p "您确定要继续吗？请输入 'yes' 以确认: " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        log_info "执行完整清理..."
        remove_all_pt_tools
        remove_docker_environment
        rm -rf /etc/pttools 2>/dev/null || true
        rm -f /var/log/pttools-install.log 2>/dev/null || true
        log_info "完整清理完成"
    else
        log_info "已取消完整系统清理。"
    fi
    
    read -p "按 Enter 键继续..."
    show_uninstall_menu
}

register_installation() {
    local app_name="$1"
    local version="$2"
    local install_path="${3:-$DOCKER_PATH/$app_name}"
    
    mkdir -p /etc/pttools
    
    echo "$app_name|$version|$install_path|$(date '+%Y-%m-%d %H:%M:%S')" >> /etc/pttools/installed.list
    log_info "已注册安装: $app_name (版本: $version, 路径: $install_path)"
}

list_installed_tools() {
    if [[ -f /etc/pttools/installed.list ]]; then
        log_info "已安装工具列表:"
        cat /etc/pttools/installed.list
    else
        log_info "没有找到已安装工具的记录。"
    fi
}

exit_script() {
    log_info "正在退出 PT Tools 安装器..."
    exit 0
}

main() {
    check_root
    check_os
    
    mkdir -p "$(dirname "$INSTALLATION_LOG")"
    
    log_info "正在启动 PT Tools 安装脚本 v$SCRIPT_VERSION"
    
    load_config
    check_dependencies
    show_main_menu
}

main "$@"
