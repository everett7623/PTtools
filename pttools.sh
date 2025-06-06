#!/bin/bash
# PT 工具安装脚本
# 作者: everett7623
# 版本: 1.0.0
# 描述: PT 工具一键安装脚本

# 严格模式：遇到未定义变量、命令失败或管道失败时立即退出
set -euo pipefail

# 脚本配置
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
GITHUB_RAW="https://raw.githubusercontent.com/everett7623/pttools/main"

# 默认配置
DEFAULT_DOCKER_PATH="/opt/docker"
DEFAULT_DOWNLOAD_PATH="/opt/downloads"
INSTALLATION_LOG="/var/log/pttools-install.log"
CONFIG_FILE="/etc/pttools/config.conf"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 回滚操作栈 (用于错误处理)
ROLLBACK_STACK=()

# 已安装应用注册表
declare -A INSTALLED_APPS

# ===============================================
# 基本函数
# ===============================================

# 记录信息日志
log_info() {
    echo -e "${GREEN}[信息]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$INSTALLATION_LOG"
}

# 记录警告日志
log_warn() {
    echo -e "${YELLOW}[警告]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$INSTALLATION_LOG"
}

# 记录错误日志
log_error() {
    echo -e "${RED}[错误]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$INSTALLATION_LOG"
}

# 打印分隔线
print_separator() {
    echo "========================================"
}

# 错误处理函数
error_handler() {
    local exit_code=$1
    local line_number=$2
    local bash_lineno=$3 # 实际执行的命令行号
    local last_command=$4 # 导致错误的命令

    log_error "安装失败，退出码为 $exit_code，发生在脚本第 $line_number 行 (命令行号 $bash_lineno)。"
    log_error "错误命令: $last_command"
    
    execute_rollback # 执行回滚操作
    
    exit "$exit_code"
}

# 设置陷阱，捕获 ERR 信号（命令失败时触发）
trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND"' ERR

# 注册回滚操作
rb() {
    ROLLBACK_STACK+=("$*")
}

# 执行回滚操作栈中的命令
execute_rollback() {
    if [[ ${#ROLLBACK_STACK[@]} -gt 0 ]]; then
        log_info "正在执行回滚操作..."
        # 从后往前执行回滚命令
        for (( i=${#ROLLBACK_STACK[@]}-1; i>=0; i-- )); do
            log_info "回滚: ${ROLLBACK_STACK[i]}"
            eval "${ROLLBACK_STACK[i]}" || true # 即使回滚命令失败也继续执行
        done
    fi
}

# ===============================================
# 系统检查和验证
# ===============================================

# 检查是否以 root 权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行。"
        exit 1
    fi
}

# 检查操作系统类型和版本
check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
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

# 检查并安装基本依赖
check_dependencies() {
    local deps=("wget" "curl" "ss") # ss 命令用于端口检查
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "缺少以下依赖: ${missing[*]}"
        install_apt_dependencies "${missing[@]}" # 只安装基础依赖
    fi

    # 单独检查并安装 Docker 和 Docker Compose
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
        # 针对不同架构下载最新版 Docker Compose
        local ARCH=$(uname -m)
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-${ARCH}" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        rb "rm -f /usr/local/bin/docker-compose"
    else
        log_info "Docker Compose 已安装。"
    fi
}

# 安装 apt 软件包（仅限 Ubuntu/Debian）
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

# ===============================================
# 配置管理
# ===============================================

# 加载配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "正在加载配置文件: $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log_info "配置文件 $CONFIG_FILE 不存在，正在创建默认配置。"
        create_default_config
    fi
}

# 创建默认配置
create_default_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
# PTtools 配置文件
DOCKER_PATH="${DEFAULT_DOCKER_PATH}"
DOWNLOAD_PATH="${DEFAULT_DOWNLOAD_PATH}"
SEEDBOX_USER="admin"
SEEDBOX_PASSWORD="adminadmin" # qBittorrent WebUI 密码
WEBUI_PORT=8080 # qBittorrent WebUI 端口
DAEMON_PORT=23333 # qBittorrent BT 端口
PASSKEY="" # 留空或填写您的 Tracker Passkey
EOF
    log_info "已在 $CONFIG_FILE 创建默认配置文件。"
}

# 保存配置
save_config() {
    cat > "$CONFIG_FILE" << EOF
# PTtools 配置文件
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

# ===============================================
# 用户输入函数
# ===============================================

# 提示用户输入，可带默认值
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

# 提示用户输入密码（隐藏输入）
prompt_password() {
    local prompt="$1"
    local password
    
    read -s -p "$(echo -e "${BLUE}$prompt${NC}: ")" password
    echo # 换行
    echo "$password"
}

# 验证端口号是否有效且未被占用
validate_port() {
    local port="$1"
    local port_name="$2" # 端口名称，用于更好的提示

    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1024 || port > 65535 )); then # 避免常见系统端口
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

# ===============================================
# Docker 环境管理函数
# ===============================================

# 设置 Docker 环境目录
setup_docker_environment() {
    log_info "正在设置 Docker 环境目录..."
    
    # 创建主 Docker 目录
    mkdir -p "$DOCKER_PATH"
    chmod -R 777 "$DOCKER_PATH" # 赋予写入权限，方便容器内读写

    # 创建下载目录
    mkdir -p "$DOWNLOAD_PATH"
    chmod -R 777 "$DOWNLOAD_PATH"
    
    # 为每个应用创建子目录 (如果需要)
    local apps=("qbittorrent" "transmission" "emby" "iyuuplus" "moviepilot" "vertex" "nas-tools" "filebrowser" "metatube" "byte-muse")
    for app in "${apps[@]}"; do
        mkdir -p "$DOCKER_PATH/$app"
        log_info "已创建 Docker 应用目录: $DOCKER_PATH/$app"
    done
    
    log_info "Docker 环境设置完成。"
}

# ===============================================
# 主菜单函数
# ===============================================

# 显示脚本 Banner
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

# 显示主菜单
show_main_menu() {
    show_banner
    echo "主菜单:"
    echo "1. 安装 qBittorrent 4.3.8 (独立安装)"
    echo "2. 安装 qBittorrent 4.3.9 (Jerry's Script)"
    echo "3. 安装 qBittorrent 4.3.8 + Vertex (Docker)"
    echo "4. 安装 qBittorrent 4.3.9 + Vertex (Jerry's Script + Docker)"
    echo "5. 安装选定应用程序 (Docker Compose)"
    echo "6. VPS 优化 (针对 PT 流量)"
    echo "7. 卸载选项"
    echo "8. 退出"
    print_separator
    
    local choice
    read -p "请输入您的选择 [1-8]: " choice
    
    case "$choice" in
        1) install_qb_438 ;;
        2) install_qb_439_jerry ;;
        3) install_qb_438_vertex_combo ;; # 调用组合安装函数
        4) install_qb_439_vertex_combo ;; # 调用组合安装函数
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

# ===============================================
# qBittorrent 安装函数
# ===============================================

# 安装 qBittorrent 4.3.8
install_qb_438() {
    log_info "正在安装 qBittorrent 4.3.8..."
    
    # 获取用户输入
    SEEDBOX_USER=$(prompt_user "请输入 qBittorrent WebUI 用户名" "${SEEDBOX_USER}")
    # 密码单独处理，因为 qb438.sh 的第二个参数应该是密码，不是 passkey
    SEEDBOX_PASSWORD=$(prompt_password "请输入 qBittorrent WebUI 密码")
    # 验证密码是否为空
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
    
    # 保存配置
    save_config
    
    log_info "正在下载并运行 qBittorrent 4.3.8 安装脚本..."
    # 调用远程 qb438.sh 脚本，并传递参数
    bash <(wget -qO- "$GITHUB_RAW/modules/qb438.sh") \
        "$SEEDBOX_USER" "$SEEDBOX_PASSWORD" "$WEBUI_PORT" "$DAEMON_PORT"
    
    register_installation "qbittorrent" "4.3.8"
    log_info "qBittorrent 4.3.8 安装完成。"
    
    log_info "所有安装已完成，系统将自动重启两次。"
    log_info "第一次重启将在 1 分钟后触发。"
    log_info "第二次重启将由 /root/BBRx.sh 在第一次重启后触发。"
    log_info "整个流程预计 5-10 分钟，请耐心等待..."
    shutdown -r +1 "PTtools: qBittorrent 4.3.8 安装完成，系统将重启。"
    exit 0 # 触发重启后退出主脚本
}

# 安装 qBittorrent 4.3.9 (Jerry's Script)
install_qb_439_jerry() {
    log_info "正在使用 Jerry's Script 安装 qBittorrent 4.3.9..."
    
    local username=$(prompt_user "请输入 qBittorrent 用户名" "${SEEDBOX_USER}")
    local password=$(prompt_password "请输入 qBittorrent 密码")
    while [ -z "$password" ]; do
        log_warn "密码不能为空，请重新输入。"
        password=$(prompt_password "请输入 qBittorrent 密码")
    done

    local cache_size=$(prompt_user "请输入缓存大小 (MiB)" "2048")
    local custom_port=$(prompt_user "请输入自定义 WebUI 端口 (留空使用默认)" "${WEBUI_PORT}")

    # 构建 Jerry's Script 命令
    local cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh)"
    cmd+=" -u $username -p $password -c $cache_size -q 4.3.9 -l v1.2.20"
    
    if [[ -n "$custom_port" ]]; then
        cmd+=" -o $custom_port"
    fi
    
    log_info "正在运行 Jerry's qBittorrent 4.3.9 安装脚本..."
    eval "$cmd" # 使用 eval 来执行动态构建的命令
    
    register_installation "qbittorrent" "4.3.9"
    log_info "qBittorrent 4.3.9 安装完成。"
    
    log_info "Jerry's 脚本可能需要重启，请根据提示操作或手动重启以应用所有更改。"
    read -p "安装完成。按 Enter 返回主菜单..."
    show_main_menu
}

# 组合安装：qBittorrent 4.3.8 + Vertex
install_qb_438_vertex_combo() {
    log_info "正在安装 qBittorrent 4.3.8 + Vertex 组合..."
    
    # 1. 获取 qBittorrent 参数
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
    
    # 保存配置
    save_config

    # 2. 首先安装 Docker 环境 (如果尚未安装)
    setup_docker_environment

    # 3. 安装 Vertex (Docker 版) - 注意这里路径已更新
    log_info "正在安装 Vertex (Docker 版)..."
    bash <(wget -qO- "$GITHUB_RAW/modules/vertex.sh") "latest" "$DOCKER_PATH"
    register_installation "vertex" "latest"

    # 4. 接着安装 qBittorrent 4.3.8
    log_info "正在安装 qBittorrent 4.3.8 (独立安装逻辑)..."
    bash <(wget -qO- "$GITHUB_RAW/modules/qb438.sh") \
        "$SEEDBOX_USER" "$SEEDBOX_PASSWORD" "$WEBUI_PORT" "$DAEMON_PORT"
    register_installation "qbittorrent" "4.3.8"
    
    log_info "qBittorrent 4.3.8 + Vertex 组合安装完成。"
    log_info "所有安装已完成，系统将自动重启两次。"
    log_info "第一次重启将在 1 分钟后触发。"
    log_info "第二次重启将由 /root/BBRx.sh 在第一次重启后触发。"
    log_info "整个流程预计 5-10 分钟，请耐心等待..."
    shutdown -r +1 "PTtools: qBittorrent 4.3.8 + Vertex 组合安装完成，系统将重启。"
    exit 0 # 触发重启后退出主脚本
}

# 组合安装：qBittorrent 4.3.9 (Jerry's) + Vertex
install_qb_439_vertex_combo() {
    log_info "正在安装 qBittorrent 4.3.9 (Jerry's) + Vertex 组合..."
    
    # 1. 获取 qBittorrent 参数 (与 install_qb_439_jerry 保持一致)
    local username=$(prompt_user "请输入 qBittorrent 用户名" "${SEEDBOX_USER}")
    local password=$(prompt_password "请输入 qBittorrent 密码")
    while [ -z "$password" ]; do
        log_warn "密码不能为空，请重新输入。"
        password=$(prompt_password "请输入 qBittorrent 密码")
    done
    local cache_size=$(prompt_user "请输入缓存大小 (MiB)" "2048")
    local custom_port=$(prompt_user "请输入自定义 WebUI 端口 (留空使用默认)" "${WEBUI_PORT}")

    # 保存配置 (如果需要将 Jerry's 脚本的参数保存到主配置)
    SEEDBOX_USER="$username"
    SEEDBOX_PASSWORD="$password"
    if [[ -n "$custom_port" ]]; then WEBUI_PORT="$custom_port"; fi
    save_config

    # 2. 首先安装 Docker 环境 (如果尚未安装)
    setup_docker_environment

    # 3. 安装 Vertex (Docker 版) - 注意这里路径已更新
    log_info "正在安装 Vertex (Docker 版)..."
    bash <(wget -qO- "$GITHUB_RAW/modules/vertex.sh") "latest" "$DOCKER_PATH"
    register_installation "vertex" "latest"

    # 4. 接着安装 qBittorrent 4.3.9 (Jerry's Script)
    log_info "正在运行 Jerry's qBittorrent 4.3.9 安装脚本..."
    local cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh)"
    cmd+=" -u $username -p $password -c $cache_size -q 4.3.9 -l v1.2.20"
    if [[ -n "$custom_port" ]]; then
        cmd+=" -o $custom_port"
    fi
    eval "$cmd"
    register_installation "qbittorrent" "4.3.9"

    log_info "qBittorrent 4.3.9 + Vertex 组合安装完成。"
    log_info "请检查 qBittorrent 和 Vertex 服务是否已正常启动。"
    log_info "Jerry's 脚本可能需要重启，请根据提示操作或手动重启以应用所有更改。"
    read -p "安装完成。按 Enter 返回主菜单..."
    show_main_menu
}

# 仅安装 Vertex (Docker) - 新增选项 
install_vertex_only() {
    log_info "正在独立安装 Vertex (Docker 版)..."

    # 1. 确保 Docker 环境已设置
    setup_docker_environment

    # 2. 调用 Vertex 安装模块 - 注意这里路径已更新
    bash <(wget -qO- "$GITHUB_RAW/modules/vertex.sh") "latest" "$DOCKER_PATH"
    register_installation "vertex" "latest"

    log_info "Vertex (Docker) 独立安装完成。"
    read -p "安装完成。按 Enter 返回主菜单..."
    show_main_menu
}


# ===============================================
# 应用程序选择菜单
# ===============================================

# 显示应用选择菜单
show_app_selection_menu() {
    show_banner
    echo "选择要安装的应用程序 (Docker Compose):"
    echo
    echo "下载管理:"
    echo "  1. qBittorrent (Docker)" # 注意：这里与单独安装 4.3.8/4.3.9 不同，这是基于 Docker Compose
    echo "  2. Transmission (Docker)"
    echo
    echo "自动化工具:"
    echo "  3. IYUUPlus (Docker)"
    echo "  4. MoviePilot (Docker)"
    echo "  5. Vertex (Docker)" # 如果用户选择此项，将使用 Docker Compose 生成方式
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
    read -a selections # 读取到数组
    
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

# 安装选定的 Docker 应用程序
install_docker_apps() {
    local apps=("$@") # 获取所有传入的应用程序名称
    
    log_info "正在安装选定的 Docker 应用程序: ${apps[*]}"
    
    # 设置 Docker 环境
    setup_docker_environment
    
    # 生成 docker-compose.yml 文件
    log_info "正在生成 docker-compose.yml 文件..."
    bash <(wget -qO- "$GITHUB_RAW/modules/generate_compose.sh") "$DOCKER_PATH" "${apps[@]}"
    
    # 启动 Docker 容器
    log_info "正在启动 Docker 容器..."
    cd "$DOCKER_PATH" || log_error "无法进入 Docker 目录 $DOCKER_PATH"
    docker compose up -d
    
    # 注册安装信息
    for app in "${apps[@]}"; do
        register_installation "$app" "latest" # 默认版本为 latest
    done
    
    log_info "Docker 应用程序安装完成。"
}

# ===============================================
# VPS 优化
# ===============================================

# 优化 VPS (针对 PT 流量)
optimize_vps() {
    log_info "正在开始 VPS 优化 (针对 PT 流量)..."
    
    # 下载并运行优化模块
    bash <(wget -qO- "$GITHUB_RAW/modules/vps_optimize.sh")
    
    log_info "VPS 优化完成。"
    read -p "按 Enter 键继续..."
    show_main_menu
}

# ===============================================
# 卸载函数
# ===============================================

# 显示卸载菜单
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

# 选择性卸载
selective_uninstall() {
    log_info "正在加载卸载模块..."
    bash <(wget -qO- "$GITHUB_RAW/modules/uninstall.sh") "selective"
    read -p "按 Enter 键继续..."
    show_uninstall_menu
}

# 移除所有 PT 工具
remove_all_pt_tools() {
    log_warn "此操作将移除所有 PT 工具，包括 qBittorrent、Vertex 等。"
    read -p "您确定要继续吗？(yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        bash <(wget -qO- "$GITHUB_RAW/modules/uninstall.sh") "all"
    else
        log_info "已取消移除所有 PT 工具。"
    fi
    
    read -p "按 Enter 键继续..."
    show_uninstall_menu
}

# 移除所有 Docker 环境
remove_docker_environment() {
    log_warn "此操作将移除所有 Docker 容器、镜像和网络。谨慎操作！"
    read -p "您确定要继续吗？(yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        bash <(wget -qO- "$GITHUB_RAW/modules/uninstall.sh") "docker"
    else
        log_info "已取消移除 Docker 环境。"
    fi
    
    read -p "按 Enter 键继续..."
    show_uninstall_menu
}

# 完整系统清理
complete_system_cleanup() {
    log_warn "此操作将移除所有工具、Docker 环境，并尝试还原系统更改。这是最终清理选项，请务必谨慎！"
    read -p "您确定要继续吗？请输入 'yes' 以确认: " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        bash <(wget -qO- "$GITHUB_RAW/modules/uninstall.sh") "complete"
    else
        log_info "已取消完整系统清理。"
    fi
    
    read -p "按 Enter 键继续..."
    show_uninstall_menu
}

# ===============================================
# 工具函数
# ===============================================

# 注册安装信息
register_installation() {
    local app_name="$1"
    local version="$2"
    local install_path="${3:-$DOCKER_PATH/$app_name}"
    
    # 将安装信息保存到安装记录文件
    echo "$app_name|$version|$install_path|$(date '+%Y-%m-%d %H:%M:%S')" >> /etc/pttools/installed.list
    log_info "已注册安装: $app_name (版本: $version, 路径: $install_path)"
}

# 列出已安装工具
list_installed_tools() {
    if [[ -f /etc/pttools/installed.list ]]; then
        log_info "已安装工具列表:"
        cat /etc/pttools/installed.list
    else
        log_info "没有找到已安装工具的记录。"
    fi
}

# 退出脚本
exit_script() {
    log_info "正在退出 PT Tools 安装器..."
    exit 0
}

# ===============================================
# 主执行流程
# ===============================================

main() {
    # 初步检查
    check_root # 检查是否是 root 用户
    check_os   # 检查操作系统
    
    # 创建日志目录
    mkdir -p "$(dirname "$INSTALLATION_LOG")"
    
    log_info "正在启动 PT Tools 安装脚本 v$SCRIPT_VERSION"
    
    # 加载配置
    load_config
    
    # 检查并安装依赖 (包括 Docker)
    check_dependencies
    
    # 显示主菜单并处理用户选择
    show_main_menu
}

# 运行主函数
main "$@" # 将所有命令行参数传递给 main 函数
