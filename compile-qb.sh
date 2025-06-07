#!/bin/bash

# qBittorrent 编译安装脚本
# 专门用于从源码编译安装 qBittorrent

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认配置
DEFAULT_QB_VERSION="4.3.9"
DEFAULT_LT_VERSION="1.2.20"
DOWNLOAD_DIR="/opt/downloads"

# 打印消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 显示帮助
show_help() {
    cat << EOF
qBittorrent 编译安装脚本

用法: $0 [选项]

选项:
  -q, --qbittorrent-version    qBittorrent 版本 (默认: $DEFAULT_QB_VERSION)
  -l, --libtorrent-version     libtorrent 版本 (默认: $DEFAULT_LT_VERSION)
  -h, --help                   显示此帮助信息

示例:
  $0                           # 使用默认版本安装
  $0 -q 4.3.8 -l 1.2.20       # 安装指定版本

EOF
}

# 解析参数
QB_VERSION=$DEFAULT_QB_VERSION
LT_VERSION=$DEFAULT_LT_VERSION

while [[ $# -gt 0 ]]; do
    case $1 in
        -q|--qbittorrent-version)
            QB_VERSION="$2"
            shift 2
            ;;
        -l|--libtorrent-version)
            LT_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_message $RED "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    print_message $RED "错误：此脚本必须以root权限运行！"
    exit 1
fi

# 检查系统
check_system() {
    print_message $BLUE "检查系统..."
    
    if [[ ! -f /etc/os-release ]]; then
        print_message $RED "无法识别操作系统！"
        exit 1
    fi
    
    source /etc/os-release
    OS=$NAME
    print_message $GREEN "检测到系统：$OS"
}

# 安装依赖
install_dependencies() {
    print_message $BLUE "安装编译依赖..."
    
    if [[ "$OS" == "Ubuntu" ]] || [[ "$OS" == "Debian"* ]]; then
        apt-get update
        apt-get install -y \
            build-essential pkg-config automake libtool git \
            zlib1g-dev libssl-dev libgeoip-dev \
            libboost-dev libboost-system-dev libboost-chrono-dev libboost-random-dev \
            qtbase5-dev qttools5-dev-tools libqt5svg5-dev \
            python3 python3-dev
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "Red Hat"* ]]; then
        yum groupinstall -y "Development Tools"
        yum install -y \
            git zlib-devel openssl-devel geoip-devel \
            boost-devel boost-system boost-chrono boost-random \
            qt5-qtbase-devel qt5-qttools-devel qt5-qtsvg-devel \
            python3 python3-devel
    fi
    
    print_message $GREEN "依赖安装完成！"
}

# 编译libtorrent
compile_libtorrent() {
    print_message $BLUE "编译 libtorrent-rasterbar ${LT_VERSION}..."
    
    cd /tmp
    rm -rf libtorrent-rasterbar-${LT_VERSION}*
    
    # 下载源码
    print_message $YELLOW "下载 libtorrent 源码..."
    wget https://github.com/arvidn/libtorrent/releases/download/v${LT_VERSION}/libtorrent-rasterbar-${LT_VERSION}.tar.gz
    
    if [[ ! -f libtorrent-rasterbar-${LT_VERSION}.tar.gz ]]; then
        print_message $RED "下载失败！"
        exit 1
    fi
    
    tar -xf libtorrent-rasterbar-${LT_VERSION}.tar.gz
    cd libtorrent-rasterbar-${LT_VERSION}
    
    # 配置
    print_message $YELLOW "配置编译选项..."
    ./configure \
        --disable-debug \
        --enable-encryption \
        --with-boost-libdir=/usr/lib/x86_64-linux-gnu \
        --with-libiconv \
        CXXFLAGS="-O3 -march=native -pipe -fPIC" \
        LDFLAGS="-Wl,-O1 -Wl,--as-needed"
    
    # 编译
    print_message $YELLOW "编译中（可能需要10-20分钟）..."
    make -j$(nproc)
    
    # 安装
    print_message $YELLOW "安装 libtorrent..."
    make install
    ldconfig
    
    cd /
    rm -rf /tmp/libtorrent-rasterbar-${LT_VERSION}*
    
    print_message $GREEN "libtorrent ${LT_VERSION} 编译完成！"
}

# 编译qBittorrent
compile_qbittorrent() {
    print_message $BLUE "编译 qBittorrent ${QB_VERSION}..."
    
    cd /tmp
    rm -rf qBittorrent-release-${QB_VERSION}*
    
    # 下载源码
    print_message $YELLOW "下载 qBittorrent 源码..."
    wget https://github.com/qbittorrent/qBittorrent/archive/release-${QB_VERSION}.tar.gz
    
    if [[ ! -f release-${QB_VERSION}.tar.gz ]]; then
        print_message $RED "下载失败！"
        exit 1
    fi
    
    tar -xf release-${QB_VERSION}.tar.gz
    cd qBittorrent-release-${QB_VERSION}
    
    # 配置
    print_message $YELLOW "配置编译选项..."
    ./configure \
        --disable-gui \
        --disable-debug \
        CXXFLAGS="-O3 -march=native -pipe" \
        LDFLAGS="-Wl,-O1 -Wl,--as-needed"
    
    # 编译
    print_message $YELLOW "编译中（可能需要5-10分钟）..."
    make -j$(nproc)
    
    # 安装
    print_message $YELLOW "安装 qBittorrent..."
    make install
    
    cd /
    rm -rf /tmp/release-${QB_VERSION}.tar.gz /tmp/qBittorrent-release-${QB_VERSION}
    
    print_message $GREEN "qBittorrent ${QB_VERSION} 编译完成！"
}

# 配置qBittorrent
configure_qbittorrent() {
    print_message $BLUE "配置 qBittorrent..."
    
    # 创建配置目录
    mkdir -p /root/.config/qBittorrent
    mkdir -p $DOWNLOAD_DIR
    
    # 创建基本配置
    cat > /root/.config/qBittorrent/qBittorrent.conf << EOF
[Preferences]
WebUI\Port=8080
WebUI\Username=admin
WebUI\Password_PBKDF2="@ByteArray(rDeaCtG9hVzqKpMKaLRNwg==:pQ5vr2q0J7S0IHlv88xJJh08gvjKoBCA0zRN4C8bTXGGbFe8ERlWNRra3xNhBX3x0yaSYvDONK1mlCddGndVIg==)"
WebUI\LocalHostAuth=false
WebUI\Address=*
Downloads\SavePath=$DOWNLOAD_DIR/
Downloads\TempPath=$DOWNLOAD_DIR/temp/
Connection\PortRangeMin=25000
BitTorrent\Session\Port=25000
EOF
    
    # 创建systemd服务
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

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable qbittorrent
    
    print_message $GREEN "配置完成！"
}

# 启动服务
start_service() {
    print_message $BLUE "启动 qBittorrent 服务..."
    
    systemctl start qbittorrent
    sleep 3
    
    if systemctl is-active --quiet qbittorrent; then
        print_message $GREEN "服务启动成功！"
        
        # 获取IP
        local ip=$(curl -s -4 icanhazip.com || curl -s -4 ifconfig.me || hostname -I | awk '{print $1}')
        
        echo
        print_message $GREEN "╔═══════════════════════════════════════════════════════════════╗"
        print_message $GREEN "║               qBittorrent 安装成功！                          ║"
        print_message $GREEN "╚═══════════════════════════════════════════════════════════════╝"
        echo
        print_message $CYAN "访问地址：http://${ip}:8080"
        print_message $CYAN "用户名：admin"
        print_message $CYAN "密码：adminadmin"
        print_message $CYAN "下载目录：$DOWNLOAD_DIR"
        echo
    else
        print_message $RED "服务启动失败！"
        print_message $YELLOW "查看日志："
        journalctl -u qbittorrent -n 20 --no-pager
    fi
}

# 主函数
main() {
    clear
    print_message $CYAN "╔═══════════════════════════════════════════════════════════════╗"
    print_message $CYAN "║          qBittorrent ${QB_VERSION} + libtorrent ${LT_VERSION} 编译安装          ║"
    print_message $CYAN "╚═══════════════════════════════════════════════════════════════╝"
    echo
    
    # 确认安装
    print_message $YELLOW "即将编译安装："
    print_message $YELLOW "• qBittorrent ${QB_VERSION}"
    print_message $YELLOW "• libtorrent ${LT_VERSION}"
    echo
    echo -n "继续安装？[Y/n]: "
    read -r confirm
    
    if [[ $confirm == "n" || $confirm == "N" ]]; then
        print_message $YELLOW "取消安装"
        exit 0
    fi
    
    # 执行安装步骤
    check_system
    install_dependencies
    compile_libtorrent
    compile_qbittorrent
    configure_qbittorrent
    start_service
}

# 运行主函数
main
