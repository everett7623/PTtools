#!/bin/bash

# qBittorrent 4.3.9 安装脚本
# 针对VPS优化版本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
QB_VERSION="4.3.9"
QB_DIR="/usr/local/qbittorrent"
QB_CONFIG_DIR="/root/.config/qBittorrent"
QB_DOWNLOAD_DIR="/root/downloads"
QB_PORT="8080"
QB_BT_PORT="25000"

# 打印消息函数
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 检查系统
check_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_message $RED "无法识别操作系统！"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    print_message $BLUE "安装系统依赖..."
    
    if [[ "$OS" == "Ubuntu" ]] || [[ "$OS" == "Debian"* ]]; then
        apt-get update
        apt-get install -y build-essential pkg-config automake libtool git zlib1g-dev libssl-dev libgeoip-dev
        apt-get install -y libboost-dev libboost-system-dev libboost-chrono-dev libboost-random-dev
        apt-get install -y qtbase5-dev qttools5-dev-tools libqt5svg5-dev python3
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "Red Hat"* ]]; then
        yum groupinstall -y "Development Tools"
        yum install -y git zlib-devel openssl-devel geoip-devel
        yum install -y boost-devel boost-system boost-chrono boost-random
        yum install -y qt5-qtbase-devel qt5-qttools-devel qt5-qtsvg-devel python3
    else
        print_message $RED "不支持的操作系统：$OS"
        exit 1
    fi
}

# 编译安装libtorrent
install_libtorrent() {
    print_message $BLUE "编译安装 libtorrent-rasterbar 1.2.15..."
    
    cd /tmp
    wget https://github.com/arvidn/libtorrent/releases/download/v1.2.15/libtorrent-rasterbar-1.2.15.tar.gz
    tar -xf libtorrent-rasterbar-1.2.15.tar.gz
    cd libtorrent-rasterbar-1.2.15
    
    ./configure --disable-debug --enable-encryption --with-boost-libdir=/usr/lib/x86_64-linux-gnu
    make -j$(nproc)
    make install
    ldconfig
    
    cd /
    rm -rf /tmp/libtorrent-rasterbar-1.2.15*
}

# 编译安装qBittorrent
install_qbittorrent() {
    print_message $BLUE "编译安装 qBittorrent ${QB_VERSION}..."
    
    cd /tmp
    wget https://github.com/qbittorrent/qBittorrent/archive/release-${QB_VERSION}.tar.gz
    tar -xf release-${QB_VERSION}.tar.gz
    cd qBittorrent-release-${QB_VERSION}
    
    ./configure --disable-gui --disable-debug
    make -j$(nproc)
    make install
    
    cd /
    rm -rf /tmp/release-${QB_VERSION}.tar.gz /tmp/qBittorrent-release-${QB_VERSION}
}

# 创建qBittorrent配置
create_qb_config() {
    print_message $BLUE "创建 qBittorrent 配置..."
    
    # 创建必要的目录
    mkdir -p $QB_CONFIG_DIR
    mkdir -p $QB_DOWNLOAD_DIR
    
    # 创建配置文件
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

[Meta]
MigrationVersion=2

[Network]
Cookies=@Invalid()
PortForwardingEnabled=false
Proxy\OnlyForTorrents=false

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
Bittorrent\TrackersList=
Bittorrent\uTP=true
Bittorrent\uTP_rate_limited=false
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=0
Connection\PortRangeMin=$QB_BT_PORT
Connection\ResolvePeerCountries=true
Connection\ResolvePeerHostNames=false
Connection\UPnP=false
Connection\alt_speeds_on=false
Downloads\DiskWriteCacheSize=64
Downloads\DiskWriteCacheTTL=60
Downloads\PreAllocation=false
Downloads\SavePath=$QB_DOWNLOAD_DIR/
Downloads\SaveResumeDataInterval=60
Downloads\ScanDirsV2=@Variant(\0\0\0\x1c\0\0\0\0)
Downloads\StartInPause=false
Downloads\TempPath=$QB_DOWNLOAD_DIR/temp/
Downloads\TempPathEnabled=true
Downloads\TorrentExportDir=
Downloads\UseIncompleteExtension=false
DynDNS\DomainName=changeme.dyndns.org
DynDNS\Enabled=false
DynDNS\Password=
DynDNS\Service=0
DynDNS\Username=
General\Locale=zh_CN
General\UseRandomPort=false
MailNotification\email=
MailNotification\enabled=false
MailNotification\password=
MailNotification\req_auth=true
MailNotification\req_ssl=false
MailNotification\smtp_server=smtp.changeme.com
MailNotification\username=
WebUI\Address=*
WebUI\AlternativeUIEnabled=false
WebUI\AuthSubnetWhitelist=@Invalid()
WebUI\AuthSubnetWhitelistEnabled=false
WebUI\BanDuration=3600
WebUI\CSRFProtection=true
WebUI\ClickjackingProtection=true
WebUI\CustomHTTPHeaders=
WebUI\CustomHTTPHeadersEnabled=false
WebUI\HTTPS\CertificatePath=
WebUI\HTTPS\Enabled=false
WebUI\HTTPS\KeyPath=
WebUI\HostHeaderValidation=true
WebUI\LocalHostAuth=true
WebUI\MaxAuthenticationFailCount=5
WebUI\Port=$QB_PORT
WebUI\ReverseProxySupportEnabled=false
WebUI\RootFolder=
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\TrustedReverseProxiesList=
WebUI\UseUPnP=false
WebUI\Username=admin

[RSS]
AutoDownloader\DownloadRepacks=true
AutoDownloader\SmartEpisodeFilter=s(\\d+)e(\\d+), (\\d+)x(\\d+), "(\\d{4}[.\\-]\\d{1,2}[.\\-]\\d{1,2})", "(\\d{1,2}[.\\-]\\d{1,2}[.\\-]\\d{4})"
EOF
}

# 设置初始密码
set_initial_password() {
    print_message $BLUE "设置 qBittorrent Web UI 初始密码..."
    
    # 默认密码：adminadmin
    # 密码的PBKDF2-SHA512哈希值
    echo "WebUI\Password_PBKDF2=\"@ByteArray(rDeaCtG9hVzqKpMKaLRNwg==:pQ5vr2q0J7S0IHlv88xJJh08gvjKoBCA0zRN4C8bTXGGbFe8ERlWNRra3xNhBX3x0yaSYvDONK1mlCddGndVIg==)\"" >> $QB_CONFIG_DIR/qBittorrent.conf
    
    print_message $YELLOW "Web UI 默认用户名：admin"
    print_message $YELLOW "Web UI 默认密码：adminadmin"
    print_message $RED "请登录后立即修改默认密码！"
}

# 创建systemd服务
create_systemd_service() {
    print_message $BLUE "创建 systemd 服务..."
    
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

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable qbittorrent
    systemctl start qbittorrent
}

# VPS优化设置
optimize_for_vps() {
    print_message $BLUE "应用 VPS 优化设置..."
    
    # 系统优化
    cat >> /etc/sysctl.conf << EOF

# qBittorrent VPS Optimization
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF

    # 加载BBR模块
    modprobe tcp_bbr
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    
    # 应用系统设置
    sysctl -p
    
    # 增加文件描述符限制
    cat >> /etc/security/limits.conf << EOF
* soft nofile 1048576
* hard nofile 1048576
EOF
}

# 配置防火墙
configure_firewall() {
    print_message $BLUE "配置防火墙规则..."
    
    # 检查防火墙类型并配置
    if command -v ufw &> /dev/null; then
        ufw allow $QB_PORT/tcp comment "qBittorrent Web UI"
        ufw allow $QB_BT_PORT/tcp comment "qBittorrent TCP"
        ufw allow $QB_BT_PORT/udp comment "qBittorrent UDP"
        print_message $GREEN "UFW 防火墙规则已添加"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$QB_PORT/tcp
        firewall-cmd --permanent --add-port=$QB_BT_PORT/tcp
        firewall-cmd --permanent --add-port=$QB_BT_PORT/udp
        firewall-cmd --reload
        print_message $GREEN "Firewalld 防火墙规则已添加"
    elif command -v iptables &> /dev/null; then
        iptables -A INPUT -p tcp --dport $QB_PORT -j ACCEPT
        iptables -A INPUT -p tcp --dport $QB_BT_PORT -j ACCEPT
        iptables -A INPUT -p udp --dport $QB_BT_PORT -j ACCEPT
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        print_message $GREEN "iptables 防火墙规则已添加"
    fi
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
    print_message $CYAN "默认用户名：admin"
    print_message $CYAN "默认密码：adminadmin"
    echo
    print_message $YELLOW "重要提示："
    print_message $YELLOW "1. 请立即登录并修改默认密码"
    print_message $YELLOW "2. BT 端口：${QB_BT_PORT}"
    print_message $YELLOW "3. 下载目录：${QB_DOWNLOAD_DIR}"
    echo
    print_message $GREEN "管理命令："
    print_message $GREEN "启动：systemctl start qbittorrent"
    print_message $GREEN "停止：systemctl stop qbittorrent"
    print_message $GREEN "重启：systemctl restart qbittorrent"
    print_message $GREEN "状态：systemctl status qbittorrent"
    echo
}

# 主安装函数
main() {
    print_message $BLUE "开始安装 qBittorrent ${QB_VERSION}..."
    
    # 检查系统
    check_system
    
    # 安装依赖
    install_dependencies
    
    # 安装libtorrent
    install_libtorrent
    
    # 安装qBittorrent
    install_qbittorrent
    
    # 创建配置
    create_qb_config
    
    # 设置初始密码
    set_initial_password
    
    # VPS优化
    optimize_for_vps
    
    # 创建服务
    create_systemd_service
    
    # 配置防火墙
    configure_firewall
    
    # 显示安装信息
    show_install_info
    
    print_message $GREEN "qBittorrent ${QB_VERSION} 安装完成！"
}

# 运行主函数
main