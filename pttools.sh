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
NC='\033[0m' # No Color

# 全局变量
SCRIPT_VERSION="1.0.0"
INSTALL_PATH="/opt/docker"
DOWNLOAD_PATH="/opt/downloads"
CONFIG_PATH="/etc/pttools"
LOG_PATH="/var/log/pttools"
LOG_FILE="${LOG_PATH}/install.log"

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：此脚本需要root权限运行${NC}"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建必要的目录结构..."
    
    # 创建主要目录
    mkdir -p "${INSTALL_PATH}"
    mkdir -p "${DOWNLOAD_PATH}"/{completed,incomplete,torrents}
    mkdir -p "${CONFIG_PATH}"
    mkdir -p "${LOG_PATH}"
    
    # 创建应用数据目录
    mkdir -p "${INSTALL_PATH}"/{qbittorrent,transmission,emby,iyuuplus,moviepilot,vertex}
    
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

# 安装Docker
install_docker() {
    log_info "开始安装Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker已安装，跳过安装步骤"
        return 0
    fi
    
    # 询问是否使用国内镜像
    echo -e "${CYAN}是否使用阿里云镜像安装Docker？${NC}"
    echo "1) 是 (国内用户推荐)"
    echo "2) 否 (使用官方镜像)"
    read -p "请选择 [1-2]: " docker_mirror_choice
    
    case $docker_mirror_choice in
        1)
            log_info "使用阿里云镜像安装Docker..."
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            ;;
        2)
            log_info "使用官方镜像安装Docker..."
            curl -fsSL https://get.docker.com | bash -s docker
            ;;
        *)
            log_warn "无效选择，使用官方镜像安装..."
            curl -fsSL https://get.docker.com | bash -s docker
            ;;
    esac
    
    # 启动Docker服务
    systemctl enable docker
    systemctl start docker
    
    # 安装docker-compose
    if ! command -v docker-compose &> /dev/null; then
        log_info "安装docker-compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    log_info "Docker安装完成"
}

# 获取用户输入
get_user_credentials() {
    echo -e "${CYAN}请设置qBittorrent Web UI登录信息：${NC}"
    read -p "用户名 [默认: admin]: " QB_USERNAME
    QB_USERNAME=${QB_USERNAME:-admin}
    
    while true; do
        read -s -p "密码 [至少8位]: " QB_PASSWORD
        echo
        if [[ ${#QB_PASSWORD} -ge 8 ]]; then
            break
        else
            echo -e "${RED}密码至少需要8位，请重新输入${NC}"
        fi
    done
    
    echo -e "${CYAN}请设置端口信息：${NC}"
    read -p "Web UI端口 [默认: 8080]: " QB_WEBUI_PORT
    QB_WEBUI_PORT=${QB_WEBUI_PORT:-8080}
    
    read -p "守护进程端口 [默认: 23333]: " QB_DAEMON_PORT
    QB_DAEMON_PORT=${QB_DAEMON_PORT:-23333}
    
    # 保存配置
    save_config
}

# 保存配置到文件
save_config() {
    cat > "${CONFIG_PATH}/config.conf" << EOF
# PTtools 配置文件
PTTOOLS_VERSION="${SCRIPT_VERSION}"
INSTALL_PATH="${INSTALL_PATH}"
DOWNLOAD_PATH="${DOWNLOAD_PATH}"
LOG_PATH="${LOG_PATH}"

# qBittorrent 配置
QB_USERNAME="${QB_USERNAME}"
QB_PASSWORD="${QB_PASSWORD}"
QB_WEBUI_PORT="${QB_WEBUI_PORT}"
QB_DAEMON_PORT="${QB_DAEMON_PORT}"

# 安装时间
INSTALL_DATE="$(date +'%Y-%m-%d %H:%M:%S')"
EOF
    
    log_info "配置已保存到 ${CONFIG_PATH}/config.conf"
}

# 安装qBittorrent 4.3.8 (使用iniwex5脚本)
install_qb_438() {
    log_info "开始安装qBittorrent 4.3.8..."
    
    get_user_credentials
    
    log_info "下载并执行qBittorrent 4.3.8安装脚本..."
    bash <(wget -qO- https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh) "${QB_USERNAME}" "${QB_PASSWORD}" "${QB_WEBUI_PORT}" "${QB_DAEMON_PORT}"
    
    if [[ $? -eq 0 ]]; then
        log_info "qBittorrent 4.3.8安装完成"
        echo -e "${GREEN}qBittorrent 4.3.8安装成功！${NC}"
        echo -e "${CYAN}访问地址：http://$(curl -s ifconfig.me):${QB_WEBUI_PORT}${NC}"
        echo -e "${CYAN}用户名：${QB_USERNAME}${NC}"
        echo -e "${CYAN}密码：${QB_PASSWORD}${NC}"
    else
        log_error "qBittorrent 4.3.8安装失败"
        return 1
    fi
}

# 安装qBittorrent 4.3.9 (使用jerry048脚本)
install_qb_439() {
    log_info "开始安装qBittorrent 4.3.9..."
    
    get_user_credentials
    
    # 询问缓存大小
    read -p "请输入qBittorrent缓存大小(MB) [默认: 3072]: " QB_CACHE_SIZE
    QB_CACHE_SIZE=${QB_CACHE_SIZE:-3072}
    
    # 询问是否启用额外功能
    echo -e "${CYAN}是否启用以下功能？${NC}"
    read -p "启用autobrr? [y/N]: " ENABLE_AUTOBRR
    read -p "启用autoremove-torrents? [y/N]: " ENABLE_AUTOREMOVE
    read -p "启用BBRx加速? [y/N]: " ENABLE_BBRX
    
    # 构建安装命令
    local install_cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u ${QB_USERNAME} -p ${QB_PASSWORD} -c ${QB_CACHE_SIZE} -q 4.3.9 -l v1.2.20"
    
    [[ "${ENABLE_AUTOBRR,,}" == "y" ]] && install_cmd+=" -b"
    [[ "${ENABLE_AUTOREMOVE,,}" == "y" ]] && install_cmd+=" -r"
    [[ "${ENABLE_BBRX,,}" == "y" ]] && install_cmd+=" -x"
    
    if [[ "${QB_WEBUI_PORT}" != "8080" ]] || [[ "${QB_DAEMON_PORT}" != "23333" ]]; then
        install_cmd+=" -o"
    fi
    
    log_info "执行安装命令：$install_cmd"
    eval "$install_cmd"
    
    if [[ $? -eq 0 ]]; then
        log_info "qBittorrent 4.3.9安装完成"
        echo -e "${GREEN}qBittorrent 4.3.9安装成功！${NC}"
        echo -e "${CYAN}访问地址：http://$(curl -s ifconfig.me):${QB_WEBUI_PORT}${NC}"
        echo -e "${CYAN}用户名：${QB_USERNAME}${NC}"
        echo -e "${CYAN}密码：${QB_PASSWORD}${NC}"
    else
        log_error "qBittorrent 4.3.9安装失败"
        return 1
    fi
}

# 安装Vertex
install_vertex() {
    log_info "开始安装Vertex..."
    
    # 创建Vertex目录
    mkdir -p "${INSTALL_PATH}/vertex"
    
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
      - "3334:3000"
    restart: unless-stopped
EOF
    
    # 启动Vertex
    cd "${INSTALL_PATH}/vertex"
    docker-compose up -d
    
    if [[ $? -eq 0 ]]; then
        log_info "Vertex安装完成"
        echo -e "${GREEN}Vertex安装成功！${NC}"
        echo -e "${CYAN}访问地址：http://$(curl -s ifconfig.me):3334${NC}"
    else
        log_error "Vertex安装失败"
        return 1
    fi
}

# 安装qBittorrent 4.3.8 + Vertex
install_qb_438_vertex() {
    log_info "开始安装qBittorrent 4.3.8 + Vertex组合..."
    
    install_qb_438
    if [[ $? -eq 0 ]]; then
        install_vertex
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}qBittorrent 4.3.8 + Vertex组合安装完成！${NC}"
        fi
    fi
}

# 安装qBittorrent 4.3.9 + Vertex
install_qb_439_vertex() {
    log_info "开始安装qBittorrent 4.3.9 + Vertex组合..."
    
    install_qb_439
    if [[ $? -eq 0 ]]; then
        install_vertex
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}qBittorrent 4.3.9 + Vertex组合安装完成！${NC}"
        fi
    fi
}

# VPS优化
optimize_vps() {
    log_info "开始VPS优化..."
    
    # 网络优化
    cat >> /etc/sysctl.conf << EOF

# PTtools VPS优化配置
# 网络优化
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
net.ipv4.tcp_congestion_control = bbr

# 文件描述符限制
fs.file-max = 2097152
EOF
    
    # 应用网络优化
    sysctl -p
    
    # 设置文件描述符限制
    cat >> /etc/security/limits.conf << EOF

# PTtools 文件描述符限制
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF
    
    # 启用BBR
    if ! lsmod | grep -q bbr; then
        echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
        echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
        sysctl -p
        log_info "BBR拥塞控制已启用"
    fi
    
    log_info "VPS优化完成"
}

# 显示主菜单
show_main_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                        PTtools v${SCRIPT_VERSION}                        ║"
    echo "║                   PT工具一键安装脚本                           ║"
    echo "║                 作者：everett7623                              ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}核心项目安装选项：${NC}"
    echo -e "${WHITE}1)${NC} 安装 qBittorrent 4.3.8"
    echo -e "${WHITE}2)${NC} 安装 qBittorrent 4.3.9"
    echo -e "${WHITE}3)${NC} 安装 qBittorrent 4.3.8 + Vertex"
    echo -e "${WHITE}4)${NC} 安装 qBittorrent 4.3.9 + Vertex"
    echo
    echo -e "${CYAN}系统功能：${NC}"
    echo -e "${WHITE}5)${NC} 选择安装应用 (开发中...)"
    echo -e "${WHITE}6)${NC} VPS优化"
    echo -e "${WHITE}7)${NC} 卸载选项 (开发中...)"
    echo -e "${WHITE}8)${NC} 查看系统状态"
    echo -e "${WHITE}9)${NC} 退出"
    echo
}

# 显示系统状态
show_system_status() {
    clear
    echo -e "${BLUE}系统状态信息${NC}"
    echo "=================================="
    
    # 系统信息
    echo -e "${CYAN}系统信息：${NC}"
    echo "操作系统：$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "内核版本：$(uname -r)"
    echo "CPU架构：$(uname -m)"
    
    # 内存信息
    echo -e "\n${CYAN}内存信息：${NC}"
    free -h
    
    # 磁盘信息
    echo -e "\n${CYAN}磁盘使用情况：${NC}"
    df -h /
    
    # Docker状态
    echo -e "\n${CYAN}Docker状态：${NC}"
    if command -v docker &> /dev/null; then
        echo "Docker版本：$(docker --version)"
        echo "运行中的容器："
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo "Docker未安装"
    fi
    
    echo
    read -p "按任意键返回主菜单..." -n 1
}

# 初始化
init() {
    check_root
    detect_system
    create_directories
    
    # 创建日志文件
    touch "$LOG_FILE"
    
    log_info "PTtools v${SCRIPT_VERSION} 启动"
    log_info "系统：$OS $OS_VERSION"
}

# 主函数
main() {
    init
    
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
                install_qb_438_vertex
                read -p "按任意键继续..." -n 1
                ;;
            4)
                install_docker
                install_qb_439_vertex
                read -p "按任意键继续..." -n 1
                ;;
            5)
                echo -e "${YELLOW}选择安装应用功能正在开发中...${NC}"
                read -p "按任意键继续..." -n 1
                ;;
            6)
                optimize_vps
                echo -e "${GREEN}VPS优化完成！${NC}"
                read -p "按任意键继续..." -n 1
                ;;
            7)
                echo -e "${YELLOW}卸载功能正在开发中...${NC}"
                read -p "按任意键继续..." -n 1
                ;;
            8)
                show_system_status
                ;;
            9)
                echo -e "${GREEN}感谢使用PTtools！${NC}"
                log_info "PTtools退出"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                sleep 2
                ;;
        esac
    done
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
