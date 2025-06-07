#!/bin/bash

# PTtools Script
# Author: everett7623
# GitHub: https://github.com/everett7623/PTtools

# Script Initialization and Configuration
PTTOOLS_GITHUB_RAW="https://raw.githubusercontent.com/everett7623/PTtools/main"
DOCKER_APP_DIR="/opt/docker"
DEFAULT_DOWNLOAD_DIR="/opt/downloads"
LOG_FILE="/var/log/pttools.log"
ARCH=$(uname -m)

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Redirect stdout and stderr to log file and console
exec > >(tee -a "$LOG_FILE") 2>&1

log_message() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

print_info() {
    log_message "${BLUE}[INFO] $1${NC}"
}

print_success() {
    log_message "${GREEN}[SUCCESS] $1${NC}"
}

print_warning() {
    log_message "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    log_message "${RED}[ERROR] $1${NC}"
    read -p "按回车键继续..."
}

# --- Utility Functions ---

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本必须以root用户运行，请使用 sudo su 或者 sudo bash <(wget ...) 运行。"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
    else
        print_error "无法识别的操作系统。此脚本仅支持Debian/Ubuntu系列。"
        exit 1
    fi

    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        print_error "此脚本仅支持Ubuntu/Debian系列操作系统。"
        exit 1
    fi
}

# --- Docker & Docker Compose Management ---

install_docker_and_compose() {
    print_info "检查Docker和Docker Compose安装状态..."

    if ! command -v docker &> /dev/null; then
        print_warning "Docker未安装。"
        read -p "是否安装Docker? (y/n): " confirm_docker_install
        if [[ "$confirm_docker_install" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}选择Docker安装镜像源:${NC}"
            echo "1. 官方源 (推荐国外VPS)"
            echo "2. 阿里云镜像 (推荐国内VPS)"
            read -p "请输入选择 (1/2): " docker_mirror_choice

            if [[ "$docker_mirror_choice" == "2" ]]; then
                print_info "使用阿里云镜像安装Docker..."
                curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            else
                print_info "使用官方源安装Docker..."
                curl -fsSL https://get.docker.com | bash -s docker
            fi

            if [[ $? -ne 0 ]]; then
                print_error "Docker安装失败，请检查网络或日志。"
                return 1
            fi
            print_success "Docker安装成功。"
        else
            print_error "Docker未安装，部分功能可能无法使用。"
            return 1
        fi
    else
        print_success "Docker已安装。"
    fi

    if ! command -v docker compose &> /dev/null; then
        print_warning "Docker Compose插件未安装。"
        print_info "正在安装Docker Compose插件..."
        DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
        mkdir -p $DOCKER_CONFIG/cli-plugins
        curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o $DOCKER_CONFIG/cli-plugins/docker-compose
        chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
        if [[ $? -ne 0 ]]; then
            print_error "Docker Compose插件安装失败。"
            return 1
        fi
        print_success "Docker Compose插件安装成功。"
    else
        print_success "Docker Compose插件已安装。"
    fi

    print_info "将当前用户添加到docker用户组..."
    sudo usermod -aG docker "$USER"
    print_success "请注销并重新登录您的SSH会话，以使docker组更改生效。"
    return 0
}

# --- Environment Setup ---

setup_environment() {
    print_info "创建默认下载目录: $DEFAULT_DOWNLOAD_DIR"
    mkdir -p "$DEFAULT_DOWNLOAD_DIR"
    chmod -R 777 "$DEFAULT_DOWNLOAD_DIR" # 用户要求777权限

    print_info "创建Docker应用目录: $DOCKER_APP_DIR"
    mkdir -p "$DOCKER_APP_DIR"
    chmod -R 777 "$DOCKER_APP_DIR" # 用户要求777权限

    print_info "应用VPS系统优化参数 (sysctl)..."
    cat <<EOF | sudo tee -a /etc/sysctl.conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
fs.file-max = 6553500
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 60
EOF
    sudo sysctl -p

    print_success "基础环境和系统优化已设置完成。"
}

# --- Application Installation Functions ---

install_qbittorrent() {
    local version=$1
    local bin_url
    local arch_suffix

    if [[ "$ARCH" == "x86_64" ]]; then
        arch_suffix="x86_64"
    elif [[ "$ARCH" == "aarch64" ]]; then
        arch_suffix="aarch64"
    else
        print_error "不支持的系统架构: $ARCH. qBittorrent安装失败。"
        return 1
    fi

    print_info "开始安装 qBittorrent-nox $version..."

    # Check if qbittorrent-nox is already running or installed
    if systemctl is-active --quiet qbittorrent-nox; then
        print_warning "检测到 qBittorrent-nox 服务已运行。请先手动停止或卸载现有版本再安装。"
        return 1
    fi
    if command -v qbittorrent-nox &> /dev/null; then
        print_warning "检测到 qBittorrent-nox 已安装。请先手动卸载现有版本再安装。"
        return 1
    fi

    # Download URL based on version
    case "$version" in
        "4.3.8")
            bin_url="https://github.com/rampageX/qb-nox-static-cc/releases/download/4.3.8/qbittorrent-nox_static_libtorrent1.2.14_openssl1.1.1k_${arch_suffix}.tar.gz"
            ;;
        "4.3.9")
            bin_url="https://github.com/userdocs/qbittorrent-nox-static-legacy/releases/download/v4.3.9/qbittorrent-nox_static_libtorrent1.2.14_openssl1.1.1k_${arch_suffix}.tar.gz"
            ;;
        *)
            print_error "不支持的qBittorrent版本: $version"
            return 1
            ;;
    esac

    # Create qbittorrent user
    if ! id -u qbittorrent-nox &> /dev/null; then
        print_info "创建 qbittorrent-nox 系统用户..."
        sudo useradd -rs /bin/false qbittorrent-nox
    else
        print_info "用户 qbittorrent-nox 已存在。"
    fi

    print_info "下载 qBittorrent-nox $version 二进制文件..."
    cd /tmp
    wget -q --show-progress "$bin_url"
    if [[ $? -ne 0 ]]; then
        print_error "qBittorrent $version 二进制文件下载失败。请检查URL或网络。"
        return 1
    fi

    print_info "解压并安装 qBittorrent-nox $version..."
    tar -xzf "$(basename "$bin_url")"
    sudo mv "qbittorrent-nox_static" /usr/local/bin/qbittorrent-nox
    sudo chmod +x /usr/local/bin/qbittorrent-nox
    sudo chown qbittorrent-nox:qbittorrent-nox /usr/local/bin/qbittorrent-nox

    # Create systemd service file
    print_info "创建 qBittorrent-nox systemd 服务..."
    cat <<EOF | sudo tee /etc/systemd/system/qbittorrent-nox.service
[Unit]
Description=qBittorrent Command Line Client
After=network.target

[Service]
ExecStart=/usr/local/bin/qbittorrent-nox --webui-port=8080 --profile=/home/qbittorrent-nox/.config/qBittorrent
User=qbittorrent-nox
Group=qbittorrent-nox
UMask=002
Restart=on-failure
WorkingDirectory=/home/qbittorrent-nox
ExecStop=/usr/bin/pkill -u qbittorrent-nox

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable qbittorrent-nox
    sudo systemctl start qbittorrent-nox

    if systemctl is-active --quiet qbittorrent-nox; then
        print_success "qBittorrent-nox $version 安装并启动成功。"
        print_info "WebUI 地址: http://您的VPS_IP:8080"
        print_info "默认用户名: admin"
        print_info "默认密码: adminadmin"
    else
        print_error "qBittorrent-nox $version 服务启动失败。请检查日志：sudo journalctl -u qbittorrent-nox"
        return 1
    fi

    print_info "清理临时文件..."
    rm -f "/tmp/$(basename "$bin_url")" "/tmp/qbittorrent-nox_static"
    return 0
}

install_vertex() {
    print_info "开始安装 Vertex (Docker Compose)..."
    mkdir -p "$DOCKER_APP_DIR/vertex"
    local vertex_compose_path="$DOCKER_APP_DIR/vertex/docker-compose.yaml"

    print_info "下载 Vertex Docker Compose 配置..."
    wget -qO "$vertex_compose_path" "$PTTOOLS_GITHUB_RAW/configs/docker-compose/vertex.yaml"
    if [[ $? -ne 0 ]]; then
        print_error "Vertex Docker Compose 配置下载失败。请检查URL或网络。"
        return 1
    fi

    print_info "启动 Vertex 容器..."
    cd "$DOCKER_APP_DIR/vertex"
    docker compose up -d
    if [[ $? -ne 0 ]]; then
        print_error "Vertex 容器启动失败。请检查日志。"
        return 1
    fi

    print_success "Vertex 安装并启动成功。"
    print_info "Vertex WebUI 地址: http://您的VPS_IP:3334"
    return 0
}

# --- Combined Installation Functions ---

install_qb_and_vertex() {
    local qb_version=$1
    print_info "开始安装 qBittorrent $qb_version + Vertex..."
    if install_qbittorrent "$qb_version" && install_vertex; then
        print_success "qBittorrent $qb_version 和 Vertex 已成功安装。"
    else
        print_error "qBittorrent $qb_version 或 Vertex 安装失败。"
        return 1
    fi
}

# --- Uninstallation Functions ---

uninstall_qbittorrent() {
    print_info "开始卸载 qBittorrent-nox..."
    if systemctl is-active --quiet qbittorrent-nox; then
        sudo systemctl stop qbittorrent-nox
        sudo systemctl disable qbittorrent-nox
        print_info "qBittorrent-nox 服务已停止并禁用。"
    else
        print_warning "qBittorrent-nox 服务未运行。"
    fi

    if [[ -f /etc/systemd/system/qbittorrent-nox.service ]]; then
        sudo rm /etc/systemd/system/qbittorrent-nox.service
        sudo systemctl daemon-reload
        print_info "qBittorrent-nox systemd 服务文件已移除。"
    fi

    if [[ -f /usr/local/bin/qbittorrent-nox ]]; then
        sudo rm /usr/local/bin/qbittorrent-nox
        print_info "qBittorrent-nox 二进制文件已移除。"
    fi

    if id -u qbittorrent-nox &> /dev/null; then
        sudo userdel qbittorrent-nox
        print_info "qBittorrent-nox 用户已移除。"
    fi

    if [[ -d /home/qbittorrent-nox/.config/qBittorrent ]]; then
        print_info "移除 qBittorrent 配置目录..."
        sudo rm -rf /home/qbittorrent-nox/.config/qBittorrent
    fi

    print_success "qBittorrent-nox 卸载完成。"
}

uninstall_vertex() {
    print_info "开始卸载 Vertex (Docker Compose)..."
    local vertex_dir="$DOCKER_APP_DIR/vertex"

    if [[ -d "$vertex_dir" && -f "$vertex_dir/docker-compose.yaml" ]]; then
        cd "$vertex_dir"
        print_info "停止并移除 Vertex 容器和关联数据卷..."
        docker compose down -v
        if [[ $? -ne 0 ]]; then
            print_warning "Vertex 容器停止/移除可能存在问题，但将继续删除目录。"
        fi
        cd "$DOCKER_APP_DIR" # Move out of the directory before removing it
        sudo rm -rf "$vertex_dir"
        print_success "Vertex Docker Compose 应用和目录已移除。"
    else
        print_warning "Vertex (Docker Compose) 未安装或目录不存在。"
    fi
}

uninstall_all_apps() {
    print_warning "警告：这将卸载所有通过此脚本安装的 qBittorrent 版本和 Docker Compose 应用 (如 Vertex)。"
    read -p "确定要继续吗? (y/n): " confirm_uninstall_all
    if [[ "$confirm_uninstall_all" =~ ^[Yy]$ ]]; then
        uninstall_qbittorrent
        uninstall_vertex
        print_success "所有已安装的应用程序已卸载完成。"
    else
        print_info "已取消全部卸载操作。"
    fi
}

uninstall_docker_full() {
    print_warning "警告：这将完全卸载Docker及其所有相关组件和镜像！"
    read -p "确定要继续吗? (y/n): " confirm_uninstall_docker
    if [[ "$confirm_uninstall_docker" =~ ^[Yy]$ ]]; then
        print_info "开始卸载Docker..."
        sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo rm -rf /var/lib/docker
        sudo rm -rf /etc/docker
        print_success "Docker及其所有组件已完全卸载。"
    else
        print_info "已取消Docker完全卸载操作。"
    fi
}

# --- Main Menu Functions ---

main_menu() {
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${GREEN}      PTtools 一键脚本安装/卸载     ${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${YELLOW}GitHub: https://github.com/everett7623/PTtools${NC}"
    echo ""
    echo -e "${YELLOW}核心项目安装选项 (适用于PT刷流优化):${NC}"
    echo "  1. 安装 qBittorrent 4.3.8"
    echo "  2. 安装 qBittorrent 4.3.9"
    echo "  3. 安装 qBittorrent 4.3.8 + Vertex"
    echo "  4. 安装 qBittorrent 4.3.9 + Vertex"
    echo "  5. 选择安装应用 (进入功能分类与工具列表)"
    echo ""
    echo -e "${YELLOW}卸载选项:${NC}"
    echo "  U. 卸载已安装的 qBittorrent"
    echo "  V. 卸载已安装的 Vertex"
    echo "  A. 卸载所有通过此脚本安装的应用程序"
    echo "  D. 完全卸载Docker及其所有组件"
    echo ""
    echo "  E. 退出脚本"
    echo -e "${BLUE}=====================================${NC}"
    read -p "请输入您的选择: " choice

    case "$choice" in
        1) install_qbittorrent "4.3.8" ;;
        2) install_qbittorrent "4.3.9" ;;
        3) install_qb_and_vertex "4.3.8" ;;
        4) install_qb_and_vertex "4.3.9" ;;
        5)
            # Placeholder for future "Select Applications" menu
            print_info "功能分类与工具列表 (敬请期待更多应用，目前只提供qb和vertex)。"
            read -p "按回车键返回主菜单..."
            ;;
        U|u) uninstall_qbittorrent ;;
        V|v) uninstall_vertex ;;
        A|a) uninstall_all_apps ;;
        D|d) uninstall_docker_full ;;
        E|e) print_info "退出脚本。再见！"; exit 0 ;;
        *) print_warning "无效选择，请重新输入。" ;;
    esac
    read -p "操作完成，按回车键返回主菜单..."
}

# --- Script Entry Point ---

main() {
    check_root
    check_os
    
    print_info "初始化PTtools脚本..."
    # 强制安装Docker和Docker Compose，并设置环境，因为是核心依赖
    install_docker_and_compose
    setup_environment

    while true; do
        main_menu
    done
}

main "$@"
