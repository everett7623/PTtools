#!/bin/bash
# ========================================
# 脚本名称: qb438.sh
# 脚本描述: qBittorrent 4.3.8 编译安装脚本 (libtorrent 1.2.20)
# 脚本路径: https://raw.githubusercontent.com/everett7623/PTtools/main/scripts/install/qb438.sh
# 使用方法: bash qb438.sh
# 作者: everett7623
# 更新时间: 2025-01-24
# ========================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以root权限运行！"
        exit 1
    fi
}

# 检查系统版本
check_system() {
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        OS="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        OS="ubuntu"
    else
        log_error "不支持的操作系统！"
        exit 1
    fi
    
    # 获取系统版本号
    if [[ "$OS" == "ubuntu" ]]; then
        VERSION=$(lsb_release -rs)
    elif [[ "$OS" == "debian" ]]; then
        VERSION=$(cat /etc/debian_version)
    fi
    
    log_info "检测到系统: $OS $VERSION"
}

# 安装依赖包
install_dependencies() {
    log_info "开始安装依赖包..."
    
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        apt-get update -y
        apt-get install -y \
            build-essential \
            cmake \
            git \
            pkg-config \
            libssl-dev \
            libgeoip-dev \
            zlib1g-dev \
            libboost-dev \
            libboost-system-dev \
            libboost-chrono-dev \
            libboost-random-dev \
            qtbase5-dev \
            qttools5-dev-tools \
            libqt5svg5-dev \
            python3 \
            python3-dev \
            ninja-build \
            wget \
            curl \
            ca-certificates
    fi
    
    log_info "依赖包安装完成"
}

# 创建qbittorrent用户
create_user() {
    if id "qbittorrent" &>/dev/null; then
        log_info "qbittorrent用户已存在"
    else
        log_info "创建qbittorrent用户..."
        useradd -m -s /bin/bash qbittorrent
        log_info "qbittorrent用户创建成功"
    fi
}

# 编译安装libtorrent
install_libtorrent() {
    log_info "开始编译安装 libtorrent 1.2.20..."
    
    cd /tmp
    rm -rf libtorrent-1.2.20
    
    # 下载libtorrent源码
    wget -q --show-progress -O libtorrent-1.2.20.tar.gz https://github.com/arvidn/libtorrent/archive/refs/tags/v1.2.20.tar.gz
    tar -xzf libtorrent-1.2.20.tar.gz
    cd libtorrent-1.2.20
    
    # 配置编译参数
    mkdir build && cd build
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17 \
        -DBUILD_SHARED_LIBS=ON \
        -Dencryption=ON \
        -Diconv=ON
    
    # 编译安装
    make -j$(nproc)
    make install
    
    # 更新动态链接库
    ldconfig
    
    log_info "libtorrent 1.2.20 安装完成"
}

# 编译安装qBittorrent
install_qbittorrent() {
    log_info "开始编译安装 qBittorrent 4.3.8..."
    
    cd /tmp
    rm -rf qBittorrent-4.3.8
    
    # 下载qBittorrent源码
    wget -q --show-progress -O qBittorrent-4.3.8.tar.gz https://github.com/qbittorrent/qBittorrent/archive/refs/tags/release-4.3.8.tar.gz
    tar -xzf qBittorrent-4.3.8.tar.gz
    cd qBittorrent-release-4.3.8
    
    # 配置编译参数
    ./configure \
        --prefix=/usr/local \
        --disable-gui \
        CXXFLAGS="-std=c++17"
    
    # 编译安装
    make -j$(nproc)
    make install
    
    log_info "qBittorrent 4.3.8 安装完成"
}

# 配置qBittorrent
configure_qbittorrent() {
    log_info "开始配置 qBittorrent..."
    
    # 创建配置目录
    mkdir -p /home/qbittorrent/.config/qBittorrent
    mkdir -p /home/qbittorrent/.local/share/qBittorrent
    mkdir -p /opt/downloads
    
    # 创建配置文件
    cat > /home/qbittorrent/.config/qBittorrent/qBittorrent.conf << 'EOF'
[AutoRun]
enabled=false
program=

[BitTorrent]
Session\AsyncIOThreadsCount=8
Session\CheckingMemUsageSize=32
Session\CoalesceReadWrite=true
Session\FilePoolSize=40
Session\GuidedReadCache=true
Session\MultiConnectionsPerIp=true
Session\SendBufferWatermark=512
Session\SendBufferLowWatermark=10
Session\SendBufferWatermarkFactor=200
Session\SocketBacklogSize=100
Session\SuggestMode=true
Session\uTPMixedMode=true

[LegalNotice]
Accepted=true

[Preferences]
Advanced\AnnounceToAllTrackers=true
Advanced\AnonymousMode=false
Advanced\IgnoreLimitsLAN=true
Advanced\LtTrackerExchange=true
Advanced\RecheckOnCompletion=false
Bittorrent\AddTrackers=false
Bittorrent\DHT=true
Bittorrent\Encryption=1
Bittorrent\LSD=true
Bittorrent\MaxConnecs=5000
Bittorrent\MaxConnecsPerTorrent=1000
Bittorrent\MaxUploads=20
Bittorrent\MaxUploadsPerTorrent=5
Bittorrent\PeX=true
Bittorrent\uTP=true
Bittorrent\uTP_rate_limited=false
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=0
Connection\PortRangeMin=6881
Downloads\DiskWriteCacheSize=64
Downloads\DiskWriteCacheTTL=60
Downloads\SavePath=/opt/downloads/
Downloads\ScanDirsV2=@Variant(\0\0\0\x1c\0\0\0\0)
General\Locale=zh_CN
Queueing\MaxActiveDownloads=50
Queueing\MaxActiveTorrents=100
Queueing\MaxActiveUploads=50
Queueing\QueueingEnabled=false
WebUI\Address=*
WebUI\AlternativeUIEnabled=false
WebUI\AuthSubnetWhitelist=@Invalid()
WebUI\AuthSubnetWhitelistEnabled=false
WebUI\CSRFProtection=true
WebUI\ClickjackingProtection=true
WebUI\HTTPS\Enabled=false
WebUI\HostHeaderValidation=true
WebUI\LocalHostAuth=true
WebUI\MaxAuthenticationFailCount=5
WebUI\Port=8080
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\UseUPnP=false
WebUI\Username=admin
EOF

    # 设置默认密码为 adminadmin
    PBKDF2_HASH=$(echo -n 'adminadmin' | openssl dgst -sha512 -binary | openssl enc -base64 -A)
    echo "WebUI\Password_PBKDF2=\"@ByteArray(${PBKDF2_HASH}):adminadmin\"" >> /home/qbittorrent/.config/qBittorrent/qBittorrent.conf
    
    # 设置权限
    chown -R qbittorrent:qbittorrent /home/qbittorrent
    chown -R qbittorrent:qbittorrent /opt/downloads
    chmod 755 /opt/downloads
    
    log_info "qBittorrent 配置完成"
}

# 创建systemd服务
create_systemd_service() {
    log_info "创建 systemd 服务..."
    
    cat > /etc/systemd/system/qbittorrent.service << 'EOF'
[Unit]
Description=qBittorrent Daemon Service
Documentation=https://github.com/qbittorrent/qBittorrent/wiki
After=network.target

[Service]
Type=exec
User=qbittorrent
Group=qbittorrent
UMask=007
ExecStart=/usr/local/bin/qbittorrent-nox
Restart=on-failure
TimeoutStopSec=infinity

[Install]
WantedBy=multi-user.target
EOF

    # 重载systemd
    systemctl daemon-reload
    
    # 启动服务
    systemctl enable qbittorrent.service
    systemctl start qbittorrent.service
    
    log_info "qBittorrent 服务已启动"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."
    
    if command -v ufw &> /dev/null; then
        ufw allow 8080/tcp comment 'qBittorrent Web UI'
        ufw allow 6881/tcp comment 'qBittorrent TCP'
        ufw allow 6881/udp comment 'qBittorrent UDP'
        log_info "UFW 防火墙规则已添加"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=6881/tcp
        firewall-cmd --permanent --add-port=6881/udp
        firewall-cmd --reload
        log_info "Firewalld 防火墙规则已添加"
    else
        log_warning "未检测到防火墙，请手动配置端口 8080(WebUI) 和 6881(BT)"
    fi
}

# 显示安装信息
show_info() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}qBittorrent 4.3.8 安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}访问地址:${NC} http://$(curl -s ip.sb):8080"
    echo -e "${BLUE}默认用户:${NC} admin"
    echo -e "${BLUE}默认密码:${NC} adminadmin"
    echo -e "${BLUE}下载目录:${NC} /opt/downloads"
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo -e "启动服务: systemctl start qbittorrent"
    echo -e "停止服务: systemctl stop qbittorrent"
    echo -e "重启服务: systemctl restart qbittorrent"
    echo -e "查看状态: systemctl status qbittorrent"
    echo -e "查看日志: journalctl -u qbittorrent -f"
    echo ""
    echo -e "${GREEN}========================================${NC}"
}

# 主函数
main() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}qBittorrent 4.3.8 安装脚本${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # 执行安装步骤
    check_root
    check_system
    install_dependencies
    create_user
    install_libtorrent
    install_qbittorrent
    configure_qbittorrent
    create_systemd_service
    configure_firewall
    show_info
    
    log_info "安装脚本执行完成！"
}

# 执行主函数
main "$@"
