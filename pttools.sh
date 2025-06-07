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
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_VERSION="1.0.0"
INSTALL_PATH="/opt/docker"
DOWNLOAD_PATH="/opt/downloads"
CONFIG_PATH="/etc/pttools"
LOG_PATH="/var/log/pttools"
LOG_FILE="${LOG_PATH}/install.log"
GITHUB_RAW_URL="https://raw.githubusercontent.com/everett7623/PTtools/main"

# 获取服务器IP
SERVER_IP=""

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：此脚本需要root权限运行${NC}"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 获取服务器IP
get_server_ip() {
    # 尝试多种方式获取公网IP
    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me) || \
    SERVER_IP=$(curl -s --connect-timeout 5 ipinfo.io/ip) || \
    SERVER_IP=$(curl -s --connect-timeout 5 icanhazip.com) || \
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP="your-server-ip"
    fi
}

# 创建基础目录结构
create_directories() {
    log_info "创建基础目录结构..."
    
    # 创建主要目录
    mkdir -p "${INSTALL_PATH}"
    mkdir -p "${DOWNLOAD_PATH}"
    mkdir -p "${CONFIG_PATH}"
    mkdir -p "${LOG_PATH}"
    mkdir -p "${INSTALL_PATH}/vertex"
    
    # 设置权限
    chmod -R 755 "${INSTALL_PATH}"
    chmod -R 755 "${DOWNLOAD_PATH}"
    chmod -R 755 "${CONFIG_PATH}"
    chmod -R 755 "${LOG_PATH}"
    
    log_info "目录结构创建完成"
}

# 日志函数
log_info() {
    local message="$1"
    echo -e "${GREEN}[INFO]${NC} $message"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "$LOG_FILE"
}

log_warn() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $message" >> "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $message" >> "$LOG_FILE"
}

# 检测系统类型
detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        OS_VERSION=$VERSION_ID
    else
        log_error "无法检测系统类型"
        exit 1
    fi
    
    log_info "检测到系统：$OS $OS_VERSION"
}

# 检查系统兼容性
check_system_compatibility() {
    log_info "检查系统兼容性..."
    
    # 检查系统类型
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        log_info "系统兼容性检查通过"
    else
        log_warn "当前系统可能不完全兼容，建议使用 Ubuntu 18.04+ 或 Debian 10+"
        read -p "是否继续安装？[y/N]: " continue_install
        if [[ "${continue_install,,}" != "y" ]]; then
            echo "安装已取消"
            exit 0
        fi
    fi
    
    # 检查内存
    local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [[ $total_mem -lt 1024 ]]; then
        log_warn "系统内存少于1GB，可能影响性能"
    fi
    
    # 检查磁盘空间
    local free_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $free_space -lt 10485760 ]]; then  # 10GB in KB
        log_warn "系统可用空间少于10GB，可能影响安装"
    fi
}

# 下载脚本文件
download_script() {
    local script_name="$1"
    local local_path="$2"
    
    log_info "下载脚本: $script_name"
    
    if curl -fsSL "${GITHUB_RAW_URL}/${script_name}" -o "$local_path"; then
        chmod +x "$local_path"
        log_info "脚本下载成功: $script_name"
        return 0
    else
        log_error "脚本下载失败: $script_name"
        return 1
    fi
}

# 安装Docker
install_docker() {
    log_info "开始安装Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker已安装，版本：$(docker --version)"
        
        # 检查Docker服务状态
        if systemctl is-active --quiet docker; then
            log_info "Docker服务运行正常"
        else
            log_info "启动Docker服务..."
            systemctl start docker
        fi
        
        return 0
    fi
    
    # 更新系统包
    log_info "更新系统包列表..."
    apt-get update -y
    
    # 安装必要的包
    apt-get install -y curl wget apt-transport-https ca-certificates gnupg lsb-release
    
    # 询问是否使用国内镜像
    echo -e "${CYAN}选择Docker安装源：${NC}"
    echo "1) 官方源 (国外服务器推荐)"
    echo "2) 阿里云镜像 (国内服务器推荐)"
    read -p "请选择 [1-2，默认2]: " docker_mirror_choice
    docker_mirror_choice=${docker_mirror_choice:-2}
    
    case $docker_mirror_choice in
        1)
            log_info "使用官方源安装Docker..."
            curl -fsSL https://get.docker.com | bash -s docker
            ;;
        2)
            log_info "使用阿里云镜像安装Docker..."
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            ;;
        *)
            log_info "使用阿里云镜像安装Docker..."
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            ;;
    esac
    
    # 启动Docker服务
    systemctl enable docker
    systemctl start docker
    
    # 验证Docker安装
    if docker --version &> /dev/null; then
        log_info "Docker安装成功：$(docker --version)"
    else
        log_error "Docker安装失败"
        exit 1
    fi
    
    # 安装docker-compose
    if ! command -v docker-compose &> /dev/null; then
        log_info "安装docker-compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
        # 验证docker-compose安装
        if docker-compose --version &> /dev/null; then
            log_info "docker-compose安装成功：$(docker-compose --version)"
        else
            log_error "docker-compose安装失败"
            exit 1
        fi
    fi
    
    log_info "Docker环境准备完成"
}

# 安装qBittorrent 4.3.8 (使用项目中的qb438.sh)
install_qb_438() {
    log_info "开始安装qBittorrent 4.3.8..."
    
    # 下载qb438.sh脚本
    local script_path="/tmp/qb438.sh"
    if download_script "qb438.sh" "$script_path"; then
        log_info "执行qBittorrent 4.3.8安装脚本..."
        
        # 执行脚本
        if bash "$script_path"; then
            log_info "qBittorrent 4.3.8安装完成"
            save_install_info "qbittorrent-4.3.8"
            show_success_info "qBittorrent 4.3.8"
            
            # 清理临时文件
            rm -f "$script_path"
            return 0
        else
            log_error "qBittorrent 4.3.8安装失败"
            rm -f "$script_path"
            return 1
        fi
    else
        log_error "无法下载qBittorrent 4.3.8安装脚本"
        return 1
    fi
}

# 安装qBittorrent 4.3.9 (使用项目中的qb439.sh)
install_qb_439() {
    log_info "开始安装qBittorrent 4.3.9..."
    
    # 下载qb439.sh脚本
    local script_path="/tmp/qb439.sh"
    if download_script "qb439.sh" "$script_path"; then
        log_info "执行qBittorrent 4.3.9安装脚本..."
        
        # 执行脚本
        if bash "$script_path"; then
            log_info "qBittorrent 4.3.9安装完成"
            save_install_info "qbittorrent-4.3.9"
            show_success_info "qBittorrent 4.3.9"
            
            # 清理临时文件
            rm -f "$script_path"
            return 0
        else
            log_error "qBittorrent 4.3.9安装失败"
            rm -f "$script_path"
            return 1
        fi
    else
        log_error "无法下载qBittorrent 4.3.9安装脚本"
        return 1
    fi
}

# 安装Vertex
install_vertex() {
    log_info "开始安装Vertex..."
    
    # 创建Vertex目录
    mkdir -p "${INSTALL_PATH}/vertex"
    
    # 检查端口3334是否被占用
    if ss -tulnp | grep ":3334 " > /dev/null; then
        log_warn "端口3334已被占用，将使用3335端口"
        VERTEX_PORT=3335
    else
        VERTEX_PORT=3334
    fi
    
    # 创建docker-compose配置
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
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF
    
    # 启动Vertex
    cd "${INSTALL_PATH}/vertex"
    
    if docker-compose up -d; then
        # 等待容器启动
        sleep 10
        
        # 检查容器状态
        if docker ps | grep vertex > /dev/null; then
            log_info "Vertex安装完成"
            save_install_info "vertex"
            echo -e "${GREEN}Vertex安装成功！${NC}"
            echo -e "${CYAN}访问地址：http://${SERVER_IP}:${VERTEX_PORT}${NC}"
            return 0
        else
            log_error "Vertex容器启动失败"
            docker logs vertex 2>/dev/null || true
            return 1
        fi
    else
        log_error "Vertex安装失败"
        return 1
    fi
}

# 保存安装信息
save_install_info() {
    local app_name="$1"
    local config_file="${CONFIG_PATH}/installed_apps.conf"
    
    # 创建或更新已安装应用列表
    if [[ ! -f "$config_file" ]]; then
        echo "# PTtools 已安装应用列表" > "$config_file"
        echo "# 安装时间: $(date +'%Y-%m-%d %H:%M:%S')" >> "$config_file"
    fi
    
    # 检查是否已记录
    if ! grep -q "^$app_name=" "$config_file" 2>/dev/null; then
        echo "$app_name=$(date +'%Y-%m-%d %H:%M:%S')" >> "$config_file"
    fi
}

# 显示安装成功信息
show_success_info() {
    local app_name="$1"
    echo
    echo -e "${GREEN}🎉 ${app_name} 安装成功！${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}服务器信息：${NC}"
    echo -e "${CYAN}  服务器IP：${SERVER_IP}${NC}"
    
    # 显示可能的访问端口
    if systemctl is-active --quiet qbittorrent 2>/dev/null; then
        local qb_port=$(ss -tulnp | grep qbittorrent | grep -o ':\d\+' | head -1 | tr -d ':')
        if [[ -n "$qb_port" ]]; then
            echo -e "${CYAN}  qBittorrent：http://${SERVER_IP}:${qb_port}${NC}"
        fi
    fi
    
    if docker ps | grep vertex > /dev/null; then
        local vertex_port=$(docker port vertex 2>/dev/null | grep 3000 | cut -d':' -f2)
        if [[ -n "$vertex_port" ]]; then
            echo -e "${CYAN}  Vertex：http://${SERVER_IP}:${vertex_port}${NC}"
        fi
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# 安装qBittorrent 4.3.8 + Vertex
install_qb_438_vertex() {
    log_info "开始安装qBittorrent 4.3.8 + Vertex组合..."
    
    if install_qb_438; then
        echo -e "${CYAN}qBittorrent 4.3.8 安装完成，继续安装 Vertex...${NC}"
        sleep 3
        if install_vertex; then
            echo
            echo -e "${GREEN}🎉 qBittorrent 4.3.8 + Vertex 组合安装完成！${NC}"
            show_combined_info
            return 0
        else
            log_error "Vertex安装失败，但qBittorrent 4.3.8安装成功"
            return 1
        fi
    else
        log_error "qBittorrent 4.3.8安装失败，停止安装"
        return 1
    fi
}

# 安装qBittorrent 4.3.9 + Vertex
install_qb_439_vertex() {
    log_info "开始安装qBittorrent 4.3.9 + Vertex组合..."
    
    if install_qb_439; then
        echo -e "${CYAN}qBittorrent 4.3.9 安装完成，继续安装 Vertex...${NC}"
        sleep 3
        if install_vertex; then
            echo
            echo -e "${GREEN}🎉 qBittorrent 4.3.9 + Vertex 组合安装完成！${NC}"
            show_combined_info
            return 0
        else
            log_error "Vertex安装失败，但qBittorrent 4.3.9安装成功"
            return 1
        fi
    else
        log_error "qBittorrent 4.3.9安装失败，停止安装"
        return 1
    fi
}

# 显示组合安装信息
show_combined_info() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}组合服务访问信息：${NC}"
    
    # qBittorrent信息
    if systemctl is-active --quiet qbittorrent 2>/dev/null; then
        local qb_port=$(ss -tulnp | grep qbittorrent | grep -o ':\d\+' | head -1 | tr -d ':')
        if [[ -n "$qb_port" ]]; then
            echo -e "${CYAN}  qBittorrent：http://${SERVER_IP}:${qb_port}${NC}"
        fi
    fi
    
    # Vertex信息
    if docker ps | grep vertex > /dev/null; then
        local vertex_port=$(docker port vertex 2>/dev/null | grep 3000 | cut -d':' -f2)
        if [[ -n "$vertex_port" ]]; then
            echo -e "${CYAN}  Vertex：http://${SERVER_IP}:${vertex_port}${NC}"
        fi
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 显示主菜单
show_main_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                       PTtools v${SCRIPT_VERSION}                        ║"
    echo "║                   PT工具一键安装脚本                           ║"
    echo "║                  调用现有脚本 稳定可靠                          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}核心安装选项：${NC}"
    echo -e "${WHITE}1)${NC} 安装 qBittorrent 4.3.8  ${GRAY}(调用 qb438.sh)${NC}"
    echo -e "${WHITE}2)${NC} 安装 qBittorrent 4.3.9  ${GRAY}(调用 qb439.sh)${NC}"
    echo -e "${WHITE}3)${NC} 安装 qBittorrent 4.3.8 + Vertex"
    echo -e "${WHITE}4)${NC} 安装 qBittorrent 4.3.9 + Vertex"
    echo
    echo -e "${CYAN}其他选项：${NC}"
    echo -e "${WHITE}5)${NC} 查看安装状态"
    echo -e "${WHITE}6)${NC} 退出脚本"
    echo
    echo -e "${YELLOW}提示：选项1和2将调用项目中现有的qb438.sh和qb439.sh脚本${NC}"
    echo
}

# 查看安装状态
show_install_status() {
    clear
    echo -e "${BLUE}系统安装状态${NC}"
    echo "=================================="
    
    # 检查已安装应用
    local config_file="${CONFIG_PATH}/installed_apps.conf"
    if [[ -f "$config_file" ]]; then
        echo -e "${GREEN}✓${NC} 已安装应用："
        grep -v "^#" "$config_file" 2>/dev/null | while IFS='=' read -r app time; do
            if [[ -n "$app" ]]; then
                echo -e "  - $app (安装时间: $time)"
            fi
        done
    else
        echo -e "${RED}✗${NC} 暂无已安装应用记录"
    fi
    
    echo
    
    # 检查Docker
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker已安装：$(docker --version | cut -d' ' -f3 | tr -d ',')"
        if systemctl is-active --quiet docker; then
            echo -e "${GREEN}✓${NC} Docker服务运行中"
        else
            echo -e "${RED}✗${NC} Docker服务未运行"
        fi
    else
        echo -e "${RED}✗${NC} Docker未安装"
    fi
    
    # 检查qBittorrent
    if command -v qbittorrent-nox &> /dev/null; then
        echo -e "${GREEN}✓${NC} qBittorrent已安装"
        if systemctl is-active --quiet qbittorrent 2>/dev/null; then
            echo -e "${GREEN}✓${NC} qBittorrent服务运行中"
            local qb_port=$(ss -tulnp | grep qbittorrent | grep -o ':\d\+' | head -1 | tr -d ':')
            if [[ -n "$qb_port" ]]; then
                echo -e "  访问地址：http://${SERVER_IP}:${qb_port}"
            fi
        else
            echo -e "${YELLOW}!${NC} qBittorrent服务状态未知"
        fi
    else
        echo -e "${RED}✗${NC} qBittorrent未安装"
    fi
    
    # 检查Vertex
    if docker ps | grep vertex > /dev/null; then
        echo -e "${GREEN}✓${NC} Vertex容器运行中"
        local vertex_port=$(docker port vertex 2>/dev/null | grep 3000 | cut -d':' -f2)
        if [[ -n "$vertex_port" ]]; then
            echo -e "  访问地址：http://${SERVER_IP}:${vertex_port}"
        fi
    elif docker ps -a | grep vertex > /dev/null; then
        echo -e "${YELLOW}!${NC} Vertex容器已创建但未运行"
    else
        echo -e "${RED}✗${NC} Vertex未安装"
    fi
    
    # 显示日志信息
    echo
    echo -e "${CYAN}日志文件：${NC}"
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "  安装日志：$LOG_FILE"
        local log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1)
        echo -e "  日志大小：${log_size:-未知}"
    else
        echo -e "  暂无日志文件"
    fi
    
    echo
    read -p "按任意键返回主菜单..." -n 1
}

# 初始化
init() {
    check_root
    detect_system
    get_server_ip
    check_system_compatibility
    create_directories
    
    # 创建日志文件
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    log_info "PTtools v${SCRIPT_VERSION} 启动"
    log_info "系统：$OS $OS_VERSION"
    log_info "服务器IP：$SERVER_IP"
    log_info "项目地址：https://github.com/everett7623/PTtools"
}

# 主函数
main() {
    init
    
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
                if [[ $? -eq 0 ]]; then
                    install_qb_438_vertex
                fi
                read -p "按任意键继续..." -n 1
                ;;
            4)
                install_docker
                if [[ $? -eq 0 ]]; then
                    install_qb_439_vertex
                fi
                read -p "按任意键继续..." -n 1
                ;;
            5)
                show_install_status
                ;;
            6)
                echo -e "${GREEN}感谢使用PTtools！${NC}"
                log_info "PTtools正常退出"
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
