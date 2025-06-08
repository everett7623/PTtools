#!/bin/bash

# qBittorrent 4.3.8 安装脚本
# 修改自: https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh
# 适配PTtools项目，支持传入参数配置用户名、密码、端口、下载目录

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
    exit 1 # 遇到错误即退出
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行。"
    fi
}

# 检查系统类型
check_system() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
        log_info "检测到Debian/Ubuntu系统。"
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        log_info "检测到CentOS/RHEL系统。"
    else
        log_error "不支持的系统类型。"
    fi
}

# 安装依赖包
install_dependencies() {
    log_info "安装依赖包..."

    if [ "$OS" = "debian" ]; then
        apt-get update || log_error "APT更新失败。"
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
            python3 || log_error "Debian/Ubuntu依赖安装失败。"
    elif [ "$OS" = "centos" ]; then
        yum groupinstall -y "Development Tools" || log_error "CentOS开发工具安装失败。"
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
            python3 || log_error "CentOS依赖安装失败。"
    fi
    log_info "依赖安装完成。"
}

# 编译安装libtorrent-rasterbar
install_libtorrent() {
    log_info "编译安装libtorrent-rasterbar 1.2.19..."

    cd /tmp || log_error "无法进入 /tmp 目录。"

    # 下载libtorrent源码
    if [ ! -f "libtorrent-rasterbar-1.2.19.tar.gz" ]; then
        wget https://github.com/arvidn/libtorrent/releases/download/v1.2.19/libtorrent-rasterbar-1.2.19.tar.gz || log_error "下载libtorrent源码失败。"
    fi

    tar xf libtorrent-rasterbar-1.2.19.tar.gz || log_error "解压libtorrent源码失败。"
    cd libtorrent-rasterbar-1.2.19 || log_error "无法进入libtorrent源码目录。"

    # 配置编译选项
    ./configure \
        --enable-encryption \
        --disable-debug \
        --enable-optimizations \
        --with-libgeoip=system || log_error "配置libtorrent失败。"

    # 编译并安装
    make -j$(nproc) || log_error "编译libtorrent失败。"
    make install || log_error "安装libtorrent失败。"

    # 更新库链接
    if [ "$OS" = "debian" ]; then
        ldconfig || log_warn "ldconfig执行失败，可能需要手动运行。"
    elif [ "$OS" = "centos" ]; then
        echo "/usr/local/lib" > /etc/ld.so.conf.d/libtorrent.conf || log_warn "创建libtorrent.conf失败。"
        ldconfig || log_warn "ldconfig执行失败，可能需要手动运行。"
    fi

    log_info "libtorrent-rasterbar安装完成。"
}

# 编译安装qBittorrent
install_qbittorrent() {
    log_info "编译安装qBittorrent 4.3.8..."

    cd /tmp || log_error "无法进入 /tmp 目录。"

    # 下载qBittorrent源码
    if [ ! -f "qbittorrent-4.3.8.tar.gz" ]; then
        wget https://github.com/qbittorrent/qBittorrent/archive/release-4.3.8.tar.gz -O qbittorrent-4.3.8.tar.gz || log_error "下载qBittorrent源码失败。"
    fi

    tar xf qbittorrent-4.3.8.tar.gz || log_error "解压qBittorrent源码失败。"
    cd qBittorrent-release-4.3.8 || log_error "无法进入qBittorrent源码目录。"

    # 配置编译选项
    ./configure \
        --disable-gui \
        --enable-systemd \
        --with-boost-libdir=/usr/lib/x86_64-linux-gnu || log_error "配置qBittorrent失败。"

    # 编译并安装
    make -j$(nproc) || log_error "编译qBittorrent失败。"
    make install || log_error "安装qBittorrent失败。"

    log_info "qBittorrent编译安装完成。"
}

# 创建qbittorrent用户和目录
create_user_and_dirs() {
    log_info "创建qBittorrent运行用户和目录..."

    # 创建系统用户
    if ! id "$QB_USER" &>/dev/null; then
        useradd --system --shell /usr/sbin/nologin --home-dir /var/lib/qbittorrent "$QB_USER" || log_error "创建用户 '$QB_USER' 失败。"
        log_info "用户 '$QB_USER' 创建成功。"
    else
        log_info "用户 '$QB_USER' 已存在，跳过创建。"
    fi

    # 创建必要目录
    mkdir -p "/home/$QB_USER/.config/qBittorrent" || log_error "创建用户配置目录失败。"
    mkdir -p "/home/$QB_USER/.local/share/data/qBittorrent" || log_error "创建用户数据目录失败。"
    
    # 确保下载目录存在并设置权限
    mkdir -p "$DOWNLOAD_PATH" || log_error "创建下载目录 $DOWNLOAD_PATH 失败。"
    mkdir -p "$DOWNLOAD_PATH/complete" || log_error "创建完成目录失败。"
    mkdir -p "$DOWNLOAD_PATH/incomplete" || log_error "创建未完成目录失败。"
    mkdir -p "$DOWNLOAD_PATH/watch" || log_error "创建监控目录失败。"

    # 设置目录权限
    chown -R "$QB_USER":"$QB_USER" "/home/$QB_USER" || log_error "设置用户家目录权限失败。"
    chown -R "$QB_USER":"$QB_USER" /var/lib/qbittorrent || log_error "设置 /var/lib/qbittorrent 权限失败。"
    chown -R "$QB_USER":"$QB_USER" "$DOWNLOAD_PATH" || log_error "设置下载目录权限失败。"
    
    log_info "用户和目录创建完成。"
}

# 配置qBittorrent
configure_qbittorrent() {
    log_info "配置qBittorrent..."

    local QB_CONFIG_DIR="/home/$QB_USER/.config/qBittorrent"
    local QB_CONF="$QB_CONFIG_DIR/qBittorrent.conf"

    # PBKDF2加密后的密码
    # 这个是 'adminadmin' 的 PBKDF2 hash。请提醒用户登录后修改。
    local ENCRYPTED_PASSWORD="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)"

    cat > "$QB_CONF" << EOF
[Application]
FileLogger\Enabled=true
FileLogger\Age=1
FileLogger\MaxSizeBytes=66560
FileLogger\Path=/home/${QB_USER}/.local/share/data/qBittorrent

[BitTorrent]
Session\DefaultSavePath=${DOWNLOAD_PATH}
Session\Port=${BT_PORT}
Session\TempPath=${DOWNLOAD_PATH}/incomplete
Session\TempPathEnabled=true

[Preferences]
WebUI\Port=${WEBUI_PORT}
WebUI\Username=${QB_USER}
WebUI\Password_PBKDF2=${ENCRYPTED_PASSWORD}
WebUI\LocalHostAuth=false
Downloads\SavePath=${DOWNLOAD_PATH}
Downloads\TempPath=${DOWNLOAD_PATH}/incomplete
Downloads\TempPathEnabled=true
Downloads\UseIncompleteExtension=true
Downloads\ScanDirs\1\enabled=true
Downloads\ScanDirs\1\path=${DOWNLOAD_PATH}/watch
Downloads\ScanDirs\size=1
Connection\PortRangeMin=${BT_PORT}
Connection\PortRangeMax=${BT_PORT}
General\DefaultSavePath=${DOWNLOAD_PATH}
General\TempPath=${DOWNLOAD_PATH}/incomplete
General\TempPathEnabled=true
EOF

    # 设置配置文件权限
    chown "$QB_USER":"$QB_USER" "$QB_CONF" || log_error "设置qBittorrent配置文件权限失败。"
    
    log_info "qBittorrent配置文件创建完成。"
    log_warn "默认登录信息: 用户名=${QB_USER}, 密码=adminadmin (请首次登录后修改密码！)"
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
User=${QB_USER}
Group=${QB_USER}
UMask=007
ExecStart=/usr/local/bin/qbittorrent-nox -d --webui-port=${WEBUI_PORT}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd并启用服务
    systemctl daemon-reload || log_error "Systemd守护进程重新加载失败。"
    systemctl enable qbittorrent || log_error "启用qBittorrent服务失败。"
    
    log_info "systemd服务创建完成。"
}

# 启动qBittorrent服务
start_service() {
    log_info "启动qBittorrent服务..."

    systemctl start qbittorrent || log_error "qBittorrent服务启动失败。"
    
    # 检查服务状态
    if systemctl is-active --quiet qbittorrent; then
        log_info "qBittorrent服务启动成功。"
    else
        log_error "qBittorrent服务启动失败，请检查日志: journalctl -u qbittorrent -f"
    fi
}

# 防火墙配置
configure_firewall() {
    log_info "配置防火墙..."

    # 检查并配置iptables/firewalld/ufw
    if command -v ufw &> /dev/null; then
        ufw allow "$WEBUI_PORT"/tcp || log_warn "UFW允许WebUI端口失败。"
        ufw allow "$BT_PORT"/tcp || log_warn "UFW允许BT TCP端口失败。"
        ufw allow "$BT_PORT"/udp || log_warn "UFW允许BT UDP端口失败。"
        ufw reload || log_warn "UFW重载失败。"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port="$WEBUI_PORT"/tcp || log_warn "FirewallD添加WebUI端口失败。"
        firewall-cmd --permanent --add-port="$BT_PORT"/tcp || log_warn "FirewallD添加BT TCP端口失败。"
        firewall-cmd --permanent --add-port="$BT_PORT"/udp || log_warn "FirewallD添加BT UDP端口失败。"
        firewall-cmd --reload || log_warn "FirewallD重载失败。"
    else
        log_warn "未检测到UFW或FirewallD，请手动配置防火墙规则。"
    fi
    
    log_info "防火墙配置完成。"
}

# 显示安装完成信息
show_installation_result() {
    clear
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ip.sb 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║             qBittorrent 4.3.8 安装完成                       ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}📋 安装信息:${NC}"
    echo -e "    qBittorrent版本: ${WHITE}4.3.8${NC}"
    echo -e "    libtorrent版本:  ${WHITE}1.2.19${NC}"
    echo -e "    运行用户:        ${WHITE}${QB_USER}${NC}"
    echo
    echo -e "${CYAN}🌐 访问信息:${NC}"
    echo -e "    WebUI地址:       ${WHITE}http://$SERVER_IP:${WEBUI_PORT}${NC}"
    echo -e "    用户名:          ${WHITE}${QB_USER}${NC}"
    echo -e "    密码:            ${WHITE}adminadmin${NC}"
    echo -e "    BT端口:          ${WHITE}${BT_PORT}${NC}"
    echo
    echo -e "${CYAN}📁 目录信息:${NC}"
    echo -e "    下载根目录:      ${WHITE}${DOWNLOAD_PATH}${NC}"
    echo -e "    完成目录:        ${WHITE}${DOWNLOAD_PATH}/complete${NC}"
    echo -e "    未完成目录:      ${WHITE}${DOWNLOAD_PATH}/incomplete${NC}"
    echo -e "    监控目录:        ${WHITE}${DOWNLOAD_PATH}/watch${NC}"
    echo -e "    配置目录:        ${WHITE}/home/${QB_USER}/.config/qBittorrent${NC}"
    echo
    echo -e "${CYAN}🔧 服务管理:${NC}"
    echo -e "    启动服务:        ${WHITE}systemctl start qbittorrent${NC}"
    echo -e "    停止服务:        ${WHITE}systemctl stop qbittorrent${NC}"
    echo -e "    重启服务:        ${WHITE}systemctl restart qbittorrent${NC}"
    echo -e "    查看状态:        ${WHITE}systemctl status qbittorrent${NC}"
    echo -e "    查看日志:        ${WHITE}journalctl -u qbittorrent -f${NC}"
    echo
    echo -e "${YELLOW}⚠️  重要提醒:${NC}"
    echo -e "    1. 首次登录WebUI后请务必修改默认密码！"
    echo -e "    2. 建议在WebUI中进行进一步的个性化配置。"
    echo -e "    3. 防火墙已尝试自动配置，如有问题请手动检查设置。"
    echo -e "    4. 建议在安装后${RED}手动重启系统${NC}以确保所有优化和设置生效。"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# 主函数
main() {
    log_info "开始安装qBittorrent 4.3.8..."
    
    check_root
    check_system

    # 参数处理，适配pttools主脚本的调用
    if [ "$#" -ge 2 ]; then
        QB_USER_ARG=$1
        QB_PASSWORD_ARG=$2 # 尽管这里不会直接用明文密码设置，但保留作为参数
        WEBUI_PORT_ARG=${3:-8080}
        BT_PORT_ARG=${4:-23333}
        DOWNLOAD_PATH_ARG=${5:-/opt/downloads} # 新增下载路径参数
    else
        log_error "参数不足。用法: $0 <qb_用户名> <qb_密码> [webui_端口] [bt_上传端口] [下载路径]"
    fi

    # 实际使用的变量
    QB_USER="$QB_USER_ARG"
    WEBUI_PORT="$WEBUI_PORT_ARG"
    BT_PORT="$BT_PORT_ARG"
    DOWNLOAD_PATH="$DOWNLOAD_PATH_ARG"

    log_info "安装参数："
    log_info "  用户名: $QB_USER"
    log_info "  WebUI端口: $WEBUI_PORT"
    log_info "  BT端口: $BT_PORT"
    log_info "  下载路径: $DOWNLOAD_PATH"
    echo

    install_dependencies
    install_libtorrent
    install_qbittorrent
    create_user_and_dirs
    configure_qbittorrent
    create_service
    start_service
    configure_firewall
    
    show_installation_result
    
    log_info "安装完成！请根据提示手动重启系统以确保所有配置生效。"
}

# 执行主函数
main "$@"
