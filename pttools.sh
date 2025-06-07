#!/bin/bash

# PTtools - PT工具一键安装脚本
# 作者：everett7623
# 项目地址：https://github.com/everett7623/PTtools
# 版本：1.0.0

set -e

# 基础变量
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_RAW_URL="https://raw.githubusercontent.com/everett7623/PTtools/main"

# 路径定义
INSTALL_PATH="/opt/docker"
DOWNLOAD_PATH="/opt/downloads"
CONFIG_PATH="/etc/pttools"
LOG_PATH="/var/log/pttools"
LOG_FILE="${LOG_PATH}/install.log"

# 项目路径
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# 加载工具函数
load_utils() {
    local utils_dir=""
    
    # 检查是否在项目目录中运行
    if [[ -d "${SCRIPTS_DIR}/utils" ]]; then
        utils_dir="${SCRIPTS_DIR}/utils"
    else
        # 从GitHub下载工具函数
        mkdir -p /tmp/pttools/utils
        utils_dir="/tmp/pttools/utils"
        
        for util_file in common.sh log_utils.sh docker_utils.sh; do
            if ! curl -fsSL "${GITHUB_RAW_URL}/scripts/utils/${util_file}" -o "${utils_dir}/${util_file}"; then
                echo "警告: 无法下载 ${util_file}，使用内置函数"
            fi
        done
    fi
    
    # 尝试加载工具函数
    for util_file in common.sh log_utils.sh docker_utils.sh; do
        if [[ -f "${utils_dir}/${util_file}" ]]; then
            source "${utils_dir}/${util_file}"
        fi
    done
}

# 内置基础函数（如果工具函数加载失败）
init_builtin_functions() {
    # 颜色定义
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    GRAY='\033[0;37m'
    NC='\033[0m'
    
    # 基础日志函数
    if ! type log_info >/dev/null 2>&1; then
        log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
        log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
        log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
    fi
    
    # 检查root权限
    if ! type check_root >/dev/null 2>&1; then
        check_root() {
            if [[ $EUID -ne 0 ]]; then
                log_error "此脚本需要root权限运行"
                echo "请使用: sudo $0"
                exit 1
            fi
        }
    fi
    
    # 获取服务器IP
    if ! type get_server_ip >/dev/null 2>&1; then
        get_server_ip() {
            SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null) || \
            SERVER_IP=$(curl -s --connect-timeout 5 ipinfo.io/ip 2>/dev/null) || \
            SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null) || \
            SERVER_IP="your-server-ip"
        }
    fi
}

# 初始化环境
init_environment() {
    # 创建必要目录
    mkdir -p "${INSTALL_PATH}" "${CONFIG_PATH}" "${LOG_PATH}"
    
    # 创建日志文件
    touch "${LOG_FILE}" 2>/dev/null || true
    
    log_info "PTtools v${SCRIPT_VERSION} 启动"
    log_info "项目目录: ${SCRIPT_DIR}"
}

# 下载并执行脚本
download_and_run_script() {
    local script_path="$1"
    local temp_path="/tmp/pttools/$(basename "$script_path")"
    
    mkdir -p "$(dirname "$temp_path")"
    
    log_info "下载脚本: $script_path"
    
    if curl -fsSL "${GITHUB_RAW_URL}/${script_path}" -o "$temp_path"; then
        chmod +x "$temp_path"
        log_info "执行脚本: $(basename "$script_path")"
        
        if bash "$temp_path"; then
            log_info "脚本执行成功: $(basename "$script_path")"
            return 0
        else
            log_error "脚本执行失败: $(basename "$script_path")"
            return 1
        fi
    else
        log_error "无法下载脚本: $script_path"
        return 1
    fi
}

# 检查本地脚本并执行
run_local_script() {
    local script_path="$1"
    local full_path="${SCRIPT_DIR}/${script_path}"
    
    if [[ -f "$full_path" ]]; then
        log_info "执行本地脚本: $script_path"
        if bash "$full_path"; then
            log_info "本地脚本执行成功"
            return 0
        else
            log_error "本地脚本执行失败"
            return 1
        fi
    else
        log_warn "本地脚本不存在，尝试从GitHub下载"
        download_and_run_script "$script_path"
    fi
}

# 安装Docker
install_docker() {
    # 尝试使用本地Docker安装脚本
    if run_local_script "scripts/install/docker_install.sh"; then
        return 0
    fi
    
    # 使用内置Docker安装
    log_info "使用内置Docker安装流程..."
    
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker已安装，检查服务状态..."
        systemctl start docker 2>/dev/null || true
        return 0
    fi
    
    log_info "安装Docker..."
    apt-get update -y
    apt-get install -y curl wget
    
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
    systemctl enable docker
    systemctl start docker
    
    # 安装docker-compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    log_info "Docker安装完成"
}

# 使用配置文件安装应用
install_with_compose() {
    local app_name="$1"
    local compose_file=""
    
    # 检查本地配置文件
    local local_compose="${CONFIG_DIR}/docker-compose/${app_name}.yml"
    if [[ -f "$local_compose" ]]; then
        compose_file="$local_compose"
        log_info "使用本地配置文件: $local_compose"
    else
        # 下载配置文件
        compose_file="/tmp/pttools/${app_name}.yml"
        mkdir -p "$(dirname "$compose_file")"
        
        if curl -fsSL "${GITHUB_RAW_URL}/config/docker-compose/${app_name}.yml" -o "$compose_file"; then
            log_info "下载配置文件成功: ${app_name}.yml"
        else
            log_error "无法下载配置文件: ${app_name}.yml"
            return 1
        fi
    fi
    
    # 创建应用目录
    local app_dir="${INSTALL_PATH}/${app_name}"
    mkdir -p "$app_dir"
    
    # 复制配置文件
    cp "$compose_file" "${app_dir}/docker-compose.yml"
    
    # 启动服务
    cd "$app_dir"
    if docker-compose up -d; then
        log_info "${app_name} 安装成功"
        return 0
    else
        log_error "${app_name} 安装失败"
        return 1
    fi
}

# 安装qBittorrent 4.3.8
install_qb_438() {
    log_info "开始安装qBittorrent 4.3.8..."
    run_local_script "scripts/install/qb_438.sh"
}

# 安装qBittorrent 4.3.9
install_qb_439() {
    log_info "开始安装qBittorrent 4.3.9..."
    run_local_script "scripts/install/qb_439.sh"
}

# 安装Vertex
install_vertex() {
    log_info "开始安装Vertex..."
    install_with_compose "vertex"
}

# VPS优化
optimize_vps() {
    log_info "开始VPS优化..."
    
    if run_local_script "scripts/optimize/vps_optimize.sh"; then
        log_info "VPS优化完成"
    else
        log_warn "VPS优化脚本执行失败，使用基础优化..."
        
        # 基础网络优化
        echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
        echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
        sysctl -p
        
        log_info "基础优化完成"
    fi
}

# 显示状态
show_status() {
    clear
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                        系统状态                              ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    # 系统信息
    echo -e "${CYAN}系统信息:${NC}"
    echo "  操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "  内核版本: $(uname -r)"
    echo "  运行时间: $(uptime -p)"
    echo
    
    # Docker状态
    echo -e "${CYAN}Docker状态:${NC}"
    if command -v docker >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Docker已安装: $(docker --version | cut -d' ' -f3 | tr -d ',')"
        if systemctl is-active --quiet docker; then
            echo -e "  ${GREEN}✓${NC} Docker服务运行中"
            echo "  运行中的容器: $(docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null | wc -l)个"
        else
            echo -e "  ${RED}✗${NC} Docker服务未运行"
        fi
    else
        echo -e "  ${RED}✗${NC} Docker未安装"
    fi
    echo
    
    # 应用状态
    echo -e "${CYAN}应用状态:${NC}"
    
    # qBittorrent
    if command -v qbittorrent-nox >/dev/null 2>&1 || systemctl list-units --type=service | grep -q qbittorrent; then
        echo -e "  ${GREEN}✓${NC} qBittorrent已安装"
        for port in 8080 8081 8082; do
            if ss -tulnp | grep ":$port " >/dev/null 2>&1; then
                echo -e "    Web UI: http://${SERVER_IP}:${port}"
                break
            fi
        done
    else
        echo -e "  ${RED}✗${NC} qBittorrent未安装"
    fi
    
    # Docker应用
    for app in vertex transmission emby iyuuplus moviepilot; do
        if docker ps --format '{{.Names}}' | grep -q "^${app}$"; then
            echo -e "  ${GREEN}✓${NC} ${app} 运行中"
            local port=$(docker port "$app" 2>/dev/null | head -1 | cut -d':' -f2)
            if [[ -n "$port" ]]; then
                echo -e "    访问地址: http://${SERVER_IP}:${port}"
            fi
        else
            echo -e "  ${GRAY}○${NC} ${app} 未运行"
        fi
    done
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    read -p "按任意键返回主菜单..." -n 1
}

# 显示主菜单
show_main_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                       PTtools v${SCRIPT_VERSION}                        ║"
    echo "║                   PT工具一键安装脚本                           ║"
    echo "║                    模块化架构设计                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}核心项目安装选项：${NC}"
    echo -e "${WHITE}1)${NC} 安装 qBittorrent 4.3.8"
    echo -e "${WHITE}2)${NC} 安装 qBittorrent 4.3.9"
    echo -e "${WHITE}3)${NC} 安装 qBittorrent 4.3.8 + Vertex"
    echo -e "${WHITE}4)${NC} 安装 qBittorrent 4.3.9 + Vertex"
    echo
    echo -e "${CYAN}应用管理：${NC}"
    echo -e "${WHITE}5)${NC} 选择安装应用 ${GRAY}(Docker Compose)${NC}"
    echo -e "${WHITE}6)${NC} VPS优化设置"
    echo -e "${WHITE}7)${NC} 查看系统状态"
    echo
    echo -e "${CYAN}其他选项：${NC}"
    echo -e "${WHITE}8)${NC} 卸载应用 ${GRAY}(开发中)${NC}"
    echo -e "${WHITE}9)${NC} 退出脚本"
    echo
}

# 应用选择菜单
show_app_menu() {
    clear
    echo -e "${CYAN}选择要安装的应用：${NC}"
    echo
    echo -e "${WHITE}下载管理：${NC}"
    echo "  1) qBittorrent (Docker版)"
    echo "  2) Transmission"
    echo
    echo -e "${WHITE}媒体服务器：${NC}"
    echo "  3) Emby"
    echo "  4) Jellyfin"
    echo "  5) Plex"
    echo
    echo -e "${WHITE}自动化管理：${NC}"
    echo "  6) IYUUPlus"
    echo "  7) MoviePilot"
    echo "  8) NAS-Tools"
    echo "  9) Vertex"
    echo
    echo -e "${WHITE}其他工具：${NC}"
    echo "  10) FileBrowser"
    echo "  11) AList"
    echo "  12) Portainer"
    echo
    echo "  0) 返回主菜单"
    echo
}

# 处理应用安装
handle_app_install() {
    show_app_menu
    read -p "请选择要安装的应用 [0-12]: " app_choice
    
    case $app_choice in
        1) install_with_compose "qbittorrent" ;;
        2) install_with_compose "transmission" ;;
        3) install_with_compose "emby" ;;
        4) install_with_compose "jellyfin" ;;
        5) install_with_compose "plex" ;;
        6) install_with_compose "iyuuplus" ;;
        7) install_with_compose "moviepilot" ;;
        8) install_with_compose "nastools" ;;
        9) install_with_compose "vertex" ;;
        10) install_with_compose "filebrowser" ;;
        11) install_with_compose "alist" ;;
        12) install_with_compose "portainer" ;;
        0) return ;;
        *) echo -e "${RED}无效选择${NC}"; sleep 2; return ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}应用安装完成！${NC}"
        echo -e "${CYAN}访问地址: http://${SERVER_IP}${NC}"
    fi
    
    read -p "按任意键继续..." -n 1
}

# 主函数
main() {
    # 初始化
    init_builtin_functions
    load_utils
    check_root
    get_server_ip
    init_environment
    
    while true; do
        show_main_menu
        read -p "请选择操作 [1-9]: " choice
        
        case $choice in
            1)
                install_docker
                install_qb_438
                read -p "按任意键继续..." -n 1
                ;;
            2)
                install_docker
                install_qb_439
                read -p "按任意键继续..." -n 1
                ;;
            3)
                install_docker
                if install_qb_438; then
                    install_vertex
                fi
                read -p "按任意键继续..." -n 1
                ;;
            4)
                install_docker
                if install_qb_439; then
                    install_vertex
                fi
                read -p "按任意键继续..." -n 1
                ;;
            5)
                install_docker
                handle_app_install
                ;;
            6)
                optimize_vps
                read -p "按任意键继续..." -n 1
                ;;
            7)
                show_status
                ;;
            8)
                echo -e "${YELLOW}卸载功能开发中...${NC}"
                read -p "按任意键继续..." -n 1
                ;;
            9)
                echo -e "${GREEN}感谢使用PTtools！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请输入1-9${NC}"
                sleep 2
                ;;
        esac
    done
}

# 清理函数
cleanup() {
    rm -rf /tmp/pttools 2>/dev/null || true
}

# 设置退出时清理
trap cleanup EXIT

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
