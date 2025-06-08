#!/bin/bash

# qBittorrent 4.3.8 安装脚本
# 修改自: https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh
# 适配PTtools项目

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

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

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
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

# 安装依赖包
install_dependencies() {
    log_info "安装依赖包..."
    
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

# 编译安装libtorrent-rasterbar
install_libtorrent() {
    log_info "编译安装libtorrent-rasterbar 1.2.19..."
    
    cd /tmp
    
    # 下载libtorrent源码
    if [ ! -f "libtorrent-rasterbar-1.2.19.tar.gz" ]; then
        wget https://github.com/arvidn/libtorrent/releases/download/v1.2.19/libtorrent-rasterbar-1.2.19.tar.gz
    fi
    
    tar xf libtorrent-rasterbar-1.2.19.tar.gz
    cd libtorrent-rasterbar-1.2.19
    
    # 配置编译选项
    ./configure \
        --enable-encryption \
        --disable-debug \
        --enable-optimizations \
        --with-libgeoip=system
    
    # 编译并安装
    make -j$(nproc)
    make install
    
    # 更新库链接
    if [ "$OS" = "debian" ]; then
        ldconfig
    elif [ "$OS" = "centos" ]; then
        echo "/usr/local/lib" > /etc/ld.so.conf.d/libtorrent.conf
        ldconfig
    fi
    
    log_info "libtorrent-rasterbar安装完成"
}

# 编译安装qBittorrent
install_qbittorrent() {
    log_info "编译安装qBittorrent 4.3.8..."
    
    cd /tmp
    
    # 下载qBittorrent源码
    if [ ! -f "qbittorrent-4.3.8.tar.gz" ]; then
        wget https://github.com/qbittorrent/qBittorrent/archive/release-4.3.8.tar.gz -O qbittorrent-4.3.8.tar.gz
    fi
    
    tar xf qbittorrent-4.3.8.tar.gz
    cd qBittorrent-release-4.3.8
    
    # 配置编译选项
    ./configure \
        --disable-gui \
        --enable-systemd \
        --with-boost-libdir=/usr/lib/x86_64-linux-gnu
    
    # 编译并安装
    make -j$(nproc)
    make install
    
    log_info "qBittorrent编译安装完成"
}

# 创建qbittorrent用户
create_user() {
    log_info "创建qbittorrent用户..."
    
    # 创建系统用户
    useradd --system --shell /usr/sbin/nologin --home-dir /var/lib/qbittorrent --create-home qbittorrent
    
    # 创建必要目录
    mkdir -p /home/qbittorrent/{Downloads,torrents,watch}
    mkdir -p /home/qbittorrent/.config/qBittorrent
    mkdir -p /home/qbittorrent/.local/share/data/qBittorrent
    
    # 创建统一下载目录
    mkdir -p /opt/downloads/{complete,incomplete,watch}
    
    # 设置目录权限
    chown -R qbittorrent:qbittorrent /home/qbittorrent
    chown -R qbittorrent:qbittorrent /var/lib/qbittorrent
    chown -R qbittorrent:qbittorrent /opt/downloads
    
    log_info "用户创建完成"
}

# 配置qBittorrent
configure_qbittorrent() {
    log_info "配置qBittorrent..."
    
    # 创建配置文件 - 使用更完整的配置
    cat > /home/qbittorrent/.config/qBittorrent/qBittorrent.conf << 'EOF'
[Application]
FileLogger\Enabled=true
FileLogger\Age=1
FileLogger\MaxSizeBytes=66560
FileLogger\Path=/home/qbittorrent/.local/share/data/qBittorrent

[BitTorrent]
Session\DefaultSavePath=/opt/downloads
Session\Port=8999
Session\TempPath=/opt/downloads/incomplete
Session\TempPathEnabled=true
Session\AddExtensionToIncompleteFiles=true
Session\Preallocation=true

[Preferences]
WebUI\Port=8080
WebUI\Username=admin
WebUI\Password_PBKDF2="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)"
WebUI\LocalHostAuth=false
Downloads\SavePath=/opt/downloads
Downloads\TempPath=/opt/downloads/incomplete
Downloads\TempPathEnabled=true
Downloads\UseIncompleteExtension=true
Downloads\ScanDirs\1\enabled=true
Downloads\ScanDirs\1\path=/opt/downloads/watch
Downloads\ScanDirs\size=1
Downloads\PreallocateAll=true
Connection\PortRangeMin=8999
Connection\PortRangeMax=8999
General\DefaultSavePath=/opt/downloads
General\TempPath=/opt/downloads/incomplete
General\TempPathEnabled=true

[Core]
AutoDeleteAddedTorrentFile=Never

[Meta]
MigrationVersion=4

[Network]
Cookies=@Invalid()
Proxy\OnlyForTorrents=false

[RSS]
AutoDownloader\DownloadRepacks=true
AutoDownloader\SmartEpisodeFilter=s(\\d+)e(\\d+), (\\d+)x(\\d+), "(\\d{4}[.\\-]\\d{1,2}[.\\-]\\d{1,2})", "(\\d{1,2}[.\\-]\\d{1,2}[.\\-]\\d{4})"

[MailNotification]
enabled=false

[AutoRun]
OnTorrentAdded\Enabled=false
OnTorrentFinished\Enabled=false
EOF

    # 设置配置文件权限
    chown -R qbittorrent:qbittorrent /home/qbittorrent/.config
    chmod 600 /home/qbittorrent/.config/qBittorrent/qBittorrent.conf
    
    log_info "配置文件创建完成"
    log_warn "默认登录信息: 用户名=admin, 密码=adminadmin"
}

# 创建systemd服务
create_service() {
    log_info "创建systemd服务..."
    
    cat > /etc/systemd/system/qbittorrent.service << EOF
[Unit]
Description=qBittorrent Command Line Client
After=network.target

[Service]
Type=forking
User=qbittorrent
Group=qbittorrent
UMask=007
ExecStart=/usr/local/bin/qbittorrent-nox -d --webui-port=8080
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd并启用服务
    systemctl daemon-reload
    systemctl enable qbittorrent
    
    log_info "systemd服务创建完成"
}

# 启动qBittorrent服务
start_service() {
    log_info "启动qBittorrent服务..."
    
    # 确保配置文件存在且路径正确
    if [ -f "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf" ]; then
        log_info "验证配置文件中的下载路径..."
        if grep -q "/opt/downloads" "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf"; then
            log_info "下载路径配置正确: /opt/downloads"
        else
            log_warn "配置文件中未找到正确的下载路径，重新配置..."
            configure_qbittorrent
        fi
    else
        log_error "配置文件不存在，重新创建..."
        configure_qbittorrent
    fi
    
    systemctl start qbittorrent
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if systemctl is-active --quiet qbittorrent; then
        log_info "qBittorrent服务启动成功"
        
        # 额外验证：检查WebUI是否可访问
        sleep 2
        if curl -s -f http://localhost:8080 > /dev/null; then
            log_info "qBittorrent WebUI已就绪"
        else
            log_warn "WebUI可能需要几秒钟才能完全启动"
        fi
    else
        log_error "qBittorrent服务启动失败"
        log_error "检查服务状态："
        systemctl status qbittorrent --no-pager
        log_error "检查日志："
        journalctl -u qbittorrent --no-pager -n 20
        exit 1
    fi
}

# 防火墙配置
configure_firewall() {
    log_info "配置防火墙..."
    
    # 检查并配置iptables/firewalld
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
    
    log_info "防火墙配置完成"
}

# 显示安装完成信息
show_installation_result() {
    clear
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ip.sb 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
    
    # 获取qBittorrent端口
    QB_PORT=$(grep "Session\\\\Port=" "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf" | cut -d'=' -f2 2>/dev/null || echo "8999")
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              qBittorrent 4.3.8 安装完成                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}📋 安装信息:${NC}"
    echo -e "   qBittorrent版本: ${WHITE}4.3.8${NC}"
    echo -e "   libtorrent版本:  ${WHITE}1.2.19${NC}"
    echo -e "   安装目录:        ${WHITE}/home/qbittorrent${NC}"
    echo -e "   运行用户:        ${WHITE}qbittorrent${NC}"
    echo
    echo -e "${CYAN}🌐 访问信息:${NC}"
    echo -e "   WebUI地址:       ${WHITE}http://$SERVER_IP:8080${NC}"
    echo -e "   用户名:          ${WHITE}admin${NC}"
    echo -e "   密码:            ${WHITE}adminadmin${NC}"
    echo -e "   BT端口:          ${WHITE}$QB_PORT${NC}"
    echo
    echo -e "${CYAN}📁 目录信息:${NC}"
    echo -e "   下载目录:        ${WHITE}/opt/downloads${NC}"
    echo -e "   完成目录:        ${WHITE}/opt/downloads/complete${NC}"
    echo -e "   未完成目录:      ${WHITE}/opt/downloads/incomplete${NC}"
    echo -e "   监控目录:        ${WHITE}/opt/downloads/watch${NC}"
    echo -e "   配置目录:        ${WHITE}/home/qbittorrent/.config/qBittorrent${NC}"
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
    echo -e "   4. 建议重启系统以确保所有优化生效"
    echo
}

# 主函数
main() {
    log_info "开始安装qBittorrent 4.3.8..."
    
    check_root
    check_system
    install_dependencies
    install_libtorrent
    install_qbittorrent
    create_user
    configure_qbittorrent
    create_service
    start_service
    configure_firewall
    
    # 最终验证下载路径
    log_info "验证默认下载路径设置..."
    if [ -f "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf" ]; then
        SAVE_PATH=$(grep "Downloads\\\\SavePath=" "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf" | cut -d'=' -f2)
        if [ "$SAVE_PATH" = "/opt/downloads" ]; then
            log_info "✓ 默认下载路径已正确设置为: /opt/downloads"
        else
            log_warn "⚠ 下载路径可能需要在WebUI中手动确认"
        fi
    fi
    
    show_installation_result
    
    log_info "安装完成！"
}

# 执行主函数
main "$@"
