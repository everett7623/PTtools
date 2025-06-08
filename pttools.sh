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
DOWNLOAD_DIR="/opt/downloads" # 统一默认下载目录
GITHUB_REPO="https://raw.githubusercontent.com/everett7623/PTtools/main"
COMPOSE_DIR="$DOCKER_DIR/compose"

# qBittorrent 默认配置
QB_DEFAULT_USER="qbittorrent"
QB_DEFAULT_PASSWORD="adminadmin" # qb438.sh 内部会使用PBKDF2 hash
QB_DEFAULT_WEBUI_PORT="8080"
QB_DEFAULT_BT_PORT="23333" # 默认BT端口

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    # exit 1 # 遇到错误不立即退出，给用户机会查看日志或重试
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
    sysctl -p /etc/sysctl.d/99-pttools-optimization.conf || log_warn "应用sysctl优化配置失败，请检查文件内容。"
    
    # 优化文件描述符限制
    # 检查limits.conf中是否已存在PTtools的配置，避免重复添加
    if ! grep -q "# PTtools 文件描述符优化" /etc/security/limits.conf; then
        cat >> /etc/security/limits.conf << EOF

# PTtools 文件描述符优化
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 1000000
* hard nproc 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF
    fi

    # 优化systemd默认限制
    mkdir -p /etc/systemd/system.conf.d || log_warn "创建systemd配置目录失败。"
    cat > /etc/systemd/system.conf.d/pttools.conf << EOF
[Manager]
DefaultLimitNOFILE=1000000
DefaultLimitNPROC=1000000
EOF

    # 启用BBR拥塞控制
    modprobe tcp_bbr || log_warn "加载tcp_bbr模块失败。"
    if ! grep -q "tcp_bbr" /etc/modules-load.d/modules.conf; then
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    fi
    
    log_info "VPS优化配置已应用，部分设置需重启后生效。"
}

# 安装基础依赖
install_dependencies() {
    log_info "安装基础依赖..."
    
    # 更新软件包列表
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y curl wget git unzip zip nano vim htop iotop vnstat || log_error "Debian/Ubuntu基础依赖安装失败。"
    elif command -v yum &> /dev/null; then
        yum update -y && yum install -y curl wget git unzip zip nano vim htop iotop vnstat || log_error "CentOS/RHEL基础依赖安装失败。"
    elif command -v dnf &> /dev/null; then
        dnf update -y && dnf install -y curl wget git unzip zip nano vim htop iotop vnstat || log_error "Fedora基础依赖安装失败。"
    else
        log_error "不支持的包管理器"
        exit 1
    fi
    log_info "基础依赖安装完成。"
}

# 安装Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker已安装，跳过安装步骤"
        return 0
    fi
    
    log_info "安装Docker..."
    
    # 官方安装脚本
    curl -fsSL https://get.docker.com | bash || log_error "Docker官方安装脚本执行失败。"
    
    # 启动Docker服务
    systemctl start docker || log_error "启动Docker服务失败。"
    systemctl enable docker || log_error "启用Docker服务失败。"
    
    # 优化Docker配置
    mkdir -p /etc/docker || log_error "创建/etc/docker目录失败。"
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

    systemctl restart docker || log_error "重启Docker服务失败。"
    
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
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || log_error "下载Docker Compose失败。"
    chmod +x /usr/local/bin/docker-compose || log_error "设置Docker Compose权限失败。"
    
    # 创建软链接
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose || log_warn "创建docker-compose软链接失败。"
    
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
    
    mkdir -p "$SCRIPT_DIR" || log_error "创建脚本目录失败。"
    mkdir -p "$DOCKER_DIR" || log_error "创建Docker根目录失败。"
    mkdir -p "$DOWNLOAD_DIR" || log_error "创建下载根目录失败。"
    mkdir -p "$COMPOSE_DIR" || log_error "创建Docker Compose目录失败。"
    
    # 创建优化的下载目录结构
    mkdir -p "$DOWNLOAD_DIR"/{complete,incomplete,watch,torrents} || log_error "创建下载子目录失败。"
    mkdir -p "$DOWNLOAD_DIR"/complete/{movies,tv,music,software,books} || log_error "创建完成下载分类目录失败。"
    
    # 创建各应用目录
    mkdir -p "$DOCKER_DIR"/{qbittorrent,transmission,vertex,emby,jellyfin,plex,jackett,prowlarr,sonarr,radarr,lidarr,bazarr}/config || log_error "创建Docker应用配置目录失败。"
    
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
            wget -O "$COMPOSE_DIR/$config" "$GITHUB_REPO/configs/docker-compose/$config" 2>/dev/null || log_warn "下载 $config 失败，请检查网络或GitHub连接。"
        else
            log_info "$config 已存在，跳过下载。"
        fi
    done
    log_info "配置文件下载完成。"
}

# qBittorrent 4.3.8安装
install_qb438() {
    log_info "安装qBittorrent 4.3.8 (PT优化版)..."
    
    # 先应用VPS优化
    optimize_vps_for_pt
    
    # 下载安装脚本
    wget -O /tmp/qb438.sh "$GITHUB_REPO/scripts/install/qb438.sh" || log_error "下载 qb438.sh 脚本失败。"
    chmod +x /tmp/qb438.sh || log_error "设置 qb438.sh 脚本权限失败。"
    
    # 执行安装，传递参数
    # QB_USER QB_PASSWORD WEBUI_PORT BT_PORT DOWNLOAD_PATH
    bash /tmp/qb438.sh "$QB_DEFAULT_USER" "$QB_DEFAULT_PASSWORD" "$QB_DEFAULT_WEBUI_PORT" "$QB_DEFAULT_BT_PORT" "$DOWNLOAD_DIR" || log_error "qbittorrent 4.3.8 编译安装失败。"
    
    # 清理临时文件
    rm -f /tmp/qb438.sh
    
    log_info "qBittorrent 4.3.8 安装完成"
}

# qBittorrent 4.3.9安装 (假设存在类似的编译脚本)
# 注意：如果pttools仓库中没有qb439.sh的编译安装脚本，这里会失败
install_qb439() {
    log_info "安装qBittorrent 4.3.9 (PT优化版)..."
    
    # 先应用VPS优化
    optimize_vps_for_pt
    
    # 下载安装脚本
    wget -O /tmp/qb439.sh "$GITHUB_REPO/scripts/install/qb439.sh" || log_error "下载 qb439.sh 脚本失败。请确认该版本编译脚本是否存在。"
    chmod +x /tmp/qb439.sh || log_error "设置 qb439.sh 脚本权限失败。"
    
    # 执行安装，传递参数
    bash /tmp/qb439.sh "$QB_DEFAULT_USER" "$QB_DEFAULT_PASSWORD" "$QB_DEFAULT_WEBUI_PORT" "$QB_DEFAULT_BT_PORT" "$DOWNLOAD_DIR" || log_error "qbittorrent 4.3.9 编译安装失败。"
    
    # 清理临时文件
    rm -f /tmp/qb439.sh
    
    log_info "qBittorrent 4.3.9 安装完成"
}

# PTBoost优化脚本安装
install_ptboost() {
    log_info "安装PTBoost性能优化脚本..."
    
    # 下载PTBoost脚本
    wget -O /tmp/ptboost.sh "$GITHUB_REPO/scripts/install/applications/ptboost.sh" || log_error "下载 ptboost.sh 脚本失败。"
    chmod +x /tmp/ptboost.sh || log_error "设置 ptboost.sh 脚本权限失败。"
    
    # 执行PTBoost优化
    bash /tmp/ptboost.sh || log_error "PTBoost优化脚本执行失败。"
    
    # 清理临时文件
    rm -f /tmp/ptboost.sh
    
    log_info "PTBoost优化脚本安装完成"
}

# Vertex刷流工具安装
install_vertex() {
    log_info "安装Vertex刷流工具..."
    
    # 先安装基础环境
    install_dependencies
    install_docker
    install_docker_compose
    create_directories
    download_configs # 确保下载了vertex.yml
    
    # 下载并运行Vertex安装脚本 (如果pttools中有独立的vertex安装脚本)
    # 如果vertex只是docker-compose，则直接调用 install_docker_app "vertex"
    # 假设pttools/scripts/install/applications/vertex.sh 存在，并且是docker安装方式
    wget -O /tmp/vertex.sh "$GITHUB_REPO/scripts/install/applications/vertex.sh" || log_error "下载 vertex.sh 脚本失败。"
    chmod +x /tmp/vertex.sh || log_error "设置 vertex.sh 脚本权限失败。"
    bash /tmp/vertex.sh || log_error "Vertex安装脚本执行失败。"
    
    # 清理临时文件
    rm -f /tmp/vertex.sh
    
    log_info "Vertex刷流工具安装完成"
}

# qBittorrent 4.3.8 + Vertex
install_qb438_with_vertex() {
    log_info "安装qBittorrent 4.3.8 + Vertex刷流工具..."
    # 安装Docker环境（如果还没有）
    install_docker
    install_docker_compose
    create_directories
    download_configs
    # 安装Vertex刷流工具
    install_vertex # Vertex本身可能需要调用其自身的安装逻辑
    sleep 2 # 给点时间让Vertex容器启动
    install_qb438
    log_info "qBittorrent 4.3.8 + Vertex 安装完成"
}

# qBittorrent 4.3.9 + Vertex  
install_qb439_with_vertex() {
    log_info "安装qBittorrent 4.3.9 + Vertex刷流工具..."
    # 安装Docker环境（如果还没有）
    install_docker
    install_docker_compose
    create_directories
    download_configs
    # 安装Vertex刷流工具
    install_vertex # Vertex本身可能需要调用其自身的安装逻辑
    sleep 2 # 给点时间让Vertex容器启动
    install_qb439
    log_info "qBittorrent 4.3.9 + Vertex 安装完成"
}

# Docker应用安装函数
install_docker_app() {
    local app_name=$1
    local compose_file="$COMPOSE_DIR/${app_name}.yml"
    
    if [ ! -f "$compose_file" ]; then
        log_error "配置文件 $compose_file 不存在，无法安装 $app_name。"
        return 1
    fi
    
    log_info "安装 $app_name..."
    
    # 确保进入正确的目录执行 docker-compose
    (cd "$COMPOSE_DIR" && docker-compose -f "$compose_file" up -d)
    
    if [ $? -eq 0 ]; then
        log_info "$app_name 安装成功"
    else
        log_error "$app_name 安装失败，请检查compose文件或Docker状态。"
        return 1
    fi
}

# 功能分类与工具列表菜单
application_category_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║           PTtools - 应用分类安装      ║${NC}"
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
    userdel -r "$QB_DEFAULT_USER" 2>/dev/null # 使用默认用户名进行卸载
    rm -f /etc/systemd/system/qbittorrent.service
    systemctl daemon-reload
    
    # 删除二进制文件
    rm -f /usr/local/bin/qbittorrent-nox
    
    # 询问是否删除数据
    read -p "是否删除qBittorrent的数据 (包括下载目录 $DOWNLOAD_DIR 和配置目录 /home/$QB_DEFAULT_USER/.config/qBittorrent)？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "/home/$QB_DEFAULT_USER"
        rm -rf "$DOWNLOAD_DIR" # 考虑到下载目录可能被其他应用共用，这里提醒用户
        log_info "qBittorrent数据已删除"
    else
        log_warn "qBittorrent数据保留在 $DOWNLOAD_DIR 和 /home/$QB_DEFAULT_USER。"
    fi
    
    log_info "qBittorrent卸载完成"
}

# 卸载Docker应用
uninstall_docker_app() {
    local app_name=$1
    local compose_file="$COMPOSE_DIR/${app_name}.yml"
    
    if [ ! -f "$compose_file" ]; then
        log_warn "配置文件 $compose_file 不存在，跳过卸载 $app_name。"
        return 0
    fi
    
    log_info "卸载 $app_name..."
    
    (cd "$COMPOSE_DIR" && docker-compose -f "$compose_file" down --volumes --remove-orphans 2>/dev/null) # 增加 --volumes 来移除匿名卷
    
    # 询问是否删除数据
    read -p "是否删除 $app_name 的配置数据 (位于 $DOCKER_DIR/$app_name/config)？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DOCKER_DIR/$app_name"
        log_info "$app_name 数据已删除"
    else
        log_warn "$app_name 数据保留在 $DOCKER_DIR/$app_name。"
    fi
    
    log_info "$app_name 卸载完成"
}

# 完全卸载
complete_uninstall() {
    log_warn "警告：这将卸载所有PTtools安装的应用、Docker和相关数据！"
    read -p "确定要继续吗？(y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "取消完全卸载。"
        return
    fi
    
    log_info "开始完全卸载..."
    
    # 停止并删除所有容器
    log_info "停止并删除所有Docker容器..."
    docker stop $(docker ps -aq) 2>/dev/null
    docker rm $(docker ps -aq) 2>/dev/null
    
    # 卸载qBittorrent
    uninstall_qbittorrent
    
    # 卸载Docker Compose
    log_info "卸载Docker Compose..."
    rm -f /usr/local/bin/docker-compose
    rm -f /usr/bin/docker-compose # 移除软链接
    
    # 卸载Docker
    if command -v docker &> /dev/null; then
        log_info "卸载Docker Engine..."
        if command -v apt-get &> /dev/null; then
            apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || log_warn "apt-get 卸载Docker失败。"
            apt-get autoremove -y
        elif command -v yum &> /dev/null; then
            yum remove -y docker-ce docker-ce-cli containerd.io || log_warn "yum 卸载Docker失败。"
            yum autoremove -y
        elif command -v dnf &> /dev/null; then
            dnf remove -y docker-ce docker-ce-cli containerd.io || log_warn "dnf 卸载Docker失败。"
            dnf autoremove -y
        fi
        
        # 清理Docker残留文件
        rm -rf /var/lib/docker
        rm -rf /var/lib/containerd
        rm -rf /etc/docker/daemon.json
        log_info "Docker Engine已卸载。"
    fi
    
    # 询问是否删除所有PTtools数据
    read -p "是否删除所有PTtools根目录 (脚本、Docker配置、下载数据 $DOWNLOAD_DIR)？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "删除PTtools相关目录..."
        rm -rf "$SCRIPT_DIR"
        rm -rf "$DOCKER_DIR"
        rm -rf "$DOWNLOAD_DIR"
        log_info "所有PTtools数据已删除。"
    else
        log_warn "PTtools相关目录保留在 $SCRIPT_DIR, $DOCKER_DIR, $DOWNLOAD_DIR。"
    fi
    
    # 重置系统优化
    reset_optimizations
    
    log_info "完全卸载完成！请手动重启系统以彻底清理。"
}

# 重置优化设置
reset_optimizations() {
    log_info "重置系统优化设置..."
    
    # 删除优化配置文件
    rm -f /etc/sysctl.d/99-pttools-optimization.conf
    rm -f /etc/systemd/system.conf.d/pttools.conf
    
    # 恢复默认的sysctl设置
    sysctl --system || log_warn "sysctl --system 执行失败，可能需要手动恢复默认设置。"
    
    # 清理limits.conf中添加的PTtools行
    sed -i '/# PTtools 文件描述符优化/,+4d' /etc/security/limits.conf 2>/dev/null || true # 删除标记行及后续4行
    
    # 移除modules.conf中的bbr行
    sed -i '/^tcp_bbr$/d' /etc/modules-load.d/modules.conf 2>/dev/null || true
    
    log_info "优化设置已重置，建议重启系统以彻底生效。"
}

# 系统优化菜单
system_optimization_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║            PTtools - 系统优化         ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}🔧 优化选项:${NC}"
        echo
        echo -e "${GREEN}1.${NC}  应用VPS PT刷流优化 (推荐)"
        echo -e "${YELLOW}2.${NC}  重置优化设置"
        echo
        echo -e "${BLUE}0.${NC}  返回主菜单"
        echo
        read -p "请输入选项 [0-2]: " choice
        
        case $choice in
            1) optimize_vps_for_pt ;;
            2) reset_optimizations ;;
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
        echo -e "${CYAN}║             PTtools v2.0              ║${NC}"
        echo -e "${CYAN}║         PT工具一键安装脚本 VPS优化版    ║${NC}"
        echo -e "${CYAN}║       Github: everett7623/PTtools     ║${NC}"
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
                # 依赖检查和优化已包含在 qb438.sh 内部
                install_qb438
                ;;
            2) 
                log_info "开始安装qBittorrent 4.3.9 (推荐)..."
                # 依赖检查和优化已包含在 qb439.sh 内部 (假设它与qb438.sh类似)
                install_qb439
                ;;
            3) 
                log_info "开始安装qBittorrent 4.3.8 + Vertex刷流组合..."
                install_qb438_with_vertex
                ;;
            4) 
                log_info "开始安装qBittorrent 4.3.9 + Vertex最强组合..."
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
    echo -e "${GREEN}║                    🎉 安装完成！                               ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}🌐 访问信息:${NC}"
    
    # 检查qBittorrent是否安装
    if systemctl is-active --quiet qbittorrent 2>/dev/null; then
        echo -e "    qBittorrent WebUI: ${WHITE}http://$SERVER_IP:$QB_DEFAULT_WEBUI_PORT${NC}"
        echo -e "    默认用户名: ${WHITE}$QB_DEFAULT_USER${NC}"
        echo -e "    默认密码: ${WHITE}$QB_DEFAULT_PASSWORD${NC} (请首次登录后修改!)"
    fi
    
    # 检查Docker应用
    echo
    echo -e "${CYAN}🐳 Docker应用访问:${NC}"
    if command -v docker &> /dev/null; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -v NAMES | while read line; do
            if [ ! -z "$line" ]; then
                echo -e "    $line"
            fi
        done
    else
        echo "    Docker未运行或未安装。"
    fi
    
    echo
    echo -e "${CYAN}📁 重要目录:${NC}"
    echo -e "    下载目录: ${WHITE}$DOWNLOAD_DIR${NC}"
    echo -e "    Docker应用数据: ${WHITE}$DOCKER_DIR${NC}"
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
    echo -e "${CYAN}║             欢迎使用 PTtools          ║${NC}"
    echo -e "${CYAN}║                                       ║${NC}"
    echo -e "${CYAN}║         专为PT用户设计的VPS优化脚本     ║${NC}"
    echo -e "${CYAN}║                                       ║${NC}"
    echo -e "${CYAN}║   🚀 针对刷流优化  🎯 小白友好        ║${NC}"
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
