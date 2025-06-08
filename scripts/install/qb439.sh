#!/bin/bash

# qBittorrent 4.3.9 安装脚本
# 修改自Jerry的脚本: https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh
# 适配PTtools项目

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 全局变量
QB_VERSION="4.3.9"
LIBTORRENT_VERSION="1.2.19"

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
            python3 \
            python3-dev \
            python3-setuptools \
            curl \
            wget
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
            python3 \
            python3-devel \
            python3-setuptools \
            curl \
            wget
    fi
}

# 编译安装libtorrent-rasterbar
install_libtorrent() {
    log_info "编译安装libtorrent-rasterbar $LIBTORRENT_VERSION..."
    
    cd /tmp
    
    # 清理之前的源码
    rm -rf libtorrent-rasterbar-*
    
    # 下载libtorrent源码
    if [ ! -f "libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz" ]; then
        wget https://github.com/arvidn/libtorrent/releases/download/v${LIBTORRENT_VERSION}/libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz
    fi
    
    tar xf libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz
    cd libtorrent-rasterbar-${LIBTORRENT_VERSION}
    
    # 配置编译选项
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
    
    # 编译并安装
    log_info "编译libtorrent (这可能需要一些时间)..."
    make -j$(nproc)
    
    if [ $? -ne 0 ]; then
        log_error "libtorrent编译失败"
        exit 1
    fi
    
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
    log_info "编译安装qBittorrent $QB_VERSION..."
    
    cd /tmp
    
    # 清理之前的源码
    rm -rf qBittorrent-*
    
    # 下载qBittorrent源码
    if [ ! -f "qbittorrent-${QB_VERSION}.tar.gz" ]; then
        wget https://github.com/qbittorrent/qBittorrent/archive/release-${QB_VERSION}.tar.gz -O qbittorrent-${QB_VERSION}.tar.gz
    fi
    
    tar xf qbittorrent-${QB_VERSION}.tar.gz
    cd qBittorrent-release-${QB_VERSION}
    
    # 配置编译选项
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH" \
    ./configure \
        --prefix=/usr/local \
        --disable-gui \
        --enable-systemd
    
    if [ $? -ne 0 ]; then
        log_error "qBittorrent配置失败"
        exit 1
    fi
    
    # 编译并安装
    log_info "编译qBittorrent (这可能需要一些时间)..."
    make -j$(nproc)
    
    if [ $? -ne 0 ]; then
        log_error "qBittorrent编译失败"
        exit 1
    fi
    
    make install
    
    log_info "qBittorrent编译安装完成"
}

# 创建qbittorrent用户
create_user() {
    log_info "创建qbittorrent用户..."
    
    # 删除可能存在的旧用户和目录
    userdel -r qbittorrent 2>/dev/null || true
    rm -rf /home/qbittorrent 2>/dev/null || true
    rm -rf /var/lib/qbittorrent 2>/dev/null || true
    
    # 创建系统用户，明确指定home目录为/home/qbittorrent
    useradd --system --shell /usr/sbin/nologin --home-dir /home/qbittorrent --create-home qbittorrent
    
    # 创建必要目录
    mkdir -p /home/qbittorrent/.config/qBittorrent
    mkdir -p /home/qbittorrent/.local/share/data/qBittorrent
    
    # 创建统一下载目录
    mkdir -p /opt/downloads
    
    # 设置目录权限
    chown -R qbittorrent:qbittorrent /home/qbittorrent
    chown -R qbittorrent:qbittorrent /opt/downloads
    
    # 确保qbittorrent用户对/opt/downloads有完全控制权
    chmod -R 755 /opt/downloads
    
    log_info "用户创建完成"
}

# 配置qBittorrent
configure_qbittorrent() {
    log_info "配置qBittorrent..."
    
    # 确保配置目录存在
    mkdir -p /home/qbittorrent/.config/qBittorrent
    
    # 删除可能存在的旧配置
    rm -f /home/qbittorrent/.config/qBittorrent/qBittorrent.conf
    
    # 生成随机端口 (范围: 10000-65000)
    RANDOM_PORT=$((RANDOM % 55000 + 10000))
    
    # 创建配置文件 - 不使用临时下载文件夹
    cat > /home/qbittorrent/.config/qBittorrent/qBittorrent.conf << EOF
[Application]
FileLogger\Enabled=true
FileLogger\Age=1
FileLogger\MaxSizeBytes=66560
FileLogger\Path=/home/qbittorrent/.local/share/data/qBittorrent

[BitTorrent]
Session\DefaultSavePath=/opt/downloads
Session\Port=$RANDOM_PORT
Session\TempPathEnabled=false
Session\AddExtensionToIncompleteFiles=false
Session\Preallocation=true
Session\UseAlternativeGlobalSpeedLimit=false
Session\GlobalMaxRatio=0
Session\GlobalMaxSeedingMinutes=-1
Session\MaxConnections=500
Session\MaxConnectionsPerTorrent=100
Session\MaxUploads=20
Session\MaxUploadsPerTorrent=4
Session\GlobalDLSpeedLimit=0
Session\GlobalUPSpeedLimit=0

[Preferences]
WebUI\Port=8080
WebUI\Username=admin
WebUI\Password_PBKDF2="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)"
WebUI\LocalHostAuth=false
WebUI\AuthSubnetWhitelistEnabled=false
WebUI\CSRFProtection=false
WebUI\ClickjackingProtection=false
Downloads\SavePath=/opt/downloads
Downloads\TempPathEnabled=false
Downloads\UseIncompleteExtension=false
Downloads\PreallocateAll=true
Connection\PortRangeMin=$RANDOM_PORT
Connection\PortRangeMax=$RANDOM_PORT
Connection\UPnP=false
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=0
Bittorrent\DHT=true
Bittorrent\PeX=true
Bittorrent\LSD=true
Bittorrent\Encryption=1
Queueing\MaxActiveDownloads=5
Queueing\MaxActiveTorrents=10
Queueing\MaxActiveUploads=5

[Core]
AutoDeleteAddedTorrentFile=Never

[Meta]
MigrationVersion=4

[Network]
Cookies=@Invalid()
Proxy\OnlyForTorrents=false
EOF

    # 设置配置文件权限
    chown qbittorrent:qbittorrent /home/qbittorrent/.config/qBittorrent/qBittorrent.conf
    chmod 600 /home/qbittorrent/.config/qBittorrent/qBittorrent.conf
    
    log_info "配置文件创建完成 (端口: $RANDOM_PORT)"
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
Type=exec
User=qbittorrent
Group=qbittorrent
UMask=007
WorkingDirectory=/home/qbittorrent
ExecStart=/usr/local/bin/qbittorrent-nox --webui-port=8080 --profile=/home/qbittorrent
Restart=on-failure
TimeoutStopSec=1800

# 环境变量
Environment=HOME=/home/qbittorrent
Environment=XDG_CONFIG_HOME=/home/qbittorrent/.config
Environment=XDG_DATA_HOME=/home/qbittorrent/.local/share

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd并启用服务
    systemctl daemon-reload
    systemctl enable qbittorrent
    
    log_info "systemd服务创建完成"
}

# 通过WebUI API强制设置下载路径
force_set_download_path() {
    log_info "通过WebUI API强制设置下载路径..."
    
    # 等待WebUI完全启动
    local max_attempts=15
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f http://localhost:8080 > /dev/null 2>&1; then
            log_info "WebUI已启动，正在配置路径..."
            break
        fi
        log_info "等待WebUI启动... ($attempt/$max_attempts)"
        sleep 3
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_warn "WebUI启动超时，跳过API配置"
        return 1
    fi
    
    # 尝试通过API设置路径
    local login_response
    login_response=$(curl -s -c /tmp/qb_cookies.txt \
        -d "username=admin&password=adminadmin" \
        "http://localhost:8080/api/v2/auth/login" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        log_info "成功登录WebUI，正在设置下载路径..."
        
        # 设置首选项 - 不使用临时文件夹
        curl -s -b /tmp/qb_cookies.txt \
            -d "json={\"save_path\":\"/opt/downloads\",\"temp_path_enabled\":false}" \
            "http://localhost:8080/api/v2/app/setPreferences" 2>/dev/null
        
        # 清理cookies文件
        rm -f /tmp/qb_cookies.txt
        
        log_info "API配置完成"
        return 0
    else
        log_warn "API登录失败"
        return 1
    fi
}

# 启动qBittorrent服务并确保配置正确
start_service() {
    log_info "启动qBittorrent服务..."
    
    # 确保配置文件存在
    configure_qbittorrent
    
    # 启动服务
    systemctl start qbittorrent
    
    # 检查服务状态
    sleep 3
    if ! systemctl is-active --quiet qbittorrent; then
        log_error "qBittorrent服务启动失败"
        systemctl status qbittorrent --no-pager
        journalctl -u qbittorrent --no-pager -n 20
        exit 1
    fi
    
    log_info "qBittorrent服务启动成功"
    
    # 通过API强制设置路径
    if force_set_download_path; then
        log_info "已通过API设置下载路径"
    else
        log_warn "API设置失败，需要手动配置"
    fi
}

# 防火墙配置
configure_firewall() {
    log_info "配置防火墙..."
    
    # 获取qBittorrent端口
    QB_PORT=$(grep "Session\\\\Port=" "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf" | cut -d'=' -f2)
    
    # 检查并配置iptables/firewalld
    if command -v ufw &> /dev/null; then
        ufw allow 8080/tcp comment "qBittorrent WebUI"
        ufw allow ${QB_PORT}/tcp comment "qBittorrent"
        ufw allow ${QB_PORT}/udp comment "qBittorrent"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=${QB_PORT}/tcp
        firewall-cmd --permanent --add-port=${QB_PORT}/udp
        firewall-cmd --reload
    fi
    
    log_info "防火墙配置完成"
}

# 系统优化 (来自Jerry脚本的优化)
optimize_system() {
    log_info "应用系统优化..."
    
    # 增加文件描述符限制
    cat >> /etc/security/limits.conf << EOF
qbittorrent soft nofile 51200
qbittorrent hard nofile 51200
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

# 显示安装完成信息
show_installation_result() {
    clear
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ip.sb 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
    
    # 获取qBittorrent端口
    QB_PORT=$(grep "Session\\\\Port=" "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf" | cut -d'=' -f2 2>/dev/null || echo "随机端口")
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              qBittorrent $QB_VERSION 安装完成                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}📋 安装信息:${NC}"
    echo -e "   qBittorrent版本: ${WHITE}$QB_VERSION${NC}"
    echo -e "   libtorrent版本:  ${WHITE}$LIBTORRENT_VERSION${NC}"
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
    echo -e "   3. 已禁用临时下载文件夹，所有文件直接下载到 /opt/downloads"
    echo -e "   4. 防火墙已自动配置，如有问题请检查防火墙设置"
    echo -e "   5. 建议重启系统以确保所有优化生效"
    echo
    echo -e "${CYAN}📖 路径修改方法:${NC}"
    echo -e "   1. 登录WebUI: http://$SERVER_IP:8080"
    echo -e "   2. 进入 工具 -> 选项 -> 下载"
    echo -e "   3. 将 '默认保存路径' 修改为: ${WHITE}/opt/downloads${NC}"
    echo -e "   4. 确保 '保存未完成的torrent到' 选项未勾选"
    echo -e "   5. 点击 '应用' 保存设置"
    echo
}

# 主函数
main() {
    log_info "开始安装qBittorrent $QB_VERSION..."
    
    check_root
    check_system
    install_dependencies
    install_libtorrent
    install_qbittorrent
    create_user
    # 注意：这里先不调用configure_qbittorrent，在start_service中处理
    create_service
    optimize_system  # 添加系统优化
    start_service    # 这个函数会处理配置和启动
    configure_firewall
    
    # 最终验证下载路径
    log_info "验证默认下载路径设置..."
    sleep 2
    if [ -f "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf" ]; then
        if grep -q "Downloads.*SavePath=/opt/downloads" "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf"; then
            log_info "✓ 默认下载路径已正确设置为: /opt/downloads"
        else
            log_warn "⚠ 下载路径配置需要在WebUI中手动确认"
            log_info "请在WebUI设置中将下载路径修改为: /opt/downloads"
        fi
    fi
    
    show_installation_result
    
    log_info "安装完成！"
    log_info ""
    log_info "================================================================"
    log_info "✅ qBittorrent $QB_VERSION 安装成功"
    log_info "🔧 默认保存路径已设置为: /opt/downloads"
    log_info "📁 已禁用临时下载文件夹，所有文件直接下载到主目录"
    log_info "⚡ 系统已优化，支持高性能PT刷流"
    log_info "================================================================"
}

# 执行主函数
main "$@"
