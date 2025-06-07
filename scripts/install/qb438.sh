#!/bin/bash

# qBittorrent 4.3.8 快速安装脚本
# 使用预编译版本，针对VPS优化

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置变量
QB_VERSION="4.3.8"
LIBTORRENT_VERSION="1.2.20"
QB_CONFIG_DIR="/root/.config/qBittorrent"
QB_DOWNLOAD_DIR="/opt/downloads"
QB_PORT="8080"
QB_BT_PORT="25000"
QB_USERNAME="admin"
QB_PASSWORD="adminadmin"
CACHE_SIZE="3072"  # 默认缓存大小 3GB

# GitHub加速镜像
GITHUB_PROXY="https://mirror.ghproxy.com/"

# 打印消息函数
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 显示进度
show_progress() {
    local message=$1
    echo -ne "${CYAN}[*] ${message}...${NC}"
}

# 完成进度
done_progress() {
    echo -e " ${GREEN}✓${NC}"
}

# 检查系统
check_system() {
    show_progress "检查系统"
    
    # 检查系统架构
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]]; then
        print_message $RED "错误：仅支持 x86_64 架构！"
        exit 1
    fi
    
    # 检查系统类型
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_message $RED "无法识别操作系统！"
        exit 1
    fi
    
    done_progress
    print_message $GREEN "系统：$OS $VER ($ARCH)"
}

# 安装基础依赖
install_dependencies() {
    show_progress "安装系统依赖"
    
    if [[ "$OS" == "Ubuntu" ]] || [[ "$OS" == "Debian"* ]]; then
        apt-get update >/dev/null 2>&1
        apt-get install -y curl wget tar gzip build-essential pkg-config \
            libssl-dev libgeoip-dev python3 python3-dev python3-setuptools \
            libboost-system-dev libboost-chrono-dev libboost-random-dev \
            qtbase5-dev qttools5-dev-tools libqt5svg5-dev zlib1g-dev >/dev/null 2>&1
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "Red Hat"* ]]; then
        yum groupinstall -y "Development Tools" >/dev/null 2>&1
        yum install -y curl wget tar gzip openssl-devel geoip-devel \
            python3 python3-devel python3-setuptools boost-devel \
            boost-system boost-chrono boost-random qt5-qtbase-devel \
            qt5-qttools-devel qt5-qtsvg-devel zlib-devel >/dev/null 2>&1
    fi
    
    done_progress
}

# 下载预编译的libtorrent
install_libtorrent_prebuilt() {
    show_progress "安装 libtorrent $LIBTORRENT_VERSION (预编译版)"
    
    # 创建临时目录
    TEMP_DIR="/tmp/libtorrent_install"
    mkdir -p $TEMP_DIR
    cd $TEMP_DIR
    
    # 尝试下载预编译版本
    LIBTORRENT_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v${LIBTORRENT_VERSION}/libtorrent-rasterbar-${LIBTORRENT_VERSION}-x86_64.tar.gz"
    
    if ! wget -q --show-progress "${GITHUB_PROXY}${LIBTORRENT_URL}" -O libtorrent.tar.gz 2>/dev/null; then
        # 如果预编译版本不存在，则编译安装
        print_message $YELLOW "\n预编译版本不可用，开始编译安装..."
        compile_libtorrent
    else
        # 解压并安装
        tar -xf libtorrent.tar.gz
        cp -rf libtorrent-rasterbar/* /usr/local/
        ldconfig
    fi
    
    # 清理
    cd /
    rm -rf $TEMP_DIR
    
    done_progress
}

# 编译libtorrent（备用方案）
compile_libtorrent() {
    print_message $BLUE "编译 libtorrent $LIBTORRENT_VERSION..."
    
    cd /tmp
    wget "${GITHUB_PROXY}https://github.com/arvidn/libtorrent/releases/download/v${LIBTORRENT_VERSION}/libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz"
    tar -xf libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz
    cd libtorrent-rasterbar-${LIBTORRENT_VERSION}
    
    # 优化编译配置
    ./configure \
        --disable-debug \
        --enable-encryption \
        --with-boost-libdir=/usr/lib/x86_64-linux-gnu \
        --with-libiconv \
        CXXFLAGS="-O3 -march=native -pipe" \
        LDFLAGS="-Wl,-O1 -Wl,--as-needed"
    
    # 使用所有CPU核心编译
    make -j$(nproc)
    make install
    ldconfig
    
    cd /
    rm -rf /tmp/libtorrent-rasterbar-${LIBTORRENT_VERSION}*
}

# 安装qBittorrent
install_qbittorrent() {
    show_progress "安装 qBittorrent ${QB_VERSION}"
    
    # 创建临时目录
    TEMP_DIR="/tmp/qb_install"
    mkdir -p $TEMP_DIR
    cd $TEMP_DIR
    
    # 尝试下载预编译版本
    QB_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v${LIBTORRENT_VERSION}/x86_64-qbittorrent-nox"
    
    if wget -q --show-progress "${GITHUB_PROXY}${QB_URL}" -O qbittorrent-nox 2>/dev/null; then
        # 使用预编译版本
        chmod +x qbittorrent-nox
        mv qbittorrent-nox /usr/local/bin/
    else
        # 编译安装
        print_message $YELLOW "\n预编译版本不可用，开始编译安装..."
        compile_qbittorrent
    fi
    
    # 清理
    cd /
    rm -rf $TEMP_DIR
    
    done_progress
}

# 编译qBittorrent（备用方案）
compile_qbittorrent() {
    print_message $BLUE "编译 qBittorrent ${QB_VERSION}..."
    
    cd /tmp
    wget "${GITHUB_PROXY}https://github.com/qbittorrent/qBittorrent/archive/release-${QB_VERSION}.tar.gz"
    tar -xf release-${QB_VERSION}.tar.gz
    cd qBittorrent-release-${QB_VERSION}
    
    # 优化编译配置
    ./configure \
        --disable-gui \
        --disable-debug \
        CXXFLAGS="-O3 -march=native -pipe" \
        LDFLAGS="-Wl,-O1 -Wl,--as-needed"
    
    make -j$(nproc)
    make install
    
    cd /
    rm -rf /tmp/release-${QB_VERSION}.tar.gz /tmp/qBittorrent-release-${QB_VERSION}
}

# 创建优化的qBittorrent配置
create_qb_config() {
    show_progress "创建 qBittorrent 配置"
    
    # 创建必要的目录
    mkdir -p $QB_CONFIG_DIR
    mkdir -p $QB_DOWNLOAD_DIR
    mkdir -p $QB_DOWNLOAD_DIR/temp
    chmod -R 755 $QB_DOWNLOAD_DIR
    
    # 计算缓存大小（MB）
    CACHE_SIZE_BYTES=$((CACHE_SIZE * 1024 * 1024))
    
    # 创建优化配置文件
    cat > $QB_CONFIG_DIR/qBittorrent.conf << EOF
[AutoRun]
enabled=false
program=

[Core]
AutoDeleteAddedTorrentFile=Never

[BitTorrent]
Session\AlternativeGlobalDLSpeedLimit=0
Session\AlternativeGlobalUPSpeedLimit=0
Session\BandwidthSchedulerEnabled=false
Session\DefaultSavePath=$QB_DOWNLOAD_DIR
Session\GlobalDLSpeedLimit=0
Session\GlobalMaxRatio=-1
Session\GlobalUPSpeedLimit=0
Session\IgnoreLimitsOnLAN=true
Session\IncludeOverheadInLimits=false
Session\Port=$QB_BT_PORT
Session\QueueingSystemEnabled=false
Session\TempPath=$QB_DOWNLOAD_DIR/temp
Session\UseAlternativeGlobalSpeedLimit=false
Session\AsyncIOThreadsCount=8
Session\CheckingMemUsageSize=256
Session\DiskCacheSize=$CACHE_SIZE
Session\DiskCacheTTL=60
Session\FilePoolSize=500
Session\SendBufferWatermark=500
Session\SendBufferLowWatermark=10
Session\SendBufferWatermarkFactor=50
Session\SocketBacklogSize=50
Session\SuggestMode=false
Session\SendUploadPieceSuggestions=false
Session\CoalesceReadWrite=true
Session\GuidedReadCache=true
Session\MultiConnectionsPerIp=true
Session\ValidateHTTPSTrackerCertificate=false
Session\DisableAutoTMMByDefault=false
Session\DisableAutoTMMTriggers\CategoryChanged=false
Session\DisableAutoTMMTriggers\CategorySavePathChanged=true
Session\DisableAutoTMMTriggers\DefaultSavePathChanged=true

[Preferences]
Advanced\AnnounceToAllTrackers=true
Advanced\AnonymousMode=false
Advanced\IgnoreLimitsLAN=true
Advanced\LtTrackerExchange=true
Advanced\RecheckOnCompletion=false
Advanced\SuperSeeding=false
Advanced\trackerEnabled=true
Advanced\trackerPort=9000
Bittorrent\AddTrackers=false
Bittorrent\DHT=true
Bittorrent\Encryption=1
Bittorrent\LSD=true
Bittorrent\MaxConnecs=-1
Bittorrent\MaxConnecsPerTorrent=-1
Bittorrent\MaxRatio=-1
Bittorrent\MaxRatioAction=0
Bittorrent\MaxUploads=-1
Bittorrent\MaxUploadsPerTorrent=-1
Bittorrent\PeX=true
Bittorrent\uTP=true
Bittorrent\uTP_rate_limited=false
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=0
Connection\PortRangeMin=$QB_BT_PORT
Connection\ResolvePeerCountries=false
Connection\ResolvePeerHostNames=false
Connection\UPnP=false
Downloads\DiskWriteCacheSize=$CACHE_SIZE
Downloads\DiskWriteCacheTTL=60
Downloads\PreAllocation=false
Downloads\SavePath=$QB_DOWNLOAD_DIR/
Downloads\StartInPause=false
Downloads\TempPath=$QB_DOWNLOAD_DIR/temp/
Downloads\TempPathEnabled=true
General\Locale=zh_CN
General\UseRandomPort=false
WebUI\Address=*
WebUI\AlternativeUIEnabled=false
WebUI\AuthSubnetWhitelistEnabled=false
WebUI\BanDuration=3600
WebUI\CSRFProtection=true
WebUI\ClickjackingProtection=true
WebUI\CustomHTTPHeadersEnabled=false
WebUI\HTTPS\Enabled=false
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=false
WebUI\MaxAuthenticationFailCount=5
WebUI\Port=$QB_PORT
WebUI\ReverseProxySupportEnabled=false
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\UseUPnP=false
WebUI\Username=$QB_USERNAME
EOF
    
    done_progress
}

# 设置密码
set_password() {
    show_progress "设置 Web UI 密码"
    
    # 使用 qbittorrent-nox 生成密码哈希
    PBKDF2_PASSWORD=$(echo -n "$QB_PASSWORD" | /usr/local/bin/qbittorrent-nox --webui-password 2>/dev/null | grep -oP '(?<=: ).*')
    
    if [[ -n "$PBKDF2_PASSWORD" ]]; then
        echo "WebUI\Password_PBKDF2=\"$PBKDF2_PASSWORD\"" >> $QB_CONFIG_DIR/qBittorrent.conf
    else
        # 备用方案：使用默认的adminadmin哈希
        echo "WebUI\Password_PBKDF2=\"@ByteArray(rDeaCtG9hVzqKpMKaLRNwg==:pQ5vr2q0J7S0IHlv88xJJh08gvjKoBCA0zRN4C8bTXGGbFe8ERlWNRra3xNhBX3x0yaSYvDONK1mlCddGndVIg==)\"" >> $QB_CONFIG_DIR/qBittorrent.conf
    fi
    
    done_progress
}

# 创建systemd服务
create_systemd_service() {
    show_progress "创建 systemd 服务"
    
    cat > /etc/systemd/system/qbittorrent.service << EOF
[Unit]
Description=qBittorrent-nox service
Documentation=man:qbittorrent-nox(1)
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=exec
User=root
ExecStart=/usr/local/bin/qbittorrent-nox
Restart=on-failure
RestartSec=5s
TimeoutStartSec=0
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable qbittorrent >/dev/null 2>&1
    systemctl start qbittorrent
    
    done_progress
}

# VPS优化设置
optimize_for_vps() {
    show_progress "应用 VPS 优化"
    
    # 检查是否已经有优化设置
    if grep -q "# PTtools qBittorrent VPS Optimization" /etc/sysctl.conf 2>/dev/null; then
        done_progress
        return
    fi
    
    # 系统优化
    cat >> /etc/sysctl.conf << EOF

# PTtools qBittorrent VPS Optimization
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
EOF

    # 加载BBR模块
    if ! lsmod | grep -q tcp_bbr; then
        modprobe tcp_bbr
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    fi
    
    # 应用系统设置
    sysctl -p >/dev/null 2>&1
    
    # 增加文件描述符限制
    if ! grep -q "# PTtools Limits" /etc/security/limits.conf 2>/dev/null; then
        cat >> /etc/security/limits.conf << EOF
# PTtools Limits
* soft nofile 1048576
* hard nofile 1048576
* soft memlock unlimited
* hard memlock unlimited
EOF
    fi
    
    done_progress
}

# 配置防火墙
configure_firewall() {
    show_progress "配置防火墙规则"
    
    # 检查防火墙类型并配置
    if command -v ufw &> /dev/null; then
        ufw allow $QB_PORT/tcp comment "qBittorrent Web UI" >/dev/null 2>&1
        ufw allow $QB_BT_PORT/tcp comment "qBittorrent TCP" >/dev/null 2>&1
        ufw allow $QB_BT_PORT/udp comment "qBittorrent UDP" >/dev/null 2>&1
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$QB_PORT/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=$QB_BT_PORT/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=$QB_BT_PORT/udp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    elif command -v iptables &> /dev/null; then
        iptables -A INPUT -p tcp --dport $QB_PORT -j ACCEPT
        iptables -A INPUT -p tcp --dport $QB_BT_PORT -j ACCEPT
        iptables -A INPUT -p udp --dport $QB_BT_PORT -j ACCEPT
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    
    done_progress
}

# 获取服务器IP
get_server_ip() {
    local ip=$(curl -s -4 icanhazip.com || curl -s -4 ifconfig.me || curl -s -4 ipinfo.io/ip)
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    echo $ip
}

# 显示安装信息
show_install_info() {
    local server_ip=$(get_server_ip)
    
    echo
    print_message $GREEN "╔═══════════════════════════════════════════════════════════════╗"
    print_message $GREEN "║          qBittorrent ${QB_VERSION} 安装成功！                         ║"
    print_message $GREEN "╚═══════════════════════════════════════════════════════════════╝"
    echo
    print_message $CYAN "访问地址：http://${server_ip}:${QB_PORT}"
    print_message $CYAN "用户名：$QB_USERNAME"
    print_message $CYAN "密码：$QB_PASSWORD"
    echo
    print_message $YELLOW "配置信息："
    print_message $YELLOW "• BT 端口：${QB_BT_PORT}"
    print_message $YELLOW "• 下载目录：${QB_DOWNLOAD_DIR}"
    print_message $YELLOW "• 缓存大小：${CACHE_SIZE} MB"
    print_message $YELLOW "• libtorrent：${LIBTORRENT_VERSION}"
    echo
    print_message $GREEN "管理命令："
    print_message $GREEN "• 启动：systemctl start qbittorrent"
    print_message $GREEN "• 停止：systemctl stop qbittorrent"
    print_message $GREEN "• 重启：systemctl restart qbittorrent"
    print_message $GREEN "• 状态：systemctl status qbittorrent"
    print_message $GREEN "• 日志：journalctl -u qbittorrent -f"
    echo
    print_message $PURPLE "优化建议："
    print_message $PURPLE "• 登录后检查并调整连接数限制"
    print_message $PURPLE "• 根据服务器性能调整缓存大小"
    print_message $PURPLE "• 定期清理临时文件"
    echo
}

# 主安装函数
main() {
    print_message $BLUE "╔═══════════════════════════════════════════════════════════════╗"
    print_message $BLUE "║        开始安装 qBittorrent ${QB_VERSION} (快速版)                    ║"
    print_message $BLUE "╚═══════════════════════════════════════════════════════════════╝"
    echo
    
    # 检查系统
    check_system
    
    # 安装依赖
    install_dependencies
    
    # 安装libtorrent
    install_libtorrent_prebuilt
    
    # 安装qBittorrent
    install_qbittorrent
    
    # 创建配置
    create_qb_config
    
    # 设置密码
    set_password
    
    # VPS优化
    optimize_for_vps
    
    # 创建服务
    create_systemd_service
    
    # 配置防火墙
    configure_firewall
    
    # 等待服务启动
    sleep 2
    
    # 显示安装信息
    show_install_info
    
    print_message $GREEN "qBittorrent ${QB_VERSION} 安装完成！"
}

# 运行主函数
main
