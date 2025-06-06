#!/bin/bash

# qBittorrent 4.3.8 安装脚本
# 适用于 PTtools 项目
# Github: https://github.com/everett7623/pttools

# 参数
QB_USER=${1:-"admin"}
QB_PASS=${2:-"admin"}
QB_PORT=${3:-"8080"}
QB_LISTEN_PORT=${4:-"23333"}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() {
    printf "${1}${2}${NC}\n"
}

print_color $BLUE "开始安装 qBittorrent 4.3.8..."
print_color $YELLOW "用户名: $QB_USER"
print_color $YELLOW "密码: $QB_PASS"
print_color $YELLOW "WebUI端口: $QB_PORT"
print_color $YELLOW "监听端口: $QB_LISTEN_PORT"

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

# 更新系统
print_color $YELLOW "更新系统..."
if [[ $OS == "debian" ]]; then
    apt-get update
    apt-get install -y wget curl unzip build-essential
elif [[ $OS == "centos" ]]; then
    yum update -y
    yum groupinstall -y "Development Tools"
    yum install -y wget curl unzip
fi

# 创建用户
QB_USER_SYSTEM="qbittorrent"
if ! id "$QB_USER_SYSTEM" &>/dev/null; then
    useradd -r -s /bin/false "$QB_USER_SYSTEM"
    print_color $GREEN "创建用户 $QB_USER_SYSTEM"
fi

# 下载并安装 qBittorrent 4.3.8
print_color $YELLOW "下载 qBittorrent 4.3.8..."
cd /tmp

# 根据系统架构选择下载链接
ARCH=$(uname -m)
if [[ $ARCH == "x86_64" ]]; then
    QB_URL="https://github.com/qbittorrent/qBittorrent/releases/download/release-4.3.8/qbittorrent-nox"
else
    print_color $RED "不支持的架构: $ARCH"
    exit 1
fi

# 下载qBittorrent
wget -O qbittorrent-nox "$QB_URL"
if [[ $? -ne 0 ]]; then
    print_color $RED "下载 qBittorrent 失败"
    exit 1
fi

# 安装qBittorrent
chmod +x qbittorrent-nox
mv qbittorrent-nox /usr/local/bin/
print_color $GREEN "qBittorrent 4.3.8 安装完成"

# 创建配置目录
QB_CONFIG_DIR="/home/$QB_USER_SYSTEM/.config/qBittorrent"
QB_DATA_DIR="/home/$QB_USER_SYSTEM/.local/share/data/qBittorrent"
mkdir -p "$QB_CONFIG_DIR"
mkdir -p "$QB_DATA_DIR"
mkdir -p "/opt/downloads"

# 生成配置文件
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
Session\AsyncIOThreadsCount=8
Session\CheckingMemUsageSize=32
Session\CoalesceReadWrite=false
Session\FilePoolSize=40
Session\GuidedReadCache=true
Session\MultiConnectionsPerIp=false
Session\SendBufferWatermark=500
Session\SendBufferLowWatermark=10
Session\SendBufferWatermarkFactor=50
Session\SocketBacklogSize=30
Session\UseOSCache=true
Session\Port=$QB_LISTEN_PORT
Session\UPnP=false

[Core]
AutoDeleteAddedTorrentFile=Never

[Preferences]
Advanced\AnnounceToAllTrackers=false
Advanced\RecheckOnCompletion=false
Advanced\useSystemIconTheme=true
Bittorrent\AddTrackers=false
Bittorrent\DHT=false
Bittorrent\Encryption=1
Bittorrent\LSD=false
Bittorrent\MaxConnecs=200
Bittorrent\MaxConnecsPerTorrent=100
Bittorrent\MaxRatioAction=0
Bittorrent\PeX=false
Bittorrent\uTP=false
Bittorrent\uTP_rate_limited=true
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=0
Connection\PortRangeMin=$QB_LISTEN_PORT
Downloads\DiskWriteCacheSize=64
Downloads\DiskWriteCacheTTL=60
Downloads\SavePath=/opt/downloads
Downloads\SaveResumeDataInterval=60
Downloads\ScanDirsV2=@Variant(\\0\\0\\0\\x1c\\0\\0\\0\\0)
Downloads\TorrentExportDir=
General\Locale=zh
Queueing\MaxActiveDownloads=5
Queueing\MaxActiveTorrents=10
Queueing\MaxActiveUploads=10
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
WebUI\Port=$QB_PORT
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
ExecStart=/usr/local/bin/qbittorrent-nox --webui-port=$QB_PORT
Restart=on-failure
RestartSec=5
TimeoutStopSec=infinity

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable qbittorrent
systemctl start qbittorrent

# 检查服务状态
sleep 5
if systemctl is-active --quiet qbittorrent; then
    print_color $GREEN "qBittorrent 4.3.8 服务启动成功"
    print_color $BLUE "WebUI 地址: http://你的IP:$QB_PORT"
    print_color $BLUE "用户名: $QB_USER"
    print_color $BLUE "密码: $QB_PASS"
else
    print_color $RED "qBittorrent 服务启动失败"
    exit 1
fi

print_color $GREEN "qBittorrent 4.3.8 安装完成！"
