#!/bin/bash

# qBittorrent 4.3.9 安装脚本
# 整合自: https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh
# PTtools项目: https://github.com/everett7623/PTtools

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 基础配置
QB_VERSION="4.3.9"
LIBTORRENT_VERSION="1.2.20"
QB_USER="qbittorrent"
QB_PORT="8080"
QB_DIR="/home/${QB_USER}"
DOWNLOAD_DIR="/opt/downloads"

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误：此脚本必须以root用户运行！${NC}"
   exit 1
fi

# 检查系统类型和版本
check_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
    else
        echo -e "${RED}无法检测系统版本！${NC}"
        exit 1
    fi
    
    # 设置包管理器
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        PACKAGE_MANAGER="apt-get"
    elif [[ "$OS" == "centos" ]] || [[ "$OS" == "rhel" ]] || [[ "$OS" == "fedora" ]]; then
        PACKAGE_MANAGER="yum"
    else
        echo -e "${RED}不支持的操作系统: $OS${NC}"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${CYAN}正在安装依赖包...${NC}"
    
    if [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
        apt-get update
        apt-get install -y build-essential pkg-config automake libtool git perl python3 python3-dev \
            libboost-all-dev libssl-dev libgeoip-dev qtbase5-dev qttools5-dev-tools libqt5svg5-dev \
            zlib1g-dev libpcre3-dev libxslt1-dev libxml2-dev libarchive-dev libgcrypt20-dev \
            libgpg-error-dev libgnutls28-dev ca-certificates curl wget unzip nano cmake ninja-build
    else
        yum groupinstall -y "Development Tools"
        yum install -y epel-release
        yum install -y git perl python3 python3-devel boost-devel openssl-devel geoip-devel \
            qt5-qtbase-devel qt5-linguist zlib-devel pcre-devel libxslt-devel libxml2-devel \
            libarchive-devel libgcrypt-devel gpgme-devel gnutls-devel ca-certificates curl wget \
            unzip nano cmake ninja-build
    fi
    
    echo -e "${GREEN}依赖包安装完成${NC}"
}

# 创建qBittorrent用户
create_user() {
    echo -e "${CYAN}创建qBittorrent用户...${NC}"
    
    if id "${QB_USER}" &>/dev/null; then
        echo -e "${YELLOW}用户 ${QB_USER} 已存在${NC}"
    else
        useradd -m -s /bin/bash ${QB_USER}
        echo -e "${GREEN}用户 ${QB_USER} 创建成功${NC}"
    fi
    
    # 创建下载目录
    mkdir -p ${DOWNLOAD_DIR}
    chown -R ${QB_USER}:${QB_USER} ${DOWNLOAD_DIR}
}

# 编译安装libtorrent
install_libtorrent() {
    echo -e "${CYAN}正在编译安装libtorrent ${LIBTORRENT_VERSION}...${NC}"
    
    cd /tmp
    
    # 下载libtorrent源码
    if [ ! -f "libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz" ]; then
        wget https://github.com/arvidn/libtorrent/releases/download/v${LIBTORRENT_VERSION}/libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz
    fi
    
    tar -zxvf libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz
    cd libtorrent-rasterbar-${LIBTORRENT_VERSION}
    
    # 使用CMake编译（性能更好）
    mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DCMAKE_CXX_STANDARD=17 \
             -Dwebtorrent=ON \
             -Dencryption=ON \
             -DBUILD_SHARED_LIBS=OFF
    
    make -j$(nproc)
    make install
    ldconfig
    
    cd /
    rm -rf /tmp/libtorrent-rasterbar-${LIBTORRENT_VERSION}*
    
    echo -e "${GREEN}libtorrent ${LIBTORRENT_VERSION} 安装完成${NC}"
}

# 编译安装qBittorrent
install_qbittorrent() {
    echo -e "${CYAN}正在编译安装qBittorrent ${QB_VERSION}...${NC}"
    
    cd /tmp
    
    # 下载qBittorrent源码
    if [ ! -f "release-${QB_VERSION}.tar.gz" ]; then
        wget https://github.com/qbittorrent/qBittorrent/archive/release-${QB_VERSION}.tar.gz
    fi
    
    tar -zxvf release-${QB_VERSION}.tar.gz
    cd qBittorrent-release-${QB_VERSION}
    
    # 配置编译选项
    ./configure --disable-gui \
                --disable-debug \
                --enable-webui \
                --with-boost-libdir=/usr/lib/x86_64-linux-gnu \
                CXXFLAGS="-std=c++17"
    
    make -j$(nproc)
    make install
    
    cd /
    rm -rf /tmp/qBittorrent-release-${QB_VERSION}*
    rm -f /tmp/release-${QB_VERSION}.tar.gz
    
    echo -e "${GREEN}qBittorrent ${QB_VERSION} 安装完成${NC}"
}

# 配置qBittorrent
configure_qbittorrent() {
    echo -e "${CYAN}配置qBittorrent...${NC}"
    
    # 创建配置目录
    su - ${QB_USER} -c "mkdir -p ~/.config/qBittorrent"
    
    # 生成配置文件
    cat > /home/${QB_USER}/.config/qBittorrent/qBittorrent.conf <<EOF
[AutoRun]
enabled=false
program=

[LegalNotice]
Accepted=true

[Network]
Cookies=@Invalid()

[Preferences]
Advanced\AnnounceToAllTrackers=true
Advanced\AnonymousMode=false
Advanced\IgnoreLimitsLAN=true
Advanced\LtTrackerExchange=true
Advanced\RecheckOnCompletion=false
Bittorrent\AddTrackers=false
Bittorrent\MaxConnecs=2000
Bittorrent\MaxConnecsPerTorrent=200
Bittorrent\MaxRatio=-1
Bittorrent\MaxRatioAction=0
Bittorrent\MaxUploads=100
Bittorrent\MaxUploadsPerTorrent=50
Bittorrent\PeX=true
Bittorrent\uTP=true
Bittorrent\uTP_rate_limited=false
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=0
Connection\PortRangeMin=6881
Downloads\PreAllocation=true
Downloads\SavePath=${DOWNLOAD_DIR}/
Downloads\ScanDirsV2=@Variant(\0\0\0\x1c\0\0\0\0)
Downloads\TempPath=${DOWNLOAD_DIR}/temp/
Downloads\TempPathEnabled=true
Downloads\UseIncompleteExtension=true
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
MailNotification\sender=qBittorrent_notification@example.com
MailNotification\smtp_server=smtp.changeme.com
MailNotification\username=
Queueing\QueueingEnabled=false
Scheduler\days=0
Scheduler\end_time=@Variant(\0\0\0\xf\x4J\xa2\0)
Scheduler\start_time=@Variant(\0\0\0\xf\x1\xb7t\0)
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
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=false
WebUI\MaxAuthenticationFailCount=5
WebUI\Port=${QB_PORT}
WebUI\ReverseProxySupportEnabled=false
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\TrustedReverseProxiesList=
WebUI\UseUPnP=false
WebUI\Username=admin
EOF

    # 设置Web UI密码为adminadmin
    QB_PASSWORD_HASH=$(python3 -c "import hashlib; print(hashlib.pbkdf2_hmac('sha512', b'adminadmin', b'$(openssl rand -hex 16)', 100000).hex())")
    echo "WebUI\Password_PBKDF2=\"@ByteArray(${QB_PASSWORD_HASH})\"" >> /home/${QB_USER}/.config/qBittorrent/qBittorrent.conf
    
    chown -R ${QB_USER}:${QB_USER} /home/${QB_USER}/.config
}

# 创建systemd服务
create_service() {
    echo -e "${CYAN}创建systemd服务...${NC}"
    
    cat > /etc/systemd/system/qbittorrent.service <<EOF
[Unit]
Description=qBittorrent-nox service
Documentation=man:qbittorrent-nox(1)
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=simple
User=${QB_USER}
Group=${QB_USER}
UMask=007
ExecStart=/usr/local/bin/qbittorrent-nox
Restart=on-failure
RestartSec=5s
# 内存限制（可选）
# MemoryLimit=4G

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable qbittorrent
    systemctl start qbittorrent
    
    echo -e "${GREEN}qBittorrent服务已启动${NC}"
}

# 优化系统设置
optimize_system() {
    echo -e "${CYAN}优化系统设置...${NC}"
    
    # 增加文件描述符限制
    cat >> /etc/security/limits.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

    # 优化内核参数
    cat >> /etc/sysctl.conf <<EOF
# qBittorrent优化
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
EOF

    sysctl -p
    
    echo -e "${GREEN}系统优化完成${NC}"
}

# 配置防火墙
configure_firewall() {
    echo -e "${CYAN}配置防火墙...${NC}"
    
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=${QB_PORT}/tcp
        firewall-cmd --permanent --add-port=6881-6999/tcp
        firewall-cmd --permanent --add-port=6881-6999/udp
        firewall-cmd --reload
    elif command -v ufw &> /dev/null; then
        ufw allow ${QB_PORT}/tcp
        ufw allow 6881:6999/tcp
        ufw allow 6881:6999/udp
    else
        echo -e "${YELLOW}未检测到防火墙，请手动配置${NC}"
    fi
}

# 显示安装信息
show_info() {
    clear
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}       qBittorrent ${QB_VERSION} 安装完成！${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo
    echo -e "${CYAN}访问地址：${NC}http://你的服务器IP:${QB_PORT}"
    echo -e "${CYAN}默认用户名：${NC}admin"
    echo -e "${CYAN}默认密码：${NC}adminadmin"
    echo -e "${CYAN}下载目录：${NC}${DOWNLOAD_DIR}"
    echo
    echo -e "${YELLOW}服务管理命令：${NC}"
    echo -e "启动服务: systemctl start qbittorrent"
    echo -e "停止服务: systemctl stop qbittorrent"
    echo -e "重启服务: systemctl restart qbittorrent"
    echo -e "查看状态: systemctl status qbittorrent"
    echo -e "查看日志: journalctl -u qbittorrent -f"
    echo
    echo -e "${YELLOW}注意事项：${NC}"
    echo -e "1. 首次登录后请立即修改密码"
    echo -e "2. 建议安装Vertex进行增强管理"
    echo -e "3. 已启用BBR加速和系统优化"
    echo
    echo -e "${GREEN}================================================${NC}"
}

# 主函数
main() {
    echo -e "${CYAN}开始安装qBittorrent ${QB_VERSION}...${NC}"
    
    check_system
    install_dependencies
    create_user
    install_libtorrent
    install_qbittorrent
    configure_qbittorrent
    create_service
    optimize_system
    configure_firewall
    show_info
}

# 执行主函数
main