#!/bin/bash

# qBittorrent 4.3.8 安装脚本
# 整合自: https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh
# PTtools项目: https://github.com/everett7623/PTtools

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 基础配置
QB_VERSION="4.3.8"
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

# 检查系统类型
check_system() {
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
        PACKAGE_MANAGER="yum"
    elif cat /etc/issue | grep -q -E -i "debian|ubuntu"; then
        OS="debian"
        PACKAGE_MANAGER="apt-get"
    else
        echo -e "${RED}不支持的系统类型！${NC}"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${CYAN}正在安装依赖包...${NC}"
    
    if [[ "$OS" == "debian" ]]; then
        apt-get update
        apt-get install -y build-essential pkg-config automake libtool git perl python3 python3-dev \
            libboost-all-dev libssl-dev libgeoip-dev qtbase5-dev qttools5-dev-tools libqt5svg5-dev \
            zlib1g-dev libpcre3-dev libxslt-dev libxml2-dev libarchive-dev libgcrypt20-dev \
            libgpg-error-dev libgnutls28-dev ca-certificates curl wget unzip nano
    elif [[ "$OS" == "centos" ]]; then
        yum groupinstall -y "Development Tools"
        yum install -y epel-release
        yum install -y git perl python3 python3-devel boost-devel openssl-devel geoip-devel \
            qt5-qtbase-devel qt5-linguist zlib-devel pcre-devel libxslt-devel libxml2-devel \
            libarchive-devel libgcrypt-devel gpgme-devel gnutls-devel ca-certificates curl wget unzip nano
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
    wget https://github.com/arvidn/libtorrent/releases/download/v${LIBTORRENT_VERSION}/libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz
    tar -zxvf libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz
    cd libtorrent-rasterbar-${LIBTORRENT_VERSION}
    
    ./configure --disable-debug --enable-encryption --with-boost-libdir=/usr/lib/x86_64-linux-gnu
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
    wget https://github.com/qbittorrent/qBittorrent/archive/release-${QB_VERSION}.tar.gz
    tar -zxvf release-${QB_VERSION}.tar.gz
    cd qBittorrent-release-${QB_VERSION}
    
    ./configure --disable-gui --disable-debug
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

[Preferences]
Bittorrent\CustomizeTrackersListUrl=
Bittorrent\MaxRatio=-1
Bittorrent\MaxRatioAction=0
Bittorrent\MaxConnecs=-1
Bittorrent\MaxConnecsPerTorrent=-1
Bittorrent\MaxUploads=-1
Bittorrent\MaxUploadsPerTorrent=-1
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=0
Connection\PortRangeMin=6881
Downloads\SavePath=${DOWNLOAD_DIR}/
Downloads\TempPath=${DOWNLOAD_DIR}/temp/
General\Locale=zh_CN
WebUI\Address=*
WebUI\AlternativeUIEnabled=false
WebUI\AuthSubnetWhitelist=
WebUI\AuthSubnetWhitelistEnabled=false
WebUI\HTTPS\Enabled=false
WebUI\LocalHostAuth=false
WebUI\Port=${QB_PORT}
WebUI\UseUPnP=false
WebUI\Username=admin
EOF

    # 设置Web UI密码为adminadmin
    # 密码使用PBKDF2加密
    SALT=$(openssl rand -hex 16)
    HASH=$(echo -n "adminadmin${SALT}" | openssl dgst -sha512 -binary | base64)
    echo "WebUI\Password_PBKDF2=\"@ByteArray(${HASH}:${SALT})\"" >> /home/${QB_USER}/.config/qBittorrent/qBittorrent.conf
    
    chown -R ${QB_USER}:${QB_USER} /home/${QB_USER}/.config
}

# 创建systemd服务
create_service() {
    echo -e "${CYAN}创建systemd服务...${NC}"
    
    cat > /etc/systemd/system/qbittorrent.service <<EOF
[Unit]
Description=qBittorrent Daemon Service
After=network.target

[Service]
Type=simple
User=${QB_USER}
Group=${QB_USER}
UMask=007
ExecStart=/usr/local/bin/qbittorrent-nox
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable qbittorrent
    systemctl start qbittorrent
    
    echo -e "${GREEN}qBittorrent服务已启动${NC}"
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
    echo -e "${YELLOW}注意事项：${NC}"
    echo -e "1. 首次登录后请立即修改密码"
    echo -e "2. 建议启用HTTPS以提高安全性"
    echo -e "3. 可以通过 systemctl status qbittorrent 查看服务状态"
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
    configure_firewall
    show_info
}

# 执行主函数
main