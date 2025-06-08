#!/bin/bash

# qBittorrent 4.3.8 快速部署脚本（优化版）
# 默认使用预编译二进制，可选源码编译
# 基于 PTtools 项目需求优化

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 版本定义
QB_VERSION="4.3.8"
LT_VERSION="1.2.20"

# 安装模式：fast（预编译）或 compile（源码编译）
INSTALL_MODE="${1:-fast}"

# 预编译二进制下载地址
declare -A BINARY_URLS
BINARY_URLS["x86_64"]="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.8_v1.2.20/x86_64-qbittorrent-nox"
BINARY_URLS["aarch64"]="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.8_v1.2.20/aarch64-qbittorrent-nox"
BINARY_URLS["armv7l"]="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.8_v1.2.20/armv7-qbittorrent-nox"

# 备用下载源
declare -A BACKUP_URLS
BACKUP_URLS["x86_64"]="https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox"
BACKUP_URLS["aarch64"]="https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox"

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

# 错误处理
set -e
trap 'log_error "脚本执行失败在第 $LINENO 行"; exit 1' ERR

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检查系统架构
check_arch() {
    ARCH=$(uname -m)
    log_info "检测到系统架构: $ARCH"
    
    if [[ ! "${BINARY_URLS[$ARCH]}" ]] && [[ "$INSTALL_MODE" == "fast" ]]; then
        log_warn "当前架构 $ARCH 不支持预编译版本，切换到编译模式"
        INSTALL_MODE="compile"
    fi
}

# 检查系统类型
check_system() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
        log_info "检测到Debian/Ubuntu系统"
    elif [ -f /etc/redhat-release ]; then
        OS="centos" 
        log_info "检测到CentOS/RHEL系统"
    else
        log_error "不支持的系统类型"
        exit 1
    fi
}

# 快速安装依赖（最小化）
install_minimal_deps() {
    log_info "安装最小依赖..."
    
    if [ "$OS" = "debian" ]; then
        apt-get update
        apt-get install -y curl wget
    elif [ "$OS" = "centos" ]; then
        yum install -y curl wget
    fi
}

# 快速安装qBittorrent（预编译）
fast_install_qbittorrent() {
    log_info "使用预编译二进制快速安装 qBittorrent $QB_VERSION..."
    
    # 下载预编译二进制
    local url="${BINARY_URLS[$ARCH]}"
    local backup_url="${BACKUP_URLS[$ARCH]}"
    
    log_info "下载预编译的 qbittorrent-nox..."
    
    # 尝试主下载源
    if ! wget -O /usr/local/bin/qbittorrent-nox "$url" 2>/dev/null; then
        log_warn "主下载源失败，尝试备用源..."
        if ! wget -O /usr/local/bin/qbittorrent-nox "$backup_url" 2>/dev/null; then
            log_error "下载预编译二进制失败"
            log_info "您可以尝试使用编译模式: $0 compile"
            exit 1
        fi
    fi
    
    # 设置执行权限
    chmod +x /usr/local/bin/qbittorrent-nox
    
    # 创建符号链接以兼容systemd服务
    ln -sf /usr/local/bin/qbittorrent-nox /usr/bin/qbittorrent-nox
    
    log_info "qBittorrent 安装完成（预编译版本）"
}

# 编译依赖安装（完整）
install_compile_deps() {
    log_info "安装编译依赖..."
    
    if [ "$OS" = "debian" ]; then
        apt-get update
        apt-get install -y \
            build-essential \
            cmake \
            git \
            pkg-config \
            automake \
            libtool \
            libboost-dev \
            libboost-chrono-dev \
            libboost-random-dev \
            libboost-system-dev \
            libssl-dev \
            qtbase5-dev \
            qttools5-dev-tools \
            zlib1g-dev \
            libqt5svg5-dev \
            python3
    elif [ "$OS" = "centos" ]; then
        yum groupinstall -y "Development Tools"
        yum install -y \
            cmake \
            git \
            pkgconfig \
            automake \
            libtool \
            boost-devel \
            openssl-devel \
            qt5-qtbase-devel \
            qt5-qttools-devel \
            zlib-devel \
            qt5-qtsvg-devel \
            python3
    fi
}

# 编译安装libtorrent
compile_install_libtorrent() {
    log_info "编译安装 libtorrent-rasterbar $LT_VERSION..."
    
    cd /tmp
    
    # 下载源码
    if [ ! -f "libtorrent-rasterbar-${LT_VERSION}.tar.gz" ]; then
        wget https://github.com/arvidn/libtorrent/releases/download/v${LT_VERSION}/libtorrent-rasterbar-${LT_VERSION}.tar.gz
    fi
    
    tar xf libtorrent-rasterbar-${LT_VERSION}.tar.gz
    cd libtorrent-rasterbar-${LT_VERSION}
    
    # 配置编译（使用优化选项加速）
    ./configure \
        --enable-encryption \
        --disable-debug \
        --enable-optimizations \
        --with-libgeoip=system \
        CXXFLAGS="-O3 -march=native"
    
    # 并行编译
    make -j$(nproc)
    make install
    
    # 更新库链接
    if [ "$OS" = "debian" ]; then
        ldconfig
    elif [ "$OS" = "centos" ]; then
        echo "/usr/local/lib" > /etc/ld.so.conf.d/libtorrent.conf
        ldconfig
    fi
}

# 编译安装qBittorrent
compile_install_qbittorrent() {
    log_info "编译安装 qBittorrent $QB_VERSION..."
    
    cd /tmp
    
    # 下载源码
    if [ ! -f "qbittorrent-${QB_VERSION}.tar.gz" ]; then
        wget https://github.com/qbittorrent/qBittorrent/archive/release-${QB_VERSION}.tar.gz -O qbittorrent-${QB_VERSION}.tar.gz
    fi
    
    tar xf qbittorrent-${QB_VERSION}.tar.gz
    cd qBittorrent-release-${QB_VERSION}
    
    # 根据系统设置boost路径
    if [ "$OS" = "debian" ]; then
        BOOST_LIB_PATH="/usr/lib/x86_64-linux-gnu"
    elif [ "$OS" = "centos" ]; then
        BOOST_LIB_PATH="/usr/lib64"
    fi
    
    # 配置编译
    ./configure \
        --disable-gui \
        --enable-systemd \
        --with-boost-libdir=$BOOST_LIB_PATH \
        CXXFLAGS="-O3 -march=native"
    
    # 并行编译
    make -j$(nproc)
    make install
}

# 创建qbittorrent用户
create_user() {
    log_info "创建qbittorrent用户..."
    
    # 如果用户已存在，跳过创建
    if id "qbittorrent" &>/dev/null; then
        log_warn "用户 qbittorrent 已存在，跳过创建"
        return 0
    fi
    
    # 创建系统用户
    useradd --system --shell /usr/sbin/nologin --home-dir /home/qbittorrent --create-home qbittorrent
    
    # 创建必要目录
    mkdir -p /home/qbittorrent/.config/qBittorrent
    mkdir -p /home/qbittorrent/.local/share/data/qBittorrent
    mkdir -p /opt/downloads
    
    # 设置权限
    chown -R qbittorrent:qbittorrent /home/qbittorrent
    chown -R qbittorrent:qbittorrent /opt/downloads
    chmod -R 755 /opt/downloads
}

# 优化的配置函数
configure_qbittorrent() {
    log_info "配置qBittorrent..."
    
    # 确保目录存在
    mkdir -p /home/qbittorrent/.config/qBittorrent
    
    # 生成配置文件
    cat > /home/qbittorrent/.config/qBittorrent/qBittorrent.conf << 'EOF'
[BitTorrent]
Session\DefaultSavePath=/opt/downloads
Session\TempPathEnabled=false
Session\Port=8999
Session\QueueingSystemEnabled=false
Session\MaxActiveDownloads=100
Session\MaxActiveUploads=100
Session\MaxActiveTorrents=200

[Preferences]
Downloads\SavePath=/opt/downloads
Downloads\TempPathEnabled=false
Downloads\UseIncompleteExtension=false
Downloads\PreAllocation=false
General\Locale=zh
WebUI\Username=admin
WebUI\Password_PBKDF2="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)"
WebUI\LocalHostAuth=false
WebUI\Port=8080
WebUI\CSRFProtection=false
Connection\PortRangeMin=8999
Connection\PortRangeMax=8999

[Application]
FileLogger\Enabled=false

[Core]
AutoDeleteAddedTorrentFile=Never

[Meta]
MigrationVersion=4
EOF

    # 设置权限
    chown qbittorrent:qbittorrent /home/qbittorrent/.config/qBittorrent/qBittorrent.conf
    chmod 600 /home/qbittorrent/.config/qBittorrent/qBittorrent.conf
}

# 创建systemd服务
create_service() {
    log_info "创建systemd服务..."
    
    # 检查systemd版本
    SYSTEMD_VERSION=$(systemctl --version | head -1 | awk '{print $2}')
    if [ "$SYSTEMD_VERSION" -ge 240 ] 2>/dev/null; then
        SERVICE_TYPE="exec"
    else
        SERVICE_TYPE="simple"
    fi
    
    cat > /etc/systemd/system/qbittorrent.service << EOF
[Unit]
Description=qBittorrent Command Line Client
After=network-online.target
Wants=network-online.target

[Service]
Type=$SERVICE_TYPE
User=qbittorrent
Group=qbittorrent
UMask=007
WorkingDirectory=/home/qbittorrent
ExecStart=/usr/local/bin/qbittorrent-nox --webui-port=8080 --profile=/home/qbittorrent
Restart=on-failure
RestartSec=10
TimeoutStopSec=1800

# 性能优化
LimitNOFILE=100000
Nice=-10

# 环境变量
Environment=HOME=/home/qbittorrent
Environment=XDG_CONFIG_HOME=/home/qbittorrent/.config
Environment=XDG_DATA_HOME=/home/qbittorrent/.local/share

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable qbittorrent
}

# 系统优化
optimize_system() {
    log_info "应用系统优化..."
    
    # 增加文件句柄限制
    if ! grep -q "fs.file-max" /etc/sysctl.conf; then
        echo "fs.file-max = 2097152" >> /etc/sysctl.conf
    fi
    
    # 网络优化
    cat >> /etc/sysctl.conf << EOF
# qBittorrent 优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 250000
net.ipv4.tcp_congestion_control = bbr
EOF
    
    sysctl -p
    
    # 如果是ext4文件系统，减少保留空间
    ROOT_FS=$(df -h / | awk 'NR==2 {print $1}')
    if [[ $(blkid -o value -s TYPE $ROOT_FS) == "ext4" ]]; then
        tune2fs -m 1 $ROOT_FS 2>/dev/null || true
    fi
}

# 防火墙配置
configure_firewall() {
    log_info "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        ufw allow 8080/tcp
        ufw allow 8999/tcp
        ufw allow 8999/udp
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=8999/tcp
        firewall-cmd --permanent --add-port=8999/udp
        firewall-cmd --reload
    fi
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    rm -rf /tmp/libtorrent-rasterbar-*
    rm -rf /tmp/qBittorrent-release-*
    rm -f /tmp/qbittorrent-*.tar.gz
    rm -f /tmp/libtorrent-*.tar.gz
}

# 启动服务
start_service() {
    log_info "启动qBittorrent服务..."
    
    systemctl start qbittorrent
    
    # 等待服务启动
    sleep 3
    
    if systemctl is-active --quiet qbittorrent; then
        log_info "qBittorrent服务启动成功"
    else
        log_error "qBittorrent服务启动失败"
        systemctl status qbittorrent --no-pager
        exit 1
    fi
}

# 获取IP地址
get_server_ip() {
    local ip=""
    ip=$(curl -s --connect-timeout 3 ip.sb 2>/dev/null)
    if [ -z "$ip" ]; then
        ip=$(curl -s --connect-timeout 3 ipinfo.io/ip 2>/dev/null)
    fi
    if [ -z "$ip" ]; then
        ip=$(ip route get 1 2>/dev/null | awk '{print $(NF-2);exit}')
    fi
    if [ -z "$ip" ]; then
        ip="localhost"
    fi
    echo "$ip"
}

# 显示安装结果
show_result() {
    clear
    
    local server_ip=$(get_server_ip)
    local install_time=$((SECONDS / 60))
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        qBittorrent ${QB_VERSION} 安装完成！                          ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  安装模式: ${WHITE}${INSTALL_MODE}${GREEN}                                         ║${NC}"
    echo -e "${GREEN}║  安装耗时: ${WHITE}${install_time} 分钟${GREEN}                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}🌐 访问信息:${NC}"
    echo -e "   WebUI地址:   ${WHITE}http://$server_ip:8080${NC}"
    echo -e "   用户名:      ${WHITE}admin${NC}"
    echo -e "   密码:        ${WHITE}adminadmin${NC}"
    echo -e "   BT端口:      ${WHITE}8999${NC}"
    echo
    echo -e "${CYAN}📁 目录信息:${NC}"
    echo -e "   下载目录:    ${WHITE}/opt/downloads${NC}"
    echo -e "   配置目录:    ${WHITE}/home/qbittorrent/.config/qBittorrent${NC}"
    echo
    echo -e "${CYAN}🔧 服务管理:${NC}"
    echo -e "   查看状态:    ${WHITE}systemctl status qbittorrent${NC}"
    echo -e "   重启服务:    ${WHITE}systemctl restart qbittorrent${NC}"
    echo -e "   查看日志:    ${WHITE}journalctl -u qbittorrent -f${NC}"
    echo
    echo -e "${YELLOW}⚠️  注意事项:${NC}"
    echo -e "   1. 首次登录后请及时修改默认密码"
    echo -e "   2. 已禁用CSRF保护以支持第三方工具"
    echo -e "   3. 已关闭文件预分配以提升性能"
    echo -e "   4. 系统已优化，建议重启以应用所有优化"
    echo
}

# 主函数
main() {
    SECONDS=0  # 开始计时
    
    log_info "qBittorrent $QB_VERSION 快速部署脚本"
    log_info "安装模式: $INSTALL_MODE"
    
    # 基础检查
    check_root
    check_system
    check_arch
    
    # 根据模式选择安装方式
    if [[ "$INSTALL_MODE" == "fast" ]]; then
        log_info "使用快速安装模式（预编译二进制）"
        install_minimal_deps
        fast_install_qbittorrent
    else
        log_info "使用编译安装模式（从源码编译）"
        install_compile_deps
        compile_install_libtorrent
        compile_install_qbittorrent
        cleanup
    fi
    
    # 通用配置
    create_user
    configure_qbittorrent
    create_service
    configure_firewall
    optimize_system
    start_service
    
    # 显示结果
    show_result
}

# 显示帮助
show_help() {
    echo "使用方法: $0 [模式]"
    echo
    echo "模式:"
    echo "  fast     - 快速安装（使用预编译二进制，默认）"
    echo "  compile  - 编译安装（从源码编译）"
    echo
    echo "示例:"
    echo "  $0          # 默认快速安装"
    echo "  $0 fast     # 快速安装"
    echo "  $0 compile  # 编译安装"
}

# 参数处理
case "$1" in
    fast|compile)
        main
        ;;
    -h|--help|help)
        show_help
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "无效的参数: $1"
        show_help
        exit 1
        ;;
esac
