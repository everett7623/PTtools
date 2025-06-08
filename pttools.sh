#!/bin/bash

# PTtools - PT工具一键安装脚本
# Github: https://github.com/everett7623/PTtools
# 作者: everett7623

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
SCRIPT_DIR="/opt/pttools"
DOCKER_DIR="/opt/docker"
DOWNLOAD_DIR="/opt/downloads"
GITHUB_REPO="https://raw.githubusercontent.com/everett7623/PTtools/main"
COMPOSE_DIR="$DOCKER_DIR/compose"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检查系统信息
check_system() {
    log_info "检查系统信息..."
    
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "无法识别操作系统"
        exit 1
    fi
    
    log_info "操作系统: $OS $VER"
    
    # 检查架构
    ARCH=$(uname -m)
    log_info "系统架构: $ARCH"
    
    # 检查网络连接
    if ! ping -c 1 google.com &> /dev/null; then
        log_warn "网络连接可能存在问题"
    fi
}

# 安装基础依赖
install_dependencies() {
    log_info "安装基础依赖..."
    
    # 更新软件包列表
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y curl wget git unzip zip nano vim htop
    elif command -v yum &> /dev/null; then
        yum update -y
        yum install -y curl wget git unzip zip nano vim htop
    elif command -v dnf &> /dev/null; then
        dnf update -y
        dnf install -y curl wget git unzip zip nano vim htop
    else
        log_error "不支持的包管理器"
        exit 1
    fi
}

# 安装Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker已安装，跳过安装步骤"
        return 0
    fi
    
    log_info "安装Docker..."
    
    # 官方安装脚本
    curl -fsSL https://get.docker.com | bash
    
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
    
    # 检查安装是否成功
    if command -v docker &> /dev/null; then
        log_info "Docker安装成功"
    else
        log_error "Docker安装失败"
        exit 1
    fi
}

# 安装Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose已安装，跳过安装步骤"
        return 0
    fi
    
    log_info "安装Docker Compose..."
    
    # 获取最新版本号
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    # 下载并安装
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # 创建软链接
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    # 检查安装
    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose安装成功"
    else
        log_error "Docker Compose安装失败"
        exit 1
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    mkdir -p "$SCRIPT_DIR"
    mkdir -p "$DOCKER_DIR"
    mkdir -p "$DOWNLOAD_DIR"
    mkdir -p "$COMPOSE_DIR"
    
    # 创建各应用目录
    mkdir -p "$DOCKER_DIR/qbittorrent/config"
    mkdir -p "$DOCKER_DIR/transmission/config"
    mkdir -p "$DOCKER_DIR/emby/config"
    mkdir -p "$DOCKER_DIR/jellyfin/config"
    mkdir -p "$DOCKER_DIR/plex/config"
    mkdir -p "$DOCKER_DIR/jackett/config"
    mkdir -p "$DOCKER_DIR/prowlarr/config"
    mkdir -p "$DOCKER_DIR/sonarr/config"
    mkdir -p "$DOCKER_DIR/radarr/config"
    mkdir -p "$DOCKER_DIR/lidarr/config"
    mkdir -p "$DOCKER_DIR/bazarr/config"
    
    log_info "目录结构创建完成"
}

# 下载配置文件
download_configs() {
    log_info "下载配置文件..."
    
    # 下载docker-compose文件
    configs=(
        "qbittorrent.yml"
        "transmission.yml"
        "emby.yml"
        "jellyfin.yml"
        "plex.yml"
        "jackett.yml"
        "prowlarr.yml"
        "sonarr.yml"
        "radarr.yml"
        "lidarr.yml"
        "bazarr.yml"
    )
    
    for config in "${configs[@]}"; do
        if [ ! -f "$COMPOSE_DIR/$config" ]; then
            wget -O "$COMPOSE_DIR/$config" "$GITHUB_REPO/configs/docker-compose/$config" || log_warn "下载 $config 失败"
        fi
    done
}

# qBittorrent 4.3.8安装
install_qb438() {
    log_info "安装qBittorrent 4.3.8..."
    
    # 下载安装脚本
    wget -O /tmp/qb438.sh "$GITHUB_REPO/scripts/install/qb438.sh"
    chmod +x /tmp/qb438.sh
    
    # 执行安装
    bash /tmp/qb438.sh
    
    # 清理临时文件
    rm -f /tmp/qb438.sh
}

# qBittorrent 4.3.9安装
install_qb439() {
    log_info "安装qBittorrent 4.3.9..."
    
    # 下载安装脚本
    wget -O /tmp/qb439.sh "$GITHUB_REPO/scripts/install/qb439.sh"
    chmod +x /tmp/qb439.sh
    
    # 执行安装
    bash /tmp/qb439.sh
    
    # 清理临时文件
    rm -f /tmp/qb439.sh
}

# Docker应用安装函数
install_docker_app() {
    local app_name=$1
    local compose_file="$COMPOSE_DIR/${app_name}.yml"
    
    if [ ! -f "$compose_file" ]; then
        log_error "配置文件 $compose_file 不存在"
        return 1
    fi
    
    log_info "安装 $app_name..."
    
    cd "$COMPOSE_DIR"
    docker-compose -f "$compose_file" up -d
    
    if [ $? -eq 0 ]; then
        log_info "$app_name 安装成功"
    else
        log_error "$app_name 安装失败"
        return 1
    fi
}

# Transmission安装
install_transmission() {
    install_docker_app "transmission"
}

# Emby安装
install_emby() {
    install_docker_app "emby"
}

# Jellyfin安装
install_jellyfin() {
    install_docker_app "jellyfin"
}

# Plex安装
install_plex() {
    install_docker_app "plex"
}

# Jackett安装
install_jackett() {
    install_docker_app "jackett"
}

# Prowlarr安装
install_prowlarr() {
    install_docker_app "prowlarr"
}

# Sonarr安装
install_sonarr() {
    install_docker_app "sonarr"
}

# Radarr安装
install_radarr() {
    install_docker_app "radarr"
}

# Lidarr安装
install_lidarr() {
    install_docker_app "lidarr"
}

# Bazarr安装
install_bazarr() {
    install_docker_app "bazarr"
}

# 一键安装全部应用
install_all_apps() {
    log_info "开始一键安装所有应用..."
    
    # 安装基础环境
    install_dependencies
    install_docker
    install_docker_compose
    create_directories
    download_configs
    
    # 安装应用
    install_qb439  # 默认安装4.3.9版本
    install_transmission
    install_emby
    install_jackett
    install_prowlarr
    install_sonarr
    install_radarr
    install_lidarr
    install_bazarr
    
    log_info "所有应用安装完成！"
}

# 卸载Docker应用
uninstall_docker_app() {
    local app_name=$1
    local compose_file="$COMPOSE_DIR/${app_name}.yml"
    
    if [ ! -f "$compose_file" ]; then
        log_warn "配置文件 $compose_file 不存在，跳过卸载"
        return 0
    fi
    
    log_info "卸载 $app_name..."
    
    cd "$COMPOSE_DIR"
    docker-compose -f "$compose_file" down
    docker-compose -f "$compose_file" rm -f
    
    # 询问是否删除数据
    read -p "是否删除 $app_name 的配置数据？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DOCKER_DIR/$app_name"
        log_info "$app_name 数据已删除"
    fi
}

# 卸载qBittorrent
uninstall_qbittorrent() {
    log_info "卸载qBittorrent..."
    
    # 停止服务
    systemctl stop qbittorrent
    systemctl disable qbittorrent
    
    # 删除用户和服务文件
    userdel -r qbittorrent 2>/dev/null
    rm -f /etc/systemd/system/qbittorrent.service
    systemctl daemon-reload
    
    # 询问是否删除数据
    read -p "是否删除qBittorrent的数据？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf /home/qbittorrent
        log_info "qBittorrent数据已删除"
    fi
}

# 部分卸载菜单
partial_uninstall_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║            PTtools - 部分卸载         ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}请选择要卸载的应用:${NC}"
        echo
        echo -e "${GREEN}1.${NC}  卸载 qBittorrent"
        echo -e "${GREEN}2.${NC}  卸载 Transmission"
        echo -e "${GREEN}3.${NC}  卸载 Emby"
        echo -e "${GREEN}4.${NC}  卸载 Jellyfin"
        echo -e "${GREEN}5.${NC}  卸载 Plex"
        echo -e "${GREEN}6.${NC}  卸载 Jackett"
        echo -e "${GREEN}7.${NC}  卸载 Prowlarr"
        echo -e "${GREEN}8.${NC}  卸载 Sonarr"
        echo -e "${GREEN}9.${NC}  卸载 Radarr"
        echo -e "${GREEN}10.${NC} 卸载 Lidarr"
        echo -e "${GREEN}11.${NC} 卸载 Bazarr"
        echo
        echo -e "${RED}0.${NC}  返回主菜单"
        echo
        read -p "请输入选项 [0-11]: " choice
        
        case $choice in
            1) uninstall_qbittorrent ;;
            2) uninstall_docker_app "transmission" ;;
            3) uninstall_docker_app "emby" ;;
            4) uninstall_docker_app "jellyfin" ;;
            5) uninstall_docker_app "plex" ;;
            6) uninstall_docker_app "jackett" ;;
            7) uninstall_docker_app "prowlarr" ;;
            8) uninstall_docker_app "sonarr" ;;
            9) uninstall_docker_app "radarr" ;;
            10) uninstall_docker_app "lidarr" ;;
            11) uninstall_docker_app "bazarr" ;;
            0) return ;;
            *) log_error "无效选项，请重新选择" ;;
        esac
        
        if [ "$choice" != "0" ]; then
            read -p "按回车键继续..." 
        fi
    done
}

# 完全卸载
complete_uninstall() {
    log_warn "警告：这将卸载所有PTtools安装的应用和Docker！"
    read -p "确定要继续吗？(y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    log_info "开始完全卸载..."
    
    # 停止所有容器
    docker stop $(docker ps -aq) 2>/dev/null
    docker rm $(docker ps -aq) 2>/dev/null
    
    # 卸载各个应用
    uninstall_qbittorrent
    
    # 卸载Docker
    if command -v docker &> /dev/null; then
        log_info "卸载Docker..."
        
        # 移除Docker包
        if command -v apt-get &> /dev/null; then
            apt-get remove -y docker docker-engine docker.io containerd runc
            apt-get autoremove -y
        elif command -v yum &> /dev/null; then
            yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
        fi
        
        # 删除Docker数据
        rm -rf /var/lib/docker
        rm -rf /var/lib/containerd
    fi
    
    # 删除PTtools目录
    read -p "是否删除所有PTtools数据和配置？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$SCRIPT_DIR"
        rm -rf "$DOCKER_DIR"
        rm -rf "$DOWNLOAD_DIR"
        log_info "所有数据已删除"
    fi
    
    log_info "完全卸载完成！"
}

# 显示系统状态
show_status() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            PTtools - 系统状态         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
    echo
    
    # Docker状态
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker: 已安装"
        echo "  版本: $(docker --version)"
    else
        echo -e "${RED}✗${NC} Docker: 未安装"
    fi
    
    # Docker Compose状态
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker Compose: 已安装"
        echo "  版本: $(docker-compose --version)"
    else
        echo -e "${RED}✗${NC} Docker Compose: 未安装"
    fi
    
    echo
    echo -e "${WHITE}运行中的容器:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "无运行中的容器"
    
    echo
    echo -e "${WHITE}系统资源使用:${NC}"
    echo "内存使用: $(free -h | awk 'NR==2{printf "%.1f%% (%s/%s)", $3*100/$2, $3, $2}')"
    echo "磁盘使用: $(df -h / | awk 'NR==2{printf "%s (%s)", $5, $4}')"
    
    read -p "按回车键返回主菜单..."
}

# 管理菜单
management_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║            PTtools - 管理菜单         ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}管理选项:${NC}"
        echo
        echo -e "${GREEN}1.${NC}  查看系统状态"
        echo -e "${GREEN}2.${NC}  重启所有容器"
        echo -e "${GREEN}3.${NC}  停止所有容器"
        echo -e "${GREEN}4.${NC}  启动所有容器"
        echo -e "${GREEN}5.${NC}  清理Docker资源"
        echo -e "${GREEN}6.${NC}  更新PTtools脚本"
        echo
        echo -e "${RED}0.${NC}  返回主菜单"
        echo
        read -p "请输入选项 [0-6]: " choice
        
        case $choice in
            1) show_status ;;
            2) 
                log_info "重启所有容器..."
                docker restart $(docker ps -aq) 2>/dev/null
                log_info "重启完成"
                read -p "按回车键继续..."
                ;;
            3) 
                log_info "停止所有容器..."
                docker stop $(docker ps -aq) 2>/dev/null
                log_info "停止完成"
                read -p "按回车键继续..."
                ;;
            4) 
                log_info "启动所有容器..."
                docker start $(docker ps -aq) 2>/dev/null
                log_info "启动完成"
                read -p "按回车键继续..."
                ;;
            5) 
                log_info "清理Docker资源..."
                docker system prune -f
                log_info "清理完成"
                read -p "按回车键继续..."
                ;;
            6) 
                log_info "更新PTtools脚本..."
                wget -O /tmp/pttools_new.sh https://raw.githubusercontent.com/everett7623/PTtools/main/pttools.sh
                if [ $? -eq 0 ]; then
                    cp /tmp/pttools_new.sh "$0"
                    chmod +x "$0"
                    log_info "脚本更新成功，请重新运行脚本"
                    exit 0
                else
                    log_error "脚本更新失败"
                fi
                read -p "按回车键继续..."
                ;;
            0) return ;;
            *) log_error "无效选项，请重新选择" ;;
        esac
    done
}

# 安装菜单
install_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║            PTtools - 安装菜单         ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}下载工具:${NC}"
        echo -e "${GREEN}1.${NC}  qBittorrent 4.3.8"
        echo -e "${GREEN}2.${NC}  qBittorrent 4.3.9 ${YELLOW}(推荐)${NC}"
        echo -e "${GREEN}3.${NC}  Transmission"
        echo
        echo -e "${WHITE}媒体服务器:${NC}"
        echo -e "${GREEN}4.${NC}  Emby"
        echo -e "${GREEN}5.${NC}  Jellyfin"
        echo -e "${GREEN}6.${NC}  Plex"
        echo
        echo -e "${WHITE}索引器/搜索:${NC}"
        echo -e "${GREEN}7.${NC}  Jackett"
        echo -e "${GREEN}8.${NC}  Prowlarr ${YELLOW}(推荐)${NC}"
        echo
        echo -e "${WHITE}自动化工具:${NC}"
        echo -e "${GREEN}9.${NC}  Sonarr (电视剧)"
        echo -e "${GREEN}10.${NC} Radarr (电影)"
        echo -e "${GREEN}11.${NC} Lidarr (音乐)"
        echo -e "${GREEN}12.${NC} Bazarr (字幕)"
        echo
        echo -e "${WHITE}快捷选项:${NC}"
        echo -e "${PURPLE}88.${NC} 一键安装全部应用"
        echo -e "${PURPLE}99.${NC} 安装基础环境 (Docker + Docker Compose)"
        echo
        echo -e "${RED}0.${NC}  返回主菜单"
        echo
        read -p "请输入选项 [0-12,88,99]: " choice
        
        case $choice in
            1) install_qb438 ;;
            2) install_qb439 ;;
            3) install_transmission ;;
            4) install_emby ;;
            5) install_jellyfin ;;
            6) install_plex ;;
            7) install_jackett ;;
            8) install_prowlarr ;;
            9) install_sonarr ;;
            10) install_radarr ;;
            11) install_lidarr ;;
            12) install_bazarr ;;
            88) install_all_apps ;;
            99) 
                install_dependencies
                install_docker
                install_docker_compose
                create_directories
                download_configs
                ;;
            0) return ;;
            *) log_error "无效选项，请重新选择" ;;
        esac
        
        if [ "$choice" != "0" ]; then
            read -p "按回车键继续..." 
        fi
    done
}

# 卸载菜单
uninstall_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║            PTtools - 卸载菜单         ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}卸载选项:${NC}"
        echo
        echo -e "${YELLOW}1.${NC}  部分卸载 (选择特定应用)"
        echo -e "${RED}2.${NC}  完全卸载 (所有应用和Docker)"
        echo
        echo -e "${GREEN}0.${NC}  返回主菜单"
        echo
        read -p "请输入选项 [0-2]: " choice
        
        case $choice in
            1) partial_uninstall_menu ;;
            2) complete_uninstall ;;
            0) return ;;
            *) log_error "无效选项，请重新选择" ;;
        esac
        
        if [ "$choice" != "0" ]; then
            read -p "按回车键继续..." 
        fi
    done
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║              PTtools v1.0             ║${NC}"
        echo -e "${CYAN}║        PT工具一键安装脚本            ║${NC}"
        echo -e "${CYAN}║     Github: everett7623/PTtools      ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}主菜单选项:${NC}"
        echo
        echo -e "${GREEN}1.${NC}  安装应用"
        echo -e "${YELLOW}2.${NC}  卸载应用"
        echo -e "${BLUE}3.${NC}  管理工具"
        echo -e "${PURPLE}4.${NC}  系统状态"
        echo
        echo -e "${RED}0.${NC}  退出脚本"
        echo
        read -p "请输入选项 [0-4]: " choice
        
        case $choice in
            1) install_menu ;;
            2) uninstall_menu ;;
            3) management_menu ;;
            4) show_status ;;
            0) 
                log_info "感谢使用PTtools！"
                exit 0
                ;;
            *) log_error "无效选项，请重新选择" ;;
        esac
    done
}

# 脚本入口
main() {
    # 检查root权限
    check_root
    
    # 检查系统
    check_system
    
    # 显示欢迎信息
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            欢迎使用 PTtools           ║${NC}"
    echo -e "${CYAN}║                                       ║${NC}"
    echo -e "${CYAN}║       PT工具快速安装脚本              ║${NC}"
    echo -e "${CYAN}║                                       ║${NC}"
    echo -e "${CYAN}║    适用于小白用户的一键安装方案       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
    echo
    echo -e "${WHITE}支持的应用:${NC}"
    echo -e "  • qBittorrent (4.3.8/4.3.9)"
    echo -e "  • Transmission"
    echo -e "  • Emby/Jellyfin/Plex"
    echo -e "  • Jackett/Prowlarr"
    echo -e "  • Sonarr/Radarr/Lidarr/Bazarr"
    echo
    echo -e "${WHITE}安装路径:${NC}"
    echo -e "  • Docker应用: ${DOCKER_DIR}"
    echo -e "  • 下载目录: ${DOWNLOAD_DIR}"
    echo
    read -p "按回车键进入主菜单..."
    
    # 进入主菜单
    main_menu
}

# 启动脚本
main "$@"
