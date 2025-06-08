#!/bin/bash

# qBittorrent 4.3.8 安装脚本
# 修改自: https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh
# 适配PTtools项目
# 使用 libtorrent 1.2.20 版本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 版本定义
QB_VERSION="4.3.8"
LT_VERSION="1.2.20"

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

# 错误处理
set -e
trap 'log_error "脚本执行失败在第 $LINENO 行"; exit 1' ERR

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

# 检查必要工具
check_prerequisites() {
    log_info "检查必要工具..."
    
    local missing_tools=()
    
    # 检查必要的命令
    for cmd in wget curl make gcc g++ systemctl; do
        if ! command -v $cmd &> /dev/null; then
            missing_tools+=($cmd)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必要工具: ${missing_tools[*]}"
        log_info "请先安装这些工具后再运行脚本"
        exit 1
    fi
    
    log_info "工具检查通过"
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
    log_info "编译安装libtorrent-rasterbar ${LT_VERSION}..."
    
    cd /tmp
    
    # 备份旧配置
    if [ -f "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf" ]; then
        cp "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf" \
           "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf.bak" 2>/dev/null || true
    fi
    
    # 下载libtorrent源码
    if [ ! -f "libtorrent-rasterbar-${LT_VERSION}.tar.gz" ]; then
        if ! wget https://github.com/arvidn/libtorrent/releases/download/v${LT_VERSION}/libtorrent-rasterbar-${LT_VERSION}.tar.gz; then
            log_error "下载libtorrent失败"
            exit 1
        fi
    fi
    
    if ! tar xf libtorrent-rasterbar-${LT_VERSION}.tar.gz; then
        log_error "解压libtorrent失败"
        exit 1
    fi
    
    cd libtorrent-rasterbar-${LT_VERSION}
    
    # 配置编译选项
    if ! ./configure \
        --enable-encryption \
        --disable-debug \
        --enable-optimizations \
        --with-libgeoip=system; then
        log_error "配置libtorrent失败"
        exit 1
    fi
    
    # 编译并安装
    if ! make -j$(nproc); then
        log_error "编译libtorrent失败"
        exit 1
    fi
    
    if ! make install; then
        log_error "安装libtorrent失败"
        exit 1
    fi
    
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
    log_info "编译安装qBittorrent ${QB_VERSION}..."
    
    cd /tmp
    
    # 下载qBittorrent源码
    if [ ! -f "qbittorrent-${QB_VERSION}.tar.gz" ]; then
        if ! wget https://github.com/qbittorrent/qBittorrent/archive/release-${QB_VERSION}.tar.gz -O qbittorrent-${QB_VERSION}.tar.gz; then
            log_error "下载qBittorrent失败"
            exit 1
        fi
    fi
    
    if ! tar xf qbittorrent-${QB_VERSION}.tar.gz; then
        log_error "解压qBittorrent失败"
        exit 1
    fi
    
    cd qBittorrent-release-${QB_VERSION}
    
    # 根据系统类型设置boost库路径
    if [ "$OS" = "debian" ]; then
        BOOST_LIB_PATH="/usr/lib/x86_64-linux-gnu"
    elif [ "$OS" = "centos" ]; then
        BOOST_LIB_PATH="/usr/lib64"
    fi
    
    # 配置编译选项
    if ! ./configure \
        --disable-gui \
        --enable-systemd \
        --with-boost-libdir=$BOOST_LIB_PATH; then
        log_error "配置qBittorrent失败"
        exit 1
    fi
    
    # 编译并安装
    if ! make -j$(nproc); then
        log_error "编译qBittorrent失败"
        exit 1
    fi
    
    if ! make install; then
        log_error "安装qBittorrent失败"
        exit 1
    fi
    
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
    
    # 创建配置文件 - 不使用临时下载文件夹
    cat > /home/qbittorrent/.config/qBittorrent/qBittorrent.conf << 'EOF'
[BitTorrent]
Session\DefaultSavePath=/opt/downloads
Session\TempPathEnabled=false
Session\Port=8999

[Preferences]
Downloads\SavePath=/opt/downloads
Downloads\TempPathEnabled=false
Downloads\UseIncompleteExtension=false
WebUI\Username=admin
WebUI\Password_PBKDF2="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)"
WebUI\LocalHostAuth=false
WebUI\Port=8080
Connection\PortRangeMin=8999
Connection\PortRangeMax=8999

[Application]
FileLogger\Enabled=false

[Core]
AutoDeleteAddedTorrentFile=Never

[Meta]
MigrationVersion=4
EOF

    # 设置配置文件权限
    chown qbittorrent:qbittorrent /home/qbittorrent/.config/qBittorrent/qBittorrent.conf
    chmod 600 /home/qbittorrent/.config/qBittorrent/qBittorrent.conf
    
    log_info "配置文件创建完成"
    log_warn "默认登录信息: 用户名=admin, 密码=adminadmin"
}

# 创建systemd服务
create_service() {
    log_info "创建systemd服务..."
    
    # 检查systemd版本
    SYSTEMD_VERSION=$(systemctl --version | head -1 | awk '{print $2}')
    if [ "$SYSTEMD_VERSION" -ge 240 ] 2>/dev/null; then
        SERVICE_TYPE="exec"
    else
        SERVICE_TYPE="simple"
    fi
    
    cat > /etc/systemd/system/qbittorrent.service << EOF
[Unit]
Description=qBittorrent Command Line Client
After=network.target

[Service]
Type=$SERVICE_TYPE
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

# 获取服务器IP的函数
get_server_ip() {
    local ip=""
    
    # 尝试获取公网IP
    ip=$(curl -s --connect-timeout 3 ip.sb 2>/dev/null)
    
    if [ -z "$ip" ]; then
        ip=$(curl -s --connect-timeout 3 ipinfo.io/ip 2>/dev/null)
    fi
    
    # 如果获取公网IP失败，尝试获取本地IP
    if [ -z "$ip" ]; then
        # 获取主网卡的IP地址
        ip=$(ip route get 1 2>/dev/null | awk '{print $(NF-2);exit}')
    fi
    
    # 如果还是失败，返回localhost
    if [ -z "$ip" ]; then
        ip="localhost"
    fi
    
    echo "$ip"
}

# 清理临时文件
cleanup_temp_files() {
    log_info "清理临时文件..."
    
    # 清理编译文件
    rm -rf /tmp/libtorrent-rasterbar-${LT_VERSION}*
    rm -rf /tmp/qBittorrent-release-${QB_VERSION}*
    rm -f /tmp/qb_cookies.txt
    
    # 清理下载的压缩包（可选）
    # rm -f /tmp/libtorrent-rasterbar-${LT_VERSION}.tar.gz
    # rm -f /tmp/qbittorrent-${QB_VERSION}.tar.gz
    
    log_info "临时文件清理完成"
}

# 显示安装完成信息
show_installation_result() {
    clear
    
    # 获取服务器IP
    SERVER_IP=$(get_server_ip)
    
    # 获取qBittorrent端口
    QB_PORT=$(grep "Session\\Port=" "/home/qbittorrent/.config/qBittorrent/qBittorrent.conf" | cut -d'=' -f2 2>/dev/null || echo "8999")
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              qBittorrent ${QB_VERSION} 安装完成                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}📋 安装信息:${NC}"
    echo -e "   qBittorrent版本: ${WHITE}${QB_VERSION}${NC}"
    echo -e "   libtorrent版本:  ${WHITE}${LT_VERSION}${NC}"
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
    echo -e "   2. 如果下载路径显示不正确，请在WebUI设置中手动修改为: ${WHITE}/opt/downloads${NC}"
    echo -e "   3. 已禁用临时下载文件夹，所有文件直接下载到主目录"
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
    log_info "开始安装qBittorrent ${QB_VERSION} (使用 libtorrent ${LT_VERSION})..."
    
    check_root
    check_system
    check_prerequisites
    install_dependencies
    install_libtorrent
    install_qbittorrent
    create_user
    # 注意：这里先不调用configure_qbittorrent，在start_service中处理
    create_service
    start_service  # 这个函数会处理配置和启动
    configure_firewall
    
    # 清理临时文件
    cleanup_temp_files
    
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
    log_info "🔧 下载路径设置验证"
    log_info "================================================================"
    log_info "1. 打开 WebUI: http://$(get_server_ip):8080"
    log_info "2. 用户名: admin，密码: adminadmin"
    log_info "3. 进入: 工具 → 选项 → 下载"
    log_info "4. 检查 '默认保存路径' 是否为: /opt/downloads"
    log_info "5. 确保 '保存未完成的torrent到' 选项未勾选（已禁用临时文件夹）"
    log_info "6. 如果不是，请手动修改为: /opt/downloads"
    log_info "================================================================"
}

# 执行主函数
main "$@"
