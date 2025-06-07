#!/bin/bash

# PTtools - PT工具一键安装脚本
# 作者：everett7623
# 项目地址：https://github.com/everett7623/PTtools
# 版本：1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# 基础变量
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_RAW_URL="https://raw.githubusercontent.com/everett7623/PTtools/main"
INSTALL_PATH="/opt/docker"
LOG_PATH="/var/log/pttools"
LOG_FILE="${LOG_PATH}/install.log"

# 获取服务器IP
get_server_ip() {
    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null) || \
    SERVER_IP=$(curl -s --connect-timeout 5 ipinfo.io/ip 2>/dev/null) || \
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null) || \
    SERVER_IP="your-server-ip"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：此脚本需要root权限运行${NC}"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 基础日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# 检查端口是否被占用
check_port() {
    local port="$1"
    if ss -tulnp | grep ":$port " >/dev/null 2>&1; then
        return 0  # 端口被占用
    else
        return 1  # 端口空闲
    fi
}

# 等待服务启动
wait_for_service() {
    local service_name="$1"
    local port="$2"
    local max_wait="${3:-60}"
    local count=0
    
    echo -n "等待 $service_name 启动"
    
    while [[ $count -lt $max_wait ]]; do
        if check_port "$port"; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((count += 2))
    done
    
    echo -e " ${RED}✗${NC}"
    return 1
}

# 显示成功信息
show_success() {
    local service_name="$1"
    local port="$2"
    
    echo
    echo -e "${GREEN}🎉 $service_name 安装成功！${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}访问信息：${NC}"
    echo -e "${CYAN}  服务器IP：${SERVER_IP}${NC}"
    if [[ -n "$port" ]]; then
        echo -e "${CYAN}  访问地址：http://${SERVER_IP}:${port}${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# 初始化环境
init_environment() {
    mkdir -p "${INSTALL_PATH}" "${LOG_PATH}" 2>/dev/null || true
    log_info "PTtools v${SCRIPT_VERSION} 启动"
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

# 运行本地或远程脚本
run_script() {
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

# 安装qBittorrent 4.3.8
install_qb_438() {
    log_info "开始安装qBittorrent 4.3.8..."
    run_script "scripts/install/qb438.sh"
}

# 安装qBittorrent 4.3.9
install_qb_439() {
    log_info "开始安装qBittorrent 4.3.9..."
    run_script "scripts/install/qb439.sh"
}

# 安装Vertex
install_vertex() {
    log_info "开始安装Vertex..."
    
    mkdir -p "${INSTALL_PATH}/vertex"
    
    # 检查端口
    if check_port "3334"; then
        VERTEX_PORT=3335
        log_warn "端口3334被占用，使用3335端口"
    else
        VERTEX_PORT=3334
    fi
    
    # 创建docker-compose文件
    cat > "${INSTALL_PATH}/vertex/docker-compose.yml" << EOF
version: '3.8'
services:
  vertex:
    image: lswl/vertex:stable
    container_name: vertex
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ${INSTALL_PATH}/vertex:/vertex
    ports:
      - "${VERTEX_PORT}:3000"
    restart: unless-stopped
EOF
    
    # 启动Vertex
    cd "${INSTALL_PATH}/vertex"
    if docker-compose up -d; then
        sleep 5
        if docker ps | grep vertex >/dev/null; then
            log_info "Vertex安装成功"
            show_success "Vertex" "$VERTEX_PORT"
            return 0
        else
            log_error "Vertex容器启动失败"
            return 1
        fi
    else
        log_error "Vertex安装失败"
        return 1
    fi
}

# 显示状态
show_status() {
    clear
    echo -e "${BLUE}系统状态信息${NC}"
    echo "=================================="
    
    # Docker状态
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Docker已安装"
        if systemctl is-active --quiet docker; then
            echo -e "${GREEN}✓${NC} Docker服务运行中"
        else
            echo -e "${RED}✗${NC} Docker服务未运行"
        fi
    else
        echo -e "${RED}✗${NC} Docker未安装"
    fi
    
    # qBittorrent状态
    if command -v qbittorrent-nox >/dev/null 2>&1 || systemctl list-units --type=service | grep -q qbittorrent; then
        echo -e "${GREEN}✓${NC} qBittorrent已安装"
        for port in 8080 8081 8082; do
            if check_port "$port"; then
                echo -e "${CYAN}  Web UI: http://${SERVER_IP}:${port}${NC}"
                break
            fi
        done
    else
        echo -e "${RED}✗${NC} qBittorrent未安装"
    fi
    
    # Vertex状态
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^vertex$"; then
        echo -e "${GREEN}✓${NC} Vertex运行中"
        local vertex_port=$(docker port vertex 2>/dev/null | grep 3000 | cut -d':' -f2)
        if [[ -n "$vertex_port" ]]; then
            echo -e "${CYAN}  访问地址: http://${SERVER_IP}:${vertex_port}${NC}"
        fi
    else
        echo -e "${RED}✗${NC} Vertex未运行"
    fi
    
    echo
    read -p "按任意键返回主菜单..." -n 1
}

# 显示主菜单
show_main_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                       PTtools v${SCRIPT_VERSION}                        ║"
    echo "║                   PT工具一键安装脚本                           ║"
    echo "║                    调用现有脚本文件                             ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}核心安装选项：${NC}"
    echo -e "${WHITE}1)${NC} 安装 qBittorrent 4.3.8  ${GRAY}(调用 scripts/install/qb438.sh)${NC}"
    echo -e "${WHITE}2)${NC} 安装 qBittorrent 4.3.9  ${GRAY}(调用 scripts/install/qb439.sh)${NC}"
    echo -e "${WHITE}3)${NC} 安装 qBittorrent 4.3.8 + Vertex"
    echo -e "${WHITE}4)${NC} 安装 qBittorrent 4.3.9 + Vertex"
    echo
    echo -e "${CYAN}其他选项：${NC}"
    echo -e "${WHITE}5)${NC} 查看系统状态"
    echo -e "${WHITE}6)${NC} 退出脚本"
    echo
}

# 主函数
main() {
    # 设置清理陷阱
    trap 'rm -rf /tmp/pttools 2>/dev/null || true' EXIT
    
    # 初始化
    check_root
    get_server_ip
    init_environment
    
    while true; do
        show_main_menu
        read -p "请选择操作 [1-6]: " choice
        
        case $choice in
            1)
                install_docker
                if [[ $? -eq 0 ]]; then
                    install_qb_438
                fi
                read -p "按任意键继续..." -n 1
                ;;
            2)
                install_docker
                if [[ $? -eq 0 ]]; then
                    install_qb_439
                fi
                read -p "按任意键继续..." -n 1
                ;;
            3)
                install_docker
                if [[ $? -eq 0 ]] && install_qb_438; then
                    install_vertex
                fi
                read -p "按任意键继续..." -n 1
                ;;
            4)
                install_docker
                if [[ $? -eq 0 ]] && install_qb_439; then
                    install_vertex
                fi
                read -p "按任意键继续..." -n 1
                ;;
            5)
                show_status
                ;;
            6)
                echo -e "${GREEN}感谢使用PTtools！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请输入1-6${NC}"
                sleep 2
                ;;
        esac
    done
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
