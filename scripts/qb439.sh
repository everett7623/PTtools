#!/bin/bash

# qBittorrent 4.3.9 安装脚本 (杰瑞大佬版本优化)
# 适用于 PTtools 项目
# Github: https://github.com/everett7623/pttools

# 默认参数
QB_USER="admin"
QB_PASS="admin"
QB_CACHE=256
INSTALL_QB=false
INSTALL_LT=false
INSTALL_AUTOBRR=false
INSTALL_VERTEX=false
INSTALL_AUTOREMOVE=false
ENABLE_BBR3=false
ENABLE_BBRX=false
CUSTOM_PORT=false
PORT_NUMBER=8080

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() {
    printf "${1}${2}${NC}\n"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            QB_USER="$2"
            shift 2
            ;;
        -p|--password)
            QB_PASS="$2"
            shift 2
            ;;
        -c|--cache)
            QB_CACHE="$2"
            shift 2
            ;;
        -q|--qbittorrent)
            INSTALL_QB=true
            shift
            ;;
        -l|--libtorrent)
            INSTALL_LT=true
            shift
            ;;
        -b|--autobrr)
            INSTALL_AUTOBRR=true
            shift
            ;;
        -v|--vertex)
            INSTALL_VERTEX=true
            shift
            ;;
        -r|--autoremove)
            INSTALL_AUTOREMOVE=true
            shift
            ;;
        -3|--bbr3)
            ENABLE_BBR3=true
            shift
            ;;
        -x|--bbrx)
            ENABLE_BBRX=true
            shift
            ;;
        -o|--port)
            CUSTOM_PORT=true
            PORT_NUMBER="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

print_color $BLUE "开始安装 qBittorrent 4.3.9 (杰瑞大佬优化版)..."
print_color $YELLOW "用户名: $QB_USER"
print_color $YELLOW "密码: $QB_PASS"
print_color $YELLOW "缓存大小: ${QB_CACHE}MB"

# 检测系统
if [[ -f /etc/redhat-release ]]; then
    OS="centos"
    PM="yum"
elif [[ -f /etc/debian_version ]]; then
    OS="debian"
    PM="apt-get"
else
    print_color $RED "不支持的操作系统"
    exit 1
fi

# 安装依赖
print_color $YELLOW "安装依赖包..."
if [[ $OS == "debian" ]]; then
    apt-get update
    apt-get install -y build-essential cmake git pkg-config \
        automake libtool libboost-dev libboost-system-dev \
        libboost-chrono-dev libboost-random-dev libssl-dev \
        qtbase5-dev qttools5-dev-tools libqt5svg5-dev \
        python3-dev python3-setuptools zlib1g-dev
elif [[ $OS == "centos" ]]; then
    yum groupinstall -y "Development Tools"
    yum install -y cmake git pkgconfig automake libtool \
        boost-devel openssl-devel qt5-qtbase-devel \
        qt5-qttools-devel qt5-qtsvg-devel python3-devel \
        python3-setuptools zlib-devel
fi

# 启用BBR v3
if [[ $ENABLE_BBR3 == true ]]; then
    print_color $YELLOW "启用 BBR v3..."
    modprobe tcp_bbr
    echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
    echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
    sysctl -p
    print_color $GREEN "BBR v3 已启用"
fi

# 创建用户
QB_USER_SYSTEM="qbittorrent"
if ! id "$QB_USER_SYSTEM" &>/dev/null; then
    useradd -r -s /bin/false "$QB_USER_SYSTEM"
    print_color $GREEN "创建用户 $QB_USER_SYSTEM"
fi

# 编译安装 libtorrent-rasterbar 1.2.x (如果需要)
if [[ $INSTALL_LT == true ]]; then
    print_color $YELLOW "编译安装 libtorrent-rasterbar..."
    cd /tmp
    git clone --depth 1 --branch RC_1_2 https://github.com/arvidn/libtorrent.git
    cd libtorrent
    
    mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=14
    make -j$(nproc)
    make install
    ldconfig
    
    print_color $GREEN "libtorrent-rasterbar 编译完成"
fi

# 编译安装 qBittorrent 4.3.9
print_color $YELLOW "编译安装 qBittorrent 4.3.9..."
cd /tmp
git clone --depth 1 --branch release-4.3.9 https://github.com/qbittorrent/qBittorrent.git
cd qBittorrent

# 配置编译选项
./configure --disable-gui --enable-systemd --with-boost-libdir=/usr/lib/x86_64-linux-gnu

# 编译
make -j$(nproc)
make install

# 创建配置目录
QB_CONFIG_DIR="/home/$QB_USER_SYSTEM/.config/qBittorrent"
QB_DATA_DIR="/home/$QB_USER_SYSTEM/.local/share/data/qBittorrent"
mkdir -p "$QB_CONFIG_DIR"
mkdir -p "$QB_DATA_DIR"
mkdir -p "/opt/downloads"

# 生成优化的配置文件
cat > "$QB_CONFIG_DIR/qBittorrent.conf" << EOF
[Application]
FileLogger\Age=1
FileLogger\AgeType=1
FileLogger\Backup=true
FileLogger\DeleteOld=true
FileLogger\Enabled=true
FileLogger\MaxSizeBytes=66560
FileLogger\Path=/home/$QB_USER_SYSTEM/.local/share/data/qBittorrent

[BitTorrent]
Session\AnnounceToAllTiers=true
Session\AsyncIOThreadsCount=16
Session\CheckingMemUsageSize=$QB_CACHE
Session\CoalesceReadWrite=true
Session\FilePoolSize=100
Session\GuidedReadCache=true
Session\MultiConnectionsPerIp=true
Session\SendBufferWatermark=1024
Session\SendBufferLowWatermark=128
Session\SendBufferWatermarkFactor=50
Session\SocketBacklogSize=100
Session\UseOSCache=true
Session\Port=6881
Session\UPnP=false
Session\GlobalMaxSeedingMinutes=0
Session\SeedChokingAlgorithm=RoundRobin
Session\UploadChokingAlgorithm=AntiLeech

[Core]
AutoDeleteAddedTorrentFile=Never

[Preferences]
Advanced\AnnounceToAllTrackers=true
Advanced\RecheckOnCompletion=false
Advanced\useSystemIconTheme=true
Bittorrent\AddTrackers=false
Bittorrent\DHT=false
Bittorrent\Encryption=2
Bittorrent\LSD=false
Bittorrent\MaxConnecs=500
Bittorrent\MaxConnecsPerTorrent=100
Bittorrent\MaxRatioAction=0
Bittorrent\PeX=false
Bittorrent\uTP=false
Bittorrent\uTP_rate_limited=true
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=0
Connection\PortRangeMin=6881
Downloads\DiskWriteCacheSize=$QB_CACHE
Downloads\DiskWriteCacheTTL=60
Downloads\SavePath=/opt/downloads
Downloads\SaveResumeDataInterval=60
Downloads\ScanDirsV2=@Variant(\\0\\0\\0\\x1c\\0\\0\\0\\0)
Downloads\TorrentExportDir=
General\Locale=zh
Queueing\MaxActiveDownloads=10
Queueing\MaxActiveTorrents=20
Queueing\MaxActiveUploads=20
Queueing\QueueingSystemEnabled=false
WebUI\Address=*
WebUI\AlternativeUIEnabled=false
WebUI\AuthSubnetWhitelistEnabled=false
WebUI\BanDuration=3600
WebUI\CSRFProtection=true
WebUI\ClickjackingProtection=true
WebUI\CustomHTTPHeaders=
WebUI\CustomHTTPHeadersEnabled=false
WebUI\HTTPS\\CertificatePath=
WebUI\HTTPS\\Enabled=false
WebUI\HTTPS\\KeyPath=
WebUI\HostHeaderValidation=true
WebUI\LocalHostAuth=false
WebUI\MaxAuthenticationFailCount=5
WebUI\Port=$PORT_NUMBER
WebUI\RootFolder=
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\UseUPnP=false
WebUI\Username=$QB_USER
EOF

# 设置密码
QB_PASS_HASH=$(echo -n "$QB_PASS" | md5sum | cut -d' ' -f1)
sed -i "s/WebUI\\\\Username=$QB_USER/WebUI\\\\Username=$QB_USER\\nWebUI\\\\Password_PBKDF2=\"@ByteArray($QB_PASS_HASH)\"/" "$QB_CONFIG_DIR/qBittorrent.conf"

# 设置权限
chown -R "$QB_USER_SYSTEM:$QB_USER_SYSTEM" "/home/$QB_USER_SYSTEM"
chown -R "$QB_USER_SYSTEM:$QB_USER_SYSTEM" "/opt/downloads"

# 创建 systemd 服务
cat > /etc/systemd/system/qbittorrent.service << EOF
[Unit]
Description=qBittorrent Daemon Service
Documentation=man:qbittorrent-nox(1)
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=exec
User=$QB_USER_SYSTEM
ExecStart=/usr/local/bin/qbittorrent-nox --webui-port=$PORT_NUMBER
Restart=on-failure
RestartSec=5
TimeoutStopSec=infinity
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 系统优化
print_color $YELLOW "应用系统优化..."
# 内核参数优化
cat >> /etc/sysctl.conf << EOF

# qBittorrent 优化
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 30000
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 2
net.ipv4.tcp_low_latency = 1
net.ipv4.ip_local_port_range = 1024 65535
EOF

sysctl -p

# 文件描述符限制
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# 启动服务
systemctl daemon-reload
systemctl enable qbittorrent
systemctl start qbittorrent

# 检查服务状态
sleep 5
if systemctl is-active --quiet qbittorrent; then
    print_color $GREEN "qBittorrent 4.3.9 服务启动成功"
    print_color $BLUE "WebUI 地址: http://你的IP:$PORT_NUMBER"
    print_color $BLUE "用户名: $QB_USER"
    print_color $BLUE "密码: $QB_PASS"
    print_color $BLUE "缓存大小: ${QB_CACHE}MB"
    if [[ $ENABLE_BBR3 == true ]]; then
        print_color $BLUE "BBR v3 已启用"
    fi
else
    print_color $RED "qBittorrent 服务启动失败"
    journalctl -u qbittorrent --no-pager -l
    exit 1
fi

print_color $GREEN "qBittorrent 4.3.9 安装完成！"
