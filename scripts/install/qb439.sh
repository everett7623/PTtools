#!/bin/bash

# qBittorrent 4.3.9 安装脚本
# 修改自Jerry的脚本: https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh
# 适配PTtools项目

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 全局变量
QB_VERSION="4.3.9"
LIBTORRENT_VERSION="1.2.19"
INSTALL_DIR="/home/qbittorrent"
SERVICE_USER="qbittorrent"

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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检测系统信息
detect_system() {
    log_info "检测系统信息..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        log_error "无法检测系统信息"
        exit 1
    fi
    
    # 检测架构
    ARCH=$(uname -m)
    
    log_info "系统: $OS $VERSION"
    log_info "架构: $ARCH"
    
    # 验证支持的系统
    case $DISTRO in
        ubuntu|debian)
            PACKAGE_MANAGER="apt"
            ;;
        centos|rhel|fedora)
            PACKAGE_MANAGER="yum"
            if command -v dnf &> /dev/null; then
                PACKAGE_MANAGER="dnf"
            fi
            ;;
        *)
            log_error "不支持的系统: $DISTRO"
            exit 1
            ;;
    esac
}

# 安装系统依赖
install_system_dependencies() {
    log_info "安装系统依赖包..."
    
    case $PACKAGE_MANAGER in
        apt)
            apt-get update
            apt-get install -y \
                build-essential \
                cmake \
                git \
                pkg-config \
                automake \
                libtool \
                lsb-release \
                curl \
                wget \
                software-properties-common \
                apt-transport-https \
                ca-certificates \
                gnupg \
                libboost-dev \
                libboost-chrono-dev \
                libboost-random-dev \
                libboost-system-dev \
                libssl-dev \
                qtbase5-dev \
                qttools5-dev-tools \
                libqt5svg5-dev \
                zlib1g-dev \
                python3-dev \
                python3-setuptools
            ;;
        yum|dnf)
            $PACKAGE_MANAGER groupinstall -y "Development Tools"
            $PACKAGE_MANAGER install -y \
                cmake \
                git \
                pkgconfig \
                automake \
                libtool \
                curl \
                wget \
                boost-devel \
                openssl-devel \
                qt5-qtbase-devel \
                qt5-qttools-devel \
                qt5-qtsvg-devel \
                zlib-devel \
                python3-devel \
                python3-setuptools
            ;;
    esac
}

# 编译安装libtorrent-rasterbar
compile_libtorrent() {
    log_info "编译安装libtorrent-rasterbar $LIBTORRENT_VERSION..."
    
    cd /tmp
    
    # 清理之前的源码
    rm -rf libtorrent-rasterbar-*
    
    # 下载源码
    wget -O libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz \
        "https://github.com/arvidn/libtorrent/releases/download/v${LIBTORRENT_VERSION}/libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz"
    
    if [ $? -ne 0 ]; then
        log_error "下载libtorrent源码失败"
        exit 1
    fi
    
    tar -xzf libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz
    cd libtorrent-rasterbar-${LIBTORRENT_VERSION}
    
    # 配置编译选项
    log_info "配置libtorrent编译选项..."
    
    ./configure \
        --prefix=/usr/local \
        --enable-encryption \
        --disable-debug \
        --enable-optimizations \
        --with-boost-system=mt \
        --with-boost-chrono=mt \
        --with-boost-random=mt
    
    if [ $? -ne 0 ]; then
        log_error "libtorrent配置失败"
        exit 1
    fi
    
    # 编译
    log_info "编译libtorrent (这可能需要一些时间)..."
    make -j$(nproc)
    
    if [ $? -ne 0 ]; then
        log_error "libtorrent编译失败"
        exit 1
    fi
    
    # 安装
    make install
    
    # 更新动态链接库
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        ldconfig
    else
        echo "/usr/local/lib" > /etc/ld.so.conf.d/libtorrent.conf
        ldconfig
    fi
    
    log_info "libtorrent安装完成"
}

# 编译安装qBittorrent
compile_qbittorrent() {
    log_info "编译安装qBittorrent $QB_VERSION..."
    
    cd /tmp
    
    # 清理之前的源码
    rm -rf qBittorrent-*
    
    # 下载源码
    wget -O qbittorrent-${QB_VERSION}.tar.gz \
        "https://github.com/qbittorrent/qBittorrent/archive/release-${QB_VERSION}.tar.gz"
    
    if [ $? -ne 0 ]; then
        log_error "下载qBittorrent源码失败"
        exit 1
    fi
    
    tar -xzf qbittorrent-${QB_VERSION}.tar.gz
    cd qBittorrent-release-${QB_VERSION}
    
    # 配置编译选项
    log_info "配置qBittorrent编译选项..."
    
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH" \
    ./configure \
        --prefix=/usr/local \
        --disable-gui \
        --enable-systemd
    
    if [ $? -ne 0 ]; then
        log_error "qBittorrent配置失败"
        exit 1
    fi
    
    # 编译
    log_info "编译qBittorrent (这可能需要一些时间)..."
    make -j$(nproc)
    
    if [ $? -ne 0 ]; then
        log_error "qBittorrent编译失败"
        exit 1
    fi
    
    # 安装
    make install
    
    log_info "qBittorrent安装完成"
}

# 创建qbittorrent用户和目录
setup_user_and_directories() {
    log_info "设置用户和目录..."
    
    # 创建系统用户
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd --system --shell /usr/sbin/nologin --home-dir "$INSTALL_DIR" --create-home "$SERVICE_USER"
        log_info "创建用户: $SERVICE_USER"
    else
        log_info "用户已存在: $SERVICE_USER"
    fi
    
    # 创建必要目录
    mkdir -p "$INSTALL_DIR"/{Downloads,watch,torrents}
    mkdir -p "$INSTALL_DIR"/.config/qBittorrent
    mkdir -p "$INSTALL_DIR"/.local/share/data/qBittorrent
    
    # 创建下载子目录
    mkdir -p "$INSTALL_DIR"/Downloads/{Movies,TV,Music,Software,Books,complete,incomplete}
    
    # 设置权限
    chown -R "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
    
    log_info "目录结构创建完成"
}

# 生成qBittorrent配置文件
generate_config() {
    log_info "生成qBittorrent配置文件..."
    
    # 生成随机端口 (范围: 10000-65000)
    RANDOM_PORT=$((RANDOM % 55000 + 10000))
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ip.sb || curl -s ipinfo.io/ip || echo "0.0.0.0")
    
    cat > "$INSTALL_DIR/.config/qBittorrent/qBittorrent.conf" << EOF
[Application]
FileLogger\\Enabled=true
FileLogger\\Age=1
FileLogger\\MaxSizeBytes=66560
FileLogger\\Path=$INSTALL_DIR/.local/share/data/qBittorrent

[BitTorrent]
Session\\DefaultSavePath=$INSTALL_DIR/Downloads
Session\\Port=$RANDOM_PORT
Session\\TempPath=$INSTALL_DIR/Downloads/incomplete
Session\\TempPathEnabled=true
Session\\AddExtensionToIncompleteFiles=true
Session\\Preallocation=true
Session\\UseAlternativeGlobalSpeedLimit=false
Session\\GlobalMaxRatio=0
Session\\GlobalMaxSeedingMinutes=-1
Session\\MaxConnections=500
Session\\MaxConnectionsPerTorrent=100
Session\\MaxUploads=20
Session\\MaxUploadsPerTorrent=4
Session\\GlobalDLSpeedLimit=0
Session\\GlobalUPSpeedLimit=0

[Preferences]
WebUI\\Port=8080
WebUI\\Username=admin
WebUI\\Password_PBKDF2="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)"
WebUI\\LocalHostAuth=false
WebUI\\AuthSubnetWhitelistEnabled=false
WebUI\\CSRFProtection=false
WebUI\\ClickjackingProtection=false
Downloads\\SavePath=$INSTALL_DIR/Downloads
Downloads\\TempPath=$INSTALL_DIR/Downloads/incomplete
Downloads\\ScanDirs\\1\\enabled=true
Downloads\\ScanDirs\\1\\path=$INSTALL_DIR/watch
Downloads\\ScanDirs\\size=1
Downloads\\PreallocateAll=true
Downloads\\UseIncompleteExtension=true
Connection\\PortRangeMin=$RANDOM_PORT
Connection\\PortRangeMax=$RANDOM_PORT
Connection\\UPnP=false
Connection\\GlobalDLLimitAlt=0
Connection\\GlobalUPLimitAlt=0
Bittorrent\\DHT=true
Bittorrent\\PeX=true
Bittorrent\\LSD=true
Bittorrent\\Encryption=1
Queueing\\MaxActiveDownloads=5
Queueing\\MaxActiveTorrents=10
Queueing\\MaxActiveUploads=5
EOF

    # 设置配置文件权限
    chown -R "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_DIR/.config"
    chmod 600 "$INSTALL_DIR/.config/qBittorrent/qBittorrent.conf"
    
    log_info "配置文件生成完成 (端口: $RANDOM_PORT)"
}

# 创建systemd服务文件
create_systemd_service() {
    log_info "创建systemd服务文件..."
    
    cat > /etc/systemd/system/qbittorrent.service << EOF
[Unit]
Description=qBittorrent-nox service
Documentation=man:qbittorrent-nox(1)
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=exec
User=$SERVICE_USER
Group=$SERVICE_USER
UMask=0002
ExecStart=/usr/local/bin/qbittorrent-nox --webui-port=8080
ExecStop=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
KillMode=mixed

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=false
ReadWritePaths=$INSTALL_DIR
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd配置
    systemctl daemon-reload
    
    log_info "systemd服务文件创建完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."
    
    # 获取qBittorrent端口
    QB_PORT=$(grep "Session\\\\Port=" "$INSTALL_DIR/.config/qBittorrent/qBittorrent.conf" | cut -d'=' -f2)
    
    # UFW (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        ufw allow 8080/tcp comment "qBittorrent WebUI"
        ufw allow ${QB_PORT}/tcp comment "qBittorrent"
        ufw allow ${QB_PORT}/udp comment "qBittorrent"
    fi
    
    # firewalld (CentOS/RHEL/Fedora)
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=${QB_PORT}/tcp
        firewall-cmd --permanent --add-port=${QB_PORT}/udp
        firewall-cmd --reload
    fi
    
    log_info "防火墙配置完成"
}

# 启动并启用服务
start_service() {
    log_info "启动qBittorrent服务..."
    
    # 启用服务
    systemctl enable qbittorrent
    
    # 启动服务
    systemctl start qbittorrent
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if systemctl is-active --quiet qbittorrent; then
        log_info "qBittorrent服务启动成功"
    else
        log_error "qBittorrent服务启动失败"
        log_error "查看服务状态: systemctl status qbittorrent"
        log_error "查看服务日志: journalctl -u qbittorrent -f"
        exit 1
    fi
}

# 优化系统设置
optimize_system() {
    log_info "优化系统设置..."
    
    # 增加文件描述符限制
    cat >> /etc/security/limits.conf << EOF
$SERVICE_USER soft nofile 51200
$SERVICE_USER hard nofile 51200
EOF

    # 添加到 systemd 服务文件中
    mkdir -p /etc/systemd/system/qbittorrent.service.d
    cat > /etc/systemd/system/qbittorrent.service.d/override.conf << EOF
[Service]
LimitNOFILE=51200
EOF

    # 网络优化
    cat >> /etc/sysctl.conf << EOF
# qBittorrent 网络优化
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
EOF

    sysctl -p
    
    log_info "系统优化完成"
}

# 显示安装结果
show_installation_result() {
    clear
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ip.sb || curl -s ipinfo.io/ip || echo "localhost")
    
    # 获取qBittorrent端口
    QB_PORT=$(grep "Session\\\\Port=" "$INSTALL_DIR/.config/qBittorrent/qBittorrent.conf" | cut -d'=' -f2)
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              qBittorrent $QB_VERSION 安装完成                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}📋 安装信息:${NC}"
    echo -e "   qBittorrent版本: ${WHITE}$QB_VERSION${NC}"
    echo -e "   libtorrent版本:  ${WHITE}$LIBTORRENT_VERSION${NC}"
    echo -e "   安装目录:        ${WHITE}$INSTALL_DIR${NC}"
    echo -e "   运行用户:        ${WHITE}$SERVICE_USER${NC}"
    echo
    echo -e "${CYAN}🌐 访问信息:${NC}"
    echo -e "   WebUI地址:       ${WHITE}http://$SERVER_IP:8080${NC}"
    echo -e "   用户名:          ${WHITE}admin${NC}"
    echo -e "   密码:            ${WHITE}adminadmin${NC}"
    echo -e "   BT端口:          ${WHITE}$QB_PORT${NC}"
    echo
    echo -e "${CYAN}📁 目录信息:${NC}"
    echo -e "   下载目录:        ${WHITE}$INSTALL_DIR/Downloads${NC}"
    echo -e "   监控目录:        ${WHITE}$INSTALL_DIR/watch${NC}"
    echo -e "   配置目录:        ${WHITE}$INSTALL_DIR/.config/qBittorrent${NC}"
    echo
    echo -e "${CYAN}🔧 服务管理:${NC}"
    echo -e "   启动服务:        ${WHITE}systemctl start qbittorrent${NC}"
    echo -e "   停止服务:        ${WHITE}systemctl stop qbittorrent${NC}"
    echo -e "   重启服务:        ${WHITE}systemctl restart qbittorrent${NC}"
    echo -e "   查看状态:        ${WHITE}systemctl status qbittorrent${NC}"
    echo -e "   查看日志:        ${WHITE}journalctl -u qbittorrent -f${NC}"
    echo
    echo -e "${YELLOW}⚠️  重要提醒:${NC}"
    echo -e "   1. 首次登录后请及时修改默认密码"
    echo -e "   2. 建议在WebUI中进行进一步的个性化配置"
    echo -e "   3. 防火墙已自动配置，如有问题请检查防火墙设置"
    echo
}

# 主安装函数
main() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            qBittorrent $QB_VERSION 自动安装脚本                  ║${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}║  此脚本将编译安装最新版本的 qBittorrent 和 libtorrent       ║${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}║  适配 PTtools 项目 - github.com/everett7623/PTtools         ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    read -p "按回车键开始安装，或按 Ctrl+C 取消..."
    
    log_info "开始安装 qBittorrent $QB_VERSION..."
    
    # 执行安装步骤
    check_root
    detect_system
    install_system_dependencies
    compile_libtorrent
    compile_qbittorrent
    setup_user_and_directories
    generate_config
    create_systemd_service
    configure_firewall
    optimize_system
    start_service
    
    # 显示安装结果
    show_installation_result
    
    log_info "安装完成！"
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
