#!/bin/bash

# qBittorrent 4.3.8 安装脚本 - PTtools集成版本
# 优化用于seedbox和PT刷流
# 版本: 2025-06-09 v2.0.0
# 项目地址: https://github.com/everett7623/PTtools

VERSION="2025-06-09 v2.0.0"
SCRIPT_URL="https://raw.githubusercontent.com/everett7623/PTtools/main/scripts/install/qb438.sh"

# 颜色定义 - 与PTtools主程序保持一致
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 全局变量
QB_VERSION="4.3.8"
LT_VERSION="1.2.14"
SERVICE_USER="qbittorrent"
QB_CONFIG_DIR="/home/${SERVICE_USER}/.config/qBittorrent"
QB_DOWNLOAD_DIR="/opt/downloads"
DEFAULT_PORT="8080"
DEFAULT_UP_PORT="23333"
DEFAULT_PASSWORD="adminadmin"
DEFAULT_USERNAME="admin"

# 日志函数 - 与PTtools风格一致
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

# 错误处理
set -e
trap cleanup ERR

cleanup() {
    log_warn "安装过程中发生错误，正在清理..."
    exit 1
}

# 权限检查
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 系统检测
detect_system() {
    log_info "检测系统环境..."
    
    # 检测架构
    systemARCH=$(uname -m)
    case $systemARCH in
        x86_64)
            ARCH="x86_64"
            log_info "系统架构: x86_64"
            ;;
        aarch64)
            ARCH="aarch64"
            log_info "系统架构: ARM64"
            ;;
        *)
            log_error "不支持的系统架构: $systemARCH"
            exit 1
            ;;
    esac
    
    # 检测发行版
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        log_info "操作系统: $OS $VER"
    else
        log_error "无法检测系统版本"
        exit 1
    fi
    
    # 检测包管理器
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        INSTALL_CMD="apt-get install -y"
        UPDATE_CMD="apt-get update"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        INSTALL_CMD="dnf install -y"
        UPDATE_CMD="dnf makecache"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        INSTALL_CMD="yum install -y"
        UPDATE_CMD="yum makecache"
    else
        log_error "不支持的包管理器"
        exit 1
    fi
    
    # 获取内存大小
    RAM=$(free -m | awk '/^Mem:/{print $2}')
    CACHE_SIZE=$((RAM / 8))
    log_info "系统内存: ${RAM}MB, 缓存大小设置为: ${CACHE_SIZE}MB"
}

# 安装依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    $UPDATE_CMD
    
    case $PKG_MANAGER in
        apt)
            $INSTALL_CMD curl wget htop vnstat net-tools software-properties-common \
                build-essential libssl-dev libboost-system-dev libboost-chrono-dev \
                libboost-random-dev pkg-config zlib1g-dev
            ;;
        dnf|yum)
            $INSTALL_CMD curl wget htop vnstat net-tools epel-release \
                gcc gcc-c++ make openssl-devel boost-devel zlib-devel
            # CentOS/RHEL 需要启用 EPEL
            if [ "$PKG_MANAGER" = "yum" ]; then
                yum install -y epel-release
            fi
            ;;
    esac
    
    log_info "依赖安装完成"
}

# 创建用户
create_user() {
    if [ -z "$1" ]; then
        SERVICE_USER="qbittorrent"
    else
        SERVICE_USER="$1"
    fi
    
    log_info "创建服务用户: $SERVICE_USER"
    
    if ! id "$SERVICE_USER" >/dev/null 2>&1; then
        useradd -r -m -s /bin/bash "$SERVICE_USER"
        log_info "用户 $SERVICE_USER 创建成功"
    else
        log_info "用户 $SERVICE_USER 已存在"
    fi
    
    # 更新目录变量
    QB_CONFIG_DIR="/home/${SERVICE_USER}/.config/qBittorrent"
    
    # 创建必要目录
    mkdir -p "$QB_CONFIG_DIR"
    mkdir -p "$QB_DOWNLOAD_DIR"/{torrents,temp}
    
    # 设置配置目录权限
    chown -R "$SERVICE_USER:$SERVICE_USER" "/home/$SERVICE_USER"
    
    # 设置下载目录权限
    chown -R "$SERVICE_USER:$SERVICE_USER" "$QB_DOWNLOAD_DIR"
}

# 下载并安装预编译的qBittorrent
install_qbittorrent_binary() {
    log_info "下载 qBittorrent $QB_VERSION 预编译版本..."
    
    # 停止旧服务（如果存在）
    systemctl stop qbittorrent-nox@$SERVICE_USER 2>/dev/null || true
    
    # 根据架构下载对应的二进制文件
    if [[ $ARCH == "x86_64" ]]; then
        # 首选：从 GitHub 下载
        if ! wget -O /usr/bin/qbittorrent-nox "https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.8_v1.2.14/x86_64-qbittorrent-nox" 2>/dev/null; then
            # 备选：使用原脚本的源
            log_warn "从主源下载失败，尝试备用源..."
            wget -O /usr/bin/qbittorrent-nox "https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox"
        fi
    elif [[ $ARCH == "aarch64" ]]; then
        # ARM64版本
        if ! wget -O /usr/bin/qbittorrent-nox "https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.8_v1.2.14/aarch64-qbittorrent-nox" 2>/dev/null; then
            log_warn "从主源下载失败，尝试备用源..."
            wget -O /usr/bin/qbittorrent-nox "https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox"
        fi
    fi
    
    # 设置执行权限
    chmod +x /usr/bin/qbittorrent-nox
    
    log_info "qBittorrent 二进制文件安装完成"
}

# 创建systemd服务
create_service() {
    log_info "创建 systemd 服务..."
    
    cat > /etc/systemd/system/qbittorrent-nox@.service << 'EOF'
[Unit]
Description=qBittorrent-nox service for %i
Documentation=man:qbittorrent-nox(1)
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=simple
User=%i
Group=%i
UMask=002
ExecStart=/usr/bin/qbittorrent-nox
Restart=on-failure
SyslogIdentifier=qbittorrent-nox

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable qbittorrent-nox@$SERVICE_USER
    
    log_info "systemd 服务创建完成"
}

# 生成初始配置
generate_config() {
    local port=${1:-$DEFAULT_PORT}
    local up_port=${2:-$DEFAULT_UP_PORT}
    local password=${3:-$DEFAULT_PASSWORD}
    
    log_info "生成 qBittorrent 配置..."
    
    # 生成密码哈希 (adminadmin的PBKDF2哈希)
    if [ "$password" = "adminadmin" ]; then
        PASSWORD_HASH="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsO8WkSoUFm0Q==)"
    else
        # 对于自定义密码，暂时使用明文（首次登录后会自动加密）
        PASSWORD_HASH="$password"
    fi
    
    # 创建配置文件
    cat > "$QB_CONFIG_DIR/qBittorrent.conf" << EOF
[Application]
FileLogger\\Enabled=true
FileLogger\\Path=/home/$SERVICE_USER/.config/qBittorrent/logs
FileLogger\\Backup=true
FileLogger\\DeleteOld=true
FileLogger\\MaxSizeBytes=10485760
FileLogger\\Age=1

[BitTorrent]
Session\\AsyncIOThreadsCount=8
Session\\CheckingMemUsageSize=$CACHE_SIZE
Session\\CoalesceReadWrite=true
Session\\DiskCacheSize=$CACHE_SIZE
Session\\DiskWriteCacheSize=$CACHE_SIZE
Session\\MultiConnectionsPerIp=true
Session\\Port=$up_port
Session\\Preallocation=false
Session\\QueueingSystemEnabled=false
Session\\MaxActiveDownloads=50
Session\\MaxActiveTorrents=100
Session\\MaxActiveUploads=50
Session\\GlobalMaxSeedingMinutes=-1
Session\\DHT=false
Session\\DHTPort=6881
Session\\PeX=false
Session\\LSD=false
Session\\Encryption=1
Session\\MaxConnectionsPerTorrent=100
Session\\MaxUploadsPerTorrent=50
Session\\uTPEnabled=true
Session\\uTPRateLimited=false

[Core]
AutoDeleteAddedTorrentFile=Never

[Preferences]
Advanced\\RecheckOnCompletion=false
Advanced\\osCache=false
Advanced\\trackerPort=9000
Connection\\GlobalDLLimitAlt=0
Connection\\GlobalUPLimitAlt=0
Connection\\PortRangeMin=$up_port
Connection\\ResolvePeerCountries=false
Downloads\\DiskWriteCacheSize=$CACHE_SIZE
Downloads\\PreAllocation=false
Downloads\\SavePath=$QB_DOWNLOAD_DIR/
Downloads\\TempPath=$QB_DOWNLOAD_DIR/temp/
Downloads\\TempPathEnabled=true
DynDNS\\Enabled=false
General\\Locale=zh
Queueing\\QueueingEnabled=false
WebUI\\Address=*
WebUI\\AlternativeUIEnabled=false
WebUI\\AuthSubnetWhitelist=@Invalid()
WebUI\\AuthSubnetWhitelistEnabled=false
WebUI\\CSRFProtection=false
WebUI\\ClickjackingProtection=true
WebUI\\HostHeaderValidation=true
WebUI\\HTTPS\\Enabled=false
WebUI\\LocalHostAuth=false
WebUI\\Password_PBKDF2="$PASSWORD_HASH"
WebUI\\Port=$port
WebUI\\SecureCookie=true
WebUI\\ServerDomains=*
WebUI\\SessionTimeout=3600
WebUI\\UseUPnP=false
WebUI\\Username=admin
EOF
    
    # 创建日志目录
    mkdir -p "$QB_CONFIG_DIR/logs"
    mkdir -p "$QB_DOWNLOAD_DIR/temp"
    
    # 设置权限
    chown -R "$SERVICE_USER:$SERVICE_USER" "$QB_CONFIG_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$QB_DOWNLOAD_DIR"
    
    log_info "配置文件生成完成"
}

# VPS优化设置（继承自PTtools主程序）
optimize_vps() {
    log_info "应用VPS PT刷流优化配置..."
    
    # 创建优化配置文件
    cat > /etc/sysctl.d/99-qbittorrent-optimization.conf << 'EOF'
# qBittorrent VPS优化配置 - PT刷流专用

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

# 文件系统优化
fs.file-max = 1000000
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 1024

# 虚拟内存优化
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
EOF
    
    # 应用系统优化
    sysctl -p /etc/sysctl.d/99-qbittorrent-optimization.conf
    
    # 优化文件描述符限制
    cat >> /etc/security/limits.conf << EOF

# qBittorrent 文件描述符优化
$SERVICE_USER soft nofile 1000000
$SERVICE_USER hard nofile 1000000
$SERVICE_USER soft nproc 1000000
$SERVICE_USER hard nproc 1000000
EOF
    
    # 启用BBR（如果尚未启用）
    if ! lsmod | grep -q tcp_bbr; then
        modprobe tcp_bbr
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    fi
    
    # 禁用系统中的tso（如果存在相关配置）
    if [ -f /root/.boot-script.sh ]; then
        sed -i "s/disable_tso_/# disable_tso_/" /root/.boot-script.sh 2>/dev/null || true
    fi
    
    log_info "VPS优化配置已应用"
}

# 调整磁盘预留空间
optimize_disk() {
    log_info "优化磁盘设置..."
    
    # 获取根分区设备
    ROOT_DEV=$(df -h / | awk 'NR==2 {print $1}')
    
    # 检查是否为ext文件系统
    if tune2fs -l "$ROOT_DEV" &>/dev/null; then
        # 将预留空间设置为1%
        tune2fs -m 1 "$ROOT_DEV"
        log_info "磁盘预留空间已优化"
    else
        log_warn "无法优化磁盘预留空间（非ext文件系统）"
    fi
}

# 防火墙配置
configure_firewall() {
    local port=${1:-$DEFAULT_PORT}
    local up_port=${2:-$DEFAULT_UP_PORT}
    
    log_info "配置防火墙规则..."
    
    # UFW (Ubuntu/Debian)
    if command -v ufw >/dev/null 2>&1; then
        ufw allow $port/tcp comment "qBittorrent WebUI"
        ufw allow $up_port/tcp comment "qBittorrent Listen Port"
        ufw allow $up_port/udp comment "qBittorrent Listen Port"
    fi
    
    # firewalld (CentOS/RHEL)
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=$port/tcp
        firewall-cmd --permanent --add-port=$up_port/tcp
        firewall-cmd --permanent --add-port=$up_port/udp
        firewall-cmd --reload
    fi
    
    # iptables (通用)
    if command -v iptables >/dev/null 2>&1 && [ ! -f /etc/firewalld.conf ]; then
        iptables -I INPUT -p tcp --dport $port -j ACCEPT
        iptables -I INPUT -p tcp --dport $up_port -j ACCEPT
        iptables -I INPUT -p udp --dport $up_port -j ACCEPT
        # 保存规则
        if command -v netfilter-persistent >/dev/null 2>&1; then
            netfilter-persistent save
        elif [ -f /etc/sysconfig/iptables ]; then
            service iptables save
        fi
    fi
    
    log_info "防火墙配置完成"
}

# 启动服务
start_service() {
    log_info "启动 qBittorrent 服务..."
    
    systemctl start qbittorrent-nox@$SERVICE_USER
    sleep 3
    
    if systemctl is-active --quiet qbittorrent-nox@$SERVICE_USER; then
        log_info "qBittorrent 服务启动成功"
        return 0
    else
        log_error "qBittorrent 服务启动失败"
        systemctl status qbittorrent-nox@$SERVICE_USER
        return 1
    fi
}

# 显示安装信息
show_info() {
    local port=${1:-$DEFAULT_PORT}
    local up_port=${2:-$DEFAULT_UP_PORT}
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ip.sb 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "your-server-ip")
    
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    🎉 安装完成！                            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}🌐 访问信息:${NC}"
    echo -e "   WebUI 地址: ${WHITE}http://$SERVER_IP:$port${NC}"
    echo -e "   用户名: ${WHITE}admin${NC}"
    echo -e "   默认密码: ${WHITE}adminadmin${NC}"
    echo
    echo -e "${CYAN}📁 重要目录:${NC}"
    echo -e "   下载目录: ${WHITE}$QB_DOWNLOAD_DIR${NC}"
    echo -e "   配置目录: ${WHITE}$QB_CONFIG_DIR${NC}"
    echo
    echo -e "${CYAN}🔧 服务管理:${NC}"
    echo -e "   启动: ${WHITE}systemctl start qbittorrent-nox@$SERVICE_USER${NC}"
    echo -e "   停止: ${WHITE}systemctl stop qbittorrent-nox@$SERVICE_USER${NC}"
    echo -e "   重启: ${WHITE}systemctl restart qbittorrent-nox@$SERVICE_USER${NC}"
    echo -e "   状态: ${WHITE}systemctl status qbittorrent-nox@$SERVICE_USER${NC}"
    echo -e "   日志: ${WHITE}journalctl -u qbittorrent-nox@$SERVICE_USER -f${NC}"
    echo
    echo -e "${YELLOW}⚡ VPS已针对PT刷流进行优化！${NC}"
    echo -e "${PURPLE}📌 qBittorrent版本: $QB_VERSION | libtorrent版本: $LT_VERSION${NC}"
    echo
}

# 交互式安装
interactive_install() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║   qBittorrent 4.3.8 安装向导 (PT优化版) ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════╝${NC}"
    echo
    
    # 询问用户名
    read -p "请输入服务用户名 [默认: qbittorrent]: " input_user
    SERVICE_USER=${input_user:-qbittorrent}
    
    # 询问WebUI端口
    read -p "请输入WebUI端口 [默认: 8080]: " input_port
    PORT=${input_port:-8080}
    
    # 询问BT监听端口
    read -p "请输入BT监听端口 [默认: 23333]: " input_up_port
    UP_PORT=${input_up_port:-23333}
    
    # 询问密码
    read -p "请输入WebUI密码 [默认: adminadmin]: " input_password
    PASSWORD=${input_password:-adminadmin}
    
    echo
    echo -e "${CYAN}安装配置摘要:${NC}"
    echo -e "  用户名: ${WHITE}$SERVICE_USER${NC}"
    echo -e "  WebUI端口: ${WHITE}$PORT${NC}"
    echo -e "  BT端口: ${WHITE}$UP_PORT${NC}"
    echo -e "  密码: ${WHITE}$PASSWORD${NC}"
    echo
    
    read -p "确认开始安装？(Y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]] && [ ! -z "$confirm" ]; then
        log_info "安装已取消"
        exit 0
    fi
    
    # 执行安装
    install_main "$SERVICE_USER" "$PASSWORD" "$PORT" "$UP_PORT"
}

# 命令行安装
cmdline_install() {
    local user=$1
    local password=$2
    local port=${3:-8080}
    local up_port=${4:-23333}
    
    if [ -z "$user" ] || [ -z "$password" ]; then
        echo "Usage: $0 <user> <password> [port] [up_port]"
        echo "  user: 服务用户名"
        echo "  password: WebUI密码"
        echo "  port: WebUI端口 (默认: 8080)"
        echo "  up_port: BT监听端口 (默认: 23333)"
        exit 1
    fi
    
    install_main "$user" "$password" "$port" "$up_port"
}

# 主安装流程
install_main() {
    local user=$1
    local password=$2
    local port=$3
    local up_port=$4
    
    log_info "开始安装 qBittorrent $QB_VERSION (PT优化版)"
    
    # 基础检查和准备
    check_root
    detect_system
    install_dependencies
    
    # 创建用户和目录
    create_user "$user"
    
    # 安装qBittorrent
    install_qbittorrent_binary
    
    # 创建服务
    create_service
    
    # 生成配置
    generate_config "$port" "$up_port" "$password"
    
    # 系统优化
    optimize_vps
    optimize_disk
    
    # 配置防火墙
    configure_firewall "$port" "$up_port"
    
    # 启动服务
    if start_service; then
        show_info "$port" "$up_port"
    else
        log_error "服务启动失败，请检查日志"
        exit 1
    fi
    
    log_info "安装完成！"
    
    # 询问是否重启
    echo
    log_warn "系统优化需要重启才能完全生效"
    read -p "是否立即重启系统？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "系统将在1分钟后重启..."
        shutdown -r +1
    else
        log_info "请记得稍后手动重启系统以应用所有优化"
    fi
}

# 卸载功能
uninstall() {
    log_warn "开始卸载 qBittorrent..."
    
    read -p "请输入要卸载的用户名 [默认: qbittorrent]: " user
    user=${user:-qbittorrent}
    
    # 停止并禁用服务
    systemctl stop qbittorrent-nox@$user 2>/dev/null || true
    systemctl disable qbittorrent-nox@$user 2>/dev/null || true
    
    # 删除二进制文件
    rm -f /usr/bin/qbittorrent-nox
    
    # 删除服务文件
    rm -f /etc/systemd/system/qbittorrent-nox@.service
    systemctl daemon-reload
    
    # 询问是否删除用户数据
    read -p "是否删除用户数据？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        userdel -r "$user" 2>/dev/null || true
        log_info "用户数据已删除"
    fi
    
    # 删除优化配置
    rm -f /etc/sysctl.d/99-qbittorrent-optimization.conf
    sysctl --system
    
    log_info "qBittorrent 卸载完成"
}

# 更新功能
update_script() {
    log_info "检查脚本更新..."
    
    # 下载最新版本
    if wget -O /tmp/qb438_new.sh "$SCRIPT_URL" 2>/dev/null; then
        # 比较版本
        NEW_VERSION=$(grep "^VERSION=" /tmp/qb438_new.sh | cut -d'"' -f2)
        if [ "$VERSION" != "$NEW_VERSION" ]; then
            log_info "发现新版本: $NEW_VERSION"
            cp /tmp/qb438_new.sh "$0"
            chmod +x "$0"
            log_info "更新完成，请重新运行脚本"
            exit 0
        else
            log_info "已是最新版本"
        fi
    else
        log_error "无法下载更新"
    fi
    
    rm -f /tmp/qb438_new.sh
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${PURPLE}╔═══════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║   qBittorrent 4.3.8 安装脚本 (PT优化)  ║${NC}"
        echo -e "${PURPLE}║         PTtools 集成版 v2.0.0         ║${NC}"
        echo -e "${PURPLE}╚═══════════════════════════════════════╝${NC}"
        echo
        echo -e "${GREEN}1.${NC} 交互式安装 (推荐)"
        echo -e "${GREEN}2.${NC} 查看服务状态"
        echo -e "${GREEN}3.${NC} 重启服务"
        echo -e "${GREEN}4.${NC} 查看日志"
        echo -e "${GREEN}5.${NC} 卸载 qBittorrent"
        echo -e "${GREEN}6.${NC} 更新脚本"
        echo -e "${GREEN}0.${NC} 退出"
        echo
        read -p "请选择操作 [0-6]: " choice
        
        case $choice in
            1)
                interactive_install
                read -p "按回车键继续..."
                ;;
            2)
                read -p "请输入用户名 [默认: qbittorrent]: " user
                user=${user:-qbittorrent}
                systemctl status qbittorrent-nox@$user
                read -p "按回车键继续..."
                ;;
            3)
                read -p "请输入用户名 [默认: qbittorrent]: " user
                user=${user:-qbittorrent}
                systemctl restart qbittorrent-nox@$user
                log_info "服务已重启"
                read -p "按回车键继续..."
                ;;
            4)
                read -p "请输入用户名 [默认: qbittorrent]: " user
                user=${user:-qbittorrent}
                journalctl -u qbittorrent-nox@$user -n 50
                read -p "按回车键继续..."
                ;;
            5)
                uninstall
                read -p "按回车键继续..."
                ;;
            6)
                update_script
                read -p "按回车键继续..."
                ;;
            0)
                log_info "感谢使用！"
                exit 0
                ;;
            *)
                log_error "无效选项"
                sleep 1
                ;;
        esac
    done
}

# 脚本入口
if [ "$#" -eq 0 ]; then
    # 无参数，显示菜单
    main_menu
elif [ "$#" -ge 2 ]; then
    # 有参数，命令行模式
    cmdline_install "$@"
else
    # 参数不足
    echo "Usage: $0                        # 交互式安装"
    echo "       $0 <user> <password> [port] [up_port]  # 命令行安装"
    exit 1
fi
