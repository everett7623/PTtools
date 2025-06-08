#!/bin/bash

# PTtools - PT工具一键安装脚本
# Github: https://github.com/everett7623/PTtools
# 作者: everett7623
# 专为PT刷流优化设计

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

# VPS性能优化 - PT刷流专用
optimize_vps_for_pt() {
    log_info "应用VPS PT刷流优化配置..."
    
    # 网络优化
    cat > /etc/sysctl.d/99-pttools-optimization.conf << EOF
# PTtools VPS优化配置 - 专为PT刷流设计

# 网络缓冲区优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# TCP优化
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_mtu_probing = 1

# 连接跟踪优化
net.netfilter.nf_conntrack_max = 25000000
net.netfilter.nf_conntrack_tcp_timeout_established = 180
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120

# 文件系统优化
fs.file-max = 1000000
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 1024

# 虚拟内存优化
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
vm.overcommit_memory = 1

# 进程和线程优化
kernel.pid_max = 65536
kernel.threads-max = 1000000
EOF

    # 应用系统优化
    sysctl -p /etc/sysctl.d/99-pttools-optimization.conf
    
    # 优化文件描述符限制
    cat >> /etc/security/limits.conf << EOF

# PTtools 文件描述符优化
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 1000000
* hard nproc 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF

    # 优化systemd默认限制
    mkdir -p /etc/systemd/system.conf.d
    cat > /etc/systemd/system.conf.d/pttools.conf << EOF
[Manager]
DefaultLimitNOFILE=1000000
DefaultLimitNPROC=1000000
EOF

    # 启用BBR拥塞控制
    modprobe tcp_bbr
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    
    log_info "VPS优化配置已应用，重启后生效"
}

# 安装基础依赖
install_dependencies() {
    log_info "安装基础依赖..."
    
    # 更新软件包列表
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y curl wget git unzip zip nano vim htop iotop vnstat
    elif command -v yum &> /dev/null; then
        yum update -y
        yum install -y curl wget git unzip zip nano vim htop iotop vnstat
    elif command -v dnf &> /dev/null; then
        dnf update -y
        dnf install -y curl wget git unzip zip nano vim htop iotop vnstat
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
    
    # 优化Docker配置
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 5,
    "default-ulimits": {
        "nofile": {
            "name": "nofile",
            "hard": 1000000,
            "soft": 1000000
        }
    }
}
EOF

    systemctl restart docker
    
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
    
    # 创建优化的下载目录结构
    mkdir -p "$DOWNLOAD_DIR"/{complete,incomplete,watch,torrents}
    mkdir -p "$DOWNLOAD_DIR"/complete/{movies,tv,music,software,books}
    
    # 创建各应用目录
    mkdir -p "$DOCKER_DIR"/{qbittorrent,transmission,vertex,emby,jellyfin,plex,jackett,prowlarr,sonarr,radarr,lidarr,bazarr}/config
    
    log_info "目录结构创建完成"
}

# 下载配置文件
download_configs() {
    log_info "下载配置文件..."
    
    # 下载docker-compose文件
    configs=(
        "qbittorrent.yml"
        "transmission.yml"
        "vertex.yml"
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
            wget -O "$COMPOSE_DIR/$config" "$GITHUB_REPO/configs/docker-compose/$config" 2>/dev/null || log_warn "下载 $config 失败"
        fi
    done
}

# qBittorrent 4.3.8安装
install_qb438() {
    log_info "安装qBittorrent 4.3.8 (PT优化版)..."
    
    # 先应用VPS优化
    optimize_vps_for_pt
    
    # 下载安装脚本
    wget -O /tmp/qb438.sh "$GITHUB_REPO/scripts/install/qb438.sh"
    chmod +x /tmp/qb438.sh
    
    # 执行安装
    bash /tmp/qb438.sh
    
    # 清理临时文件
    rm -f /tmp/qb438.sh
    
    log_info "qBittorrent 4.3.8 安装完成"
}

# qBittorrent 4.3.9安装
install_qb439() {
    log_info "安装qBittorrent 4.3.9 (PT优化版)..."
    
    # 先应用VPS优化
    optimize_vps_for_pt
    
    # 下载安装脚本
    wget -O /tmp/qb439.sh "$GITHUB_REPO/scripts/install/qb439.sh"
    chmod +x /tmp/qb439.sh
    
    # 执行安装
    bash /tmp/qb439.sh
    
    # 清理临时文件
    rm -f /tmp/qb439.sh
    
    log_info "qBittorrent 4.3.9 安装完成"
}

# PTBoost优化脚本安装
install_ptboost() {
    log_info "安装PTBoost性能优化脚本..."
    
    # 下载PTBoost脚本
    wget -O /tmp/ptboost.sh "$GITHUB_REPO/scripts/install/applications/ptboost.sh"
    chmod +x /tmp/ptboost.sh
    
    # 执行PTBoost优化
    bash /tmp/ptboost.sh
    
    # 清理临时文件
    rm -f /tmp/ptboost.sh
    
    log_info "PTBoost优化脚本安装完成"
}

# Vertex刷流工具安装
install_vertex() {
    log_info "安装Vertex刷流工具..."
    
    # 先安装基础环境
    install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
    
    # 下载并运行Vertex安装脚本
    wget -O /tmp/vertex.sh "$GITHUB_REPO/scripts/install/applications/vertex.sh"
    chmod +x /tmp/vertex.sh
    bash /tmp/vertex.sh
    
    # 清理临时文件
    rm -f /tmp/vertex.sh
    
    log_info "Vertex刷流工具安装完成"
}

# qBittorrent 4.3.8 + Vertex
install_qb438_with_vertex() {
    log_info "安装qBittorrent 4.3.8 + Vertex刷流工具..."
    
    install_qb438
    sleep 2
    # 安装Docker环境（如果还没有）
    install_docker
    install_docker_compose
    create_directories
    download_configs
    # 安装Vertex刷流工具
    install_vertex
    
    log_info "qBittorrent 4.3.8 + Vertex 安装完成"
}

# qBittorrent 4.3.9 + Vertex  
install_qb439_with_vertex() {
    log_info "安装qBittorrent 4.3.9 + Vertex刷流工具..."
    
    install_qb439
    sleep 2
    # 安装Docker环境（如果还没有）
    install_docker
    install_docker_compose
    create_directories
    download_configs
    # 安装Vertex刷流工具
    install_vertex
    
    log_info "qBittorrent 4.3.9 + Vertex 安装完成"
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

# 功能分类与工具列表菜单
application_category_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║         PTtools - 应用分类安装        ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}📥 下载工具:${NC}"
        echo -e "${GREEN}1.${NC}  Transmission (轻量级BT客户端)"
        echo -e "${GREEN}2.${NC}  Vertex (专业刷流工具) ${YELLOW}★刷流专用${NC}"
        echo
        echo -e "${WHITE}🎬 媒体服务器:${NC}"
        echo -e "${GREEN}3.${NC}  Emby (功能丰富)"
        echo -e "${GREEN}4.${NC}  Jellyfin (开源免费)"
        echo -e "${GREEN}5.${NC}  Plex (专业级)"
        echo
        echo -e "${WHITE}🔍 索引器/搜索:${NC}"
        echo -e "${GREEN}6.${NC}  Jackett (传统代理)"
        echo -e "${GREEN}7.${NC}  Prowlarr (新一代管理) ${YELLOW}★推荐${NC}"
        echo
        echo -e "${WHITE}🤖 自动化工具:${NC}"
        echo -e "${GREEN}8.${NC}  Sonarr (电视剧管理)"
        echo -e "${GREEN}9.${NC}  Radarr (电影管理)"
        echo -e "${GREEN}10.${NC} Lidarr (音乐管理)"
        echo -e "${GREEN}11.${NC} Bazarr (字幕管理)"
        echo
        echo -e "${WHITE}🚀 批量安装:${NC}"
        echo -e "${PURPLE}88.${NC} 安装媒体服务器套件 (Emby+Prowlarr+Sonarr+Radarr)"
        echo -e "${PURPLE}89.${NC} 安装完整自动化套件 (全部应用)"
        echo
        echo -e "${BLUE}0.${NC}  返回主菜单"
        echo
        read -p "请输入选项 [0-11,88,89]: " choice
        
        case $choice in
            1) 
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "transmission"
                ;;
            2) 
                install_vertex
                ;;
            3) 
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "emby"
                ;;
            4) 
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "jellyfin"
                ;;
            5) 
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "plex"
                ;;
            6) 
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "jackett"
                ;;
            7) 
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "prowlarr"
                ;;
            8) 
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "sonarr"
                ;;
            9) 
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "radarr"
                ;;
            10) 
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "lidarr"
                ;;
            11) 
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "bazarr"
                ;;
            88)
                log_info "安装媒体服务器套件..."
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "emby"
                install_docker_app "prowlarr"
                install_docker_app "sonarr"
                install_docker_app "radarr"
                ;;
            89)
                log_info "安装完整自动化套件..."
                install_dependencies && install_docker && install_docker_compose && create_directories && download_configs
                install_docker_app "transmission"
                install_vertex
                install_docker_app "emby"
                install_docker_app "prowlarr"
                install_docker_app "sonarr"
                install_docker_app "radarr"
                install_docker_app "lidarr"
                install_docker_app "bazarr"
                ;;
            0) return ;;
            *) log_error "无效选项，请重新选择" ;;
        esac
        
        if [ "$choice" != "0" ]; then
            read -p "按回车键继续..." 
        fi
    done
}

# 卸载应用菜单
uninstall_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║            PTtools - 卸载应用         ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}🗑️  卸载选项:${NC}"
        echo
        echo -e "${YELLOW}1.${NC}  卸载qBittorrent (编译版本)"
        echo -e "${YELLOW}2.${NC}  卸载Transmission"
        echo -e "${YELLOW}3.${NC}  卸载Vertex (刷流工具)"
        echo -e "${YELLOW}4.${NC}  卸载Emby"
        echo -e "${YELLOW}5.${NC}  卸载Jellyfin"
        echo -e "${YELLOW}6.${NC}  卸载Plex"
        echo -e "${YELLOW}7.${NC}  卸载Jackett"
        echo -e "${YELLOW}8.${NC}  卸载Prowlarr"
        echo -e "${YELLOW}9.${NC}  卸载Sonarr"
        echo -e "${YELLOW}10.${NC} 卸载Radarr"
        echo -e "${YELLOW}11.${NC} 卸载Lidarr"
        echo -e "${YELLOW}12.${NC} 卸载Bazarr"
        echo
        echo -e "${RED}88.${NC} 完全卸载 (所有应用和Docker)"
        echo -e "${RED}89.${NC} 重置优化设置"
        echo
        echo -e "${BLUE}0.${NC}  返回主菜单"
        echo
        read -p "请输入选项 [0-12,88,89]: " choice
        
        case $choice in
            1) uninstall_qbittorrent ;;
            2) uninstall_docker_app "transmission" ;;
            3) uninstall_docker_app "vertex" ;;
            4) uninstall_docker_app "emby" ;;
            5) uninstall_docker_app "jellyfin" ;;
            6) uninstall_docker_app "plex" ;;
            7) uninstall_docker_app "jackett" ;;
            8) uninstall_docker_app "prowlarr" ;;
            9) uninstall_docker_app "sonarr" ;;
            10) uninstall_docker_app "radarr" ;;
            11) uninstall_docker_app "lidarr" ;;
            12) uninstall_docker_app "bazarr" ;;
            88) complete_uninstall ;;
            89) reset_optimizations ;;
            0) return ;;
            *) log_error "无效选项，请重新选择" ;;
        esac
        
        if [ "$choice" != "0" ]; then
            read -p "按回车键继续..." 
        fi
    done
}

# 卸载qBittorrent
uninstall_qbittorrent() {
    log_info "卸载qBittorrent..."
    
    # 停止服务
    systemctl stop qbittorrent 2>/dev/null
    systemctl disable qbittorrent 2>/dev/null
    
    # 删除用户和服务文件
    userdel -r qbittorrent 2>/dev/null
    rm -f /etc/systemd/system/qbittorrent.service
    systemctl daemon-reload
    
    # 删除二进制文件
    rm -f /usr/local/bin/qbittorrent-nox
    
    # 询问是否删除数据
    read -p "是否删除qBittorrent的数据？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf /home/qbittorrent
        log_info "qBittorrent数据已删除"
    fi
    
    log_info "qBittorrent卸载完成"
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
    docker-compose -f "$compose_file" down 2>/dev/null
    docker-compose -f "$compose_file" rm -f 2>/dev/null
    
    # 询问是否删除数据
    read -p "是否删除 $app_name 的配置数据？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DOCKER_DIR/$app_name"
        log_info "$app_name 数据已删除"
    fi
    
    log_info "$app_name 卸载完成"
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
    
    # 卸载qBittorrent
    uninstall_qbittorrent
    
    # 卸载Docker
    if command -v docker &> /dev/null; then
        log_info "卸载Docker..."
        
        if command -v apt-get &> /dev/null; then
            apt-get remove -y docker docker-engine docker.io containerd runc
            apt-get autoremove -y
        elif command -v yum &> /dev/null; then
            yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
        fi
        
        rm -rf /var/lib/docker
        rm -rf /var/lib/containerd
    fi
    
    # 询问是否删除所有数据
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

# 重置优化设置
reset_optimizations() {
    log_info "重置系统优化设置..."
    
    # 删除优化配置文件
    rm -f /etc/sysctl.d/99-pttools-optimization.conf
    rm -f /etc/systemd/system.conf.d/pttools.conf
    
    # 恢复默认的sysctl设置
    sysctl --system
    
    log_info "优化设置已重置，建议重启系统"
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║              PTtools v2.0             ║${NC}"
        echo -e "${CYAN}║        PT工具一键安装脚本 VPS优化版    ║${NC}"
        echo -e "${CYAN}║     Github: everett7623/PTtools      ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}🏆 核心安装选项:${NC}"
        echo
        echo -e "${GREEN}1.${NC}  qBittorrent 4.3.8"
        echo -e "${GREEN}2.${NC}  qBittorrent 4.3.9 ${YELLOW}(推荐)${NC}"
        echo -e "${GREEN}3.${NC}  qBittorrent 4.3.8 + Vertex ${PURPLE}(刷流组合)${NC}"
        echo -e "${GREEN}4.${NC}  qBittorrent 4.3.9 + Vertex ${RED}(最强组合)${NC}"
        echo
        echo -e "${WHITE}📦 其他功能:${NC}"
        echo -e "${GREEN}5.${NC}  选择安装应用 ${CYAN}(功能分类与工具列表)${NC}"
        echo -e "${GREEN}6.${NC}  系统优化 ${YELLOW}(VPS性能调优)${NC}"
        echo -e "${GREEN}7.${NC}  卸载应用"
        echo
        echo -e "${RED}0.${NC}  退出脚本"
        echo
        echo -e "${CYAN}💡 说明: 选项1-4为PT专用优化版本${NC}"
        echo
        read -p "请输入选项 [0-7]: " choice
        
        case $choice in
            1) 
                log_info "开始安装qBittorrent 4.3.8..."
                install_dependencies
                install_qb438
                ;;
            2) 
                log_info "开始安装qBittorrent 4.3.9 (推荐)..."
                install_dependencies
                install_qb439
                ;;
            3) 
                log_info "开始安装qBittorrent 4.3.8 + Vertex刷流组合..."
                install_dependencies
                install_qb438_with_vertex
                ;;
            4) 
                log_info "开始安装qBittorrent 4.3.9 + Vertex最强组合..."
                install_dependencies
                install_qb439_with_vertex
                ;;
            5) application_category_menu ;;
            6) system_optimization_menu ;;
            7) uninstall_menu ;;
            0) 
                log_info "感谢使用PTtools！"
                exit 0
                ;;
            *) log_error "无效选项，请重新选择" ;;
        esac
        
        if [ "$choice" != "0" ] && [ "$choice" != "5" ] && [ "$choice" != "6" ] && [ "$choice" != "7" ]; then
            show_completion_info
            read -p "按回车键返回主菜单..." 
        fi
    done
}

# 显示安装完成信息
show_completion_info() {
    clear
    SERVER_IP=$(curl -s ip.sb 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "your-server-ip")
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    🎉 安装完成！                            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}🌐 访问信息:${NC}"
    
    # 检查qBittorrent是否安装
    if systemctl is-active --quiet qbittorrent 2>/dev/null; then
        echo -e "   qBittorrent WebUI: ${WHITE}http://$SERVER_IP:8080${NC}"
        echo -e "   默认用户名: ${WHITE}admin${NC}"
        echo -e "   默认密码: ${WHITE}adminadmin${NC}"
    fi
    
    # 检查Docker应用
    echo
    echo -e "${CYAN}🐳 Docker应用访问:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -v NAMES | while read line; do
        if [ ! -z "$line" ]; then
            echo -e "   $line"
        fi
    done
    
    echo
    echo -e "${CYAN}📁 重要目录:${NC}"
    echo -e "   下载目录: ${WHITE}$DOWNLOAD_DIR${NC}"
    echo -e "   Docker应用: ${WHITE}$DOCKER_DIR${NC}"
    echo
    echo -e "${YELLOW}⚡ VPS已针对PT刷流进行优化！${NC}"
    echo -e "${YELLOW}💡 建议重启系统以确保所有优化生效${NC}"
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
    echo -e "${CYAN}║       专为PT用户设计的VPS优化脚本     ║${NC}"
    echo -e "${CYAN}║                                       ║${NC}"
    echo -e "${CYAN}║    🚀 针对刷流优化  🎯 小白友好       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
    echo
    echo -e "${WHITE}✨ 特色功能:${NC}"
    echo -e "  🔥 VPS网络性能优化 (BBR、TCP调优)"
    echo -e "  ⚡ 文件系统优化 (大量连接支持)"
    echo -e "  🎛️ qBittorrent专业配置"
    echo -e "  🔧 Vertex高级优化脚本"
    echo -e "  📦 Docker容器化部署"
    echo
    echo -e "${WHITE}🏆 推荐配置:${NC}"
    echo -e "  新手: ${GREEN}选项2${NC} (qB 4.3.9)"
    echo -e "  刷流: ${PURPLE}选项4${NC} (qB 4.3.9 + Vertex)"
    echo
    read -p "按回车键进入主菜单..."
    
    # 进入主菜单
    main_menu
}

# 启动脚本
main "$@"
