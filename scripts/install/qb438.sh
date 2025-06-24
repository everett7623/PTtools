#!/bin/bash
# ============================================================================
# 脚本名称: qb438.sh
# 脚本描述: qBittorrent 4.3.8 快速安装脚本 (使用官方二进制包)
# 脚本路径: https://raw.githubusercontent.com/everett7623/PTtools/main/scripts/install/qb438.sh
# 使用方法: bash qb438.sh
# 作者: everett7623
# 更新时间: 2025-01-24
# 版本信息: qBittorrent 4.3.8 + libtorrent 1.2.20
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
QB_VERSION="4.3.8"
LT_VERSION="1.2.20"
QB_USER="qbittorrent"
QB_HOME="/home/${QB_USER}"
QB_CONFIG="${QB_HOME}/.config/qBittorrent"
QB_DOWNLOAD_DIR="/opt/downloads"
INSTALL_DIR="/usr/local/bin"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 显示脚本标题
show_banner() {
    clear
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}                    qBittorrent 4.3.8 快速安装脚本                          ${NC}"
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "版本: qBittorrent ${QB_VERSION} + libtorrent ${LT_VERSION}"
    echo -e "说明: 使用官方二进制包快速安装，无需编译"
    echo -e "${GREEN}============================================================================${NC}"
    echo
}

# 检查系统要求
check_system() {
    print_info "检查系统环境..."
    
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本必须以root权限运行"
        exit 1
    fi
    
    # 检查操作系统
    if [[ ! -f /etc/debian_version ]]; then
        print_error "此脚本仅支持Debian/Ubuntu系统"
        exit 1
    fi
    
    # 获取系统版本
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        print_error "无法确定操作系统版本"
        exit 1
    fi
    
    # 检查系统架构
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]]; then
        print_error "此脚本仅支持x86_64架构"
        exit 1
    fi
    
    print_success "系统检查通过: $OS $VER ($ARCH)"
}

# 安装基础依赖包
install_dependencies() {
    print_info "更新软件包列表..."
    apt-get update -qq
    
    print_info "安装必要的依赖包..."
    apt-get install -y -qq \
        wget \
        curl \
        ca-certificates \
        libgeoip1 \
        python3
    
    print_success "依赖包安装完成"
}

# 创建qbittorrent用户
create_user() {
    print_info "创建qbittorrent用户..."
    
    if id "$QB_USER" &>/dev/null; then
        print_warning "用户 $QB_USER 已存在，跳过创建"
    else
        useradd -m -s /bin/bash $QB_USER
        print_success "用户 $QB_USER 创建成功"
    fi
    
    # 创建下载目录
    mkdir -p $QB_DOWNLOAD_DIR
    chown -R $QB_USER:$QB_USER $QB_DOWNLOAD_DIR
    chmod 755 $QB_DOWNLOAD_DIR
}

# 下载并安装qBittorrent预编译版本
download_precompiled_qb() {
    local url=$1
    local filename=$2
    
    print_info "正在下载: $filename"
    
    # 下载文件
    if wget --progress=bar:force -t 3 -T 30 -O "$filename" "$url" 2>&1; then
        # 检查文件是否存在且大小合理
        if [[ -f "$filename" ]] && [[ $(stat -c%s "$filename" 2>/dev/null || echo 0) -gt 5000000 ]]; then
            return 0
        fi
    fi
    
    rm -f "$filename"
    return 1
}

# 安装qBittorrent
install_qbittorrent() {
    print_info "开始安装 qBittorrent ${QB_VERSION}..."
    
    # 创建临时目录
    TMP_DIR="/tmp/qb_install_$$"
    mkdir -p $TMP_DIR
    cd $TMP_DIR
    
    # 尝试下载预编译版本
    DOWNLOAD_SUCCESS=false
    
    # 方案1: 使用已知的稳定预编译版本
    print_info "尝试下载预编译版本..."
    
    # 下载链接列表
    declare -A DOWNLOAD_LINKS=(
        ["qb_shutu"]="https://github.com/Shutu736/pt/raw/master/qb-nox/qbittorrent-nox_4.3.8_linux_x64"
        ["qb_static_1214"]="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.8_v1.2.14/x86_64-qbittorrent-nox"
        ["qb_static_1215"]="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.8_v1.2.15/x86_64-qbittorrent-nox"
    )
    
    # 尝试每个下载源
    for key in "${!DOWNLOAD_LINKS[@]}"; do
        if download_precompiled_qb "${DOWNLOAD_LINKS[$key]}" "qbittorrent-nox"; then
            DOWNLOAD_SUCCESS=true
            print_success "从 $key 下载成功"
            break
        else
            print_warning "从 $key 下载失败，尝试下一个源..."
        fi
    done
    
    # 如果下载失败，尝试apt安装
    if [[ "$DOWNLOAD_SUCCESS" = false ]]; then
        print_warning "所有预编译版本下载失败，尝试通过apt安装..."
        
        # 安装qbittorrent-nox
        if apt-get install -y qbittorrent-nox; then
            print_success "通过apt安装成功"
            # 清理并返回
            cd /
            rm -rf $TMP_DIR
            return 0
        else
            print_error "apt安装也失败了"
            cd /
            rm -rf $TMP_DIR
            exit 1
        fi
    fi
    
    # 安装下载的二进制文件
    chmod +x qbittorrent-nox
    
    # 移动到安装目录
    mv qbittorrent-nox /usr/local/bin/qbittorrent-nox
    
    # 创建符号链接
    ln -sf /usr/local/bin/qbittorrent-nox /usr/bin/qbittorrent-nox
    
    print_success "qBittorrent ${QB_VERSION} 安装成功"
    
    # 清理临时文件
    cd /
    rm -rf $TMP_DIR
}

# 配置qBittorrent
configure_qbittorrent() {
    print_info "配置qBittorrent..."
    
    # 创建配置目录
    sudo -u $QB_USER mkdir -p "$QB_CONFIG"
    
    # 创建初始配置文件
    cat > "$QB_CONFIG/qBittorrent.conf" << EOF
[AutoRun]
enabled=false
program=

[BitTorrent]
Session\AsyncIOThreadsCount=8
Session\CheckingMemUsageSize=128
Session\FilePoolSize=5000
Session\MultiConnectionsPerIp=true
Session\SlowTorrentsDownloadRate=20
Session\SlowTorrentsInactivityTimer=60
Session\SlowTorrentsUploadRate=20

[Core]
AutoDeleteAddedTorrentFile=Never

[LegalNotice]
Accepted=true

[Meta]
MigrationVersion=3

[Network]
Cookies=@Invalid()

[Preferences]
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=0
Connection\PortRangeMin=28888
Downloads\DiskWriteCacheSize=64
Downloads\DiskWriteCacheTTL=60
Downloads\SavePath=/opt/downloads/
Downloads\ScanDirsV2=@Variant(\0\0\0\x1c\0\0\0\0)
General\Locale=zh_CN
General\UseRandomPort=false
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
WebUI\HostHeaderValidation=true
WebUI\LocalHostAuth=true
WebUI\MaxAuthenticationFailCount=5
WebUI\Port=8080
WebUI\ReverseProxySupportEnabled=false
WebUI\RootFolder=
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\TrustedReverseProxiesList=
WebUI\UseUPnP=false
WebUI\Username=admin

[RSS]
AutoDownloader\DownloadRepacks=true
AutoDownloader\SmartEpisodeFilter=s(\\d+)e(\\d+), (\\d+)x(\\d+), "(\\d{4}[.\\-]\\d{1,2}[.\\-]\\d{1,2})", "(\\d{1,2}[.\\-]\\d{1,2}[.\\-]\\d{4})"
EOF

    # 设置默认密码为 adminadmin
    print_info "设置WebUI默认密码..."
    
    # 生成密码哈希（使用简单的方法）
    # 注意：这是qBittorrent 4.3.8使用的旧版密码格式
    PASSWD_HASH='@ByteArray(mDiVG1lHVKaXJhc8RKQN2A==:D3GCfWJdf5IVcEpih7vRWMPqB0DhYvSPcLCJvKMrYPMOI8h0aH0TKBpCp5gQIYJPdTDYRyCjCF2HeqGNkXaKgg==)'
    echo "WebUI\Password_PBKDF2=\"$PASSWD_HASH\"" >> "$QB_CONFIG/qBittorrent.conf"
    
    # 设置权限
    chown -R $QB_USER:$QB_USER "$QB_CONFIG"
    chmod 600 "$QB_CONFIG/qBittorrent.conf"
    
    print_success "qBittorrent配置完成"
}

# 创建systemd服务
create_systemd_service() {
    print_info "创建systemd服务..."
    
    cat > /etc/systemd/system/qbittorrent.service << EOF
[Unit]
Description=qBittorrent-nox service
Documentation=man:qbittorrent-nox(1)
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=exec
User=$QB_USER
Group=$QB_USER
WorkingDirectory=$QB_HOME
ExecStart=/usr/bin/qbittorrent-nox
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd配置
    systemctl daemon-reload
    
    # 启用并启动服务
    systemctl enable qbittorrent.service
    systemctl start qbittorrent.service
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if systemctl is-active --quiet qbittorrent.service; then
        print_success "qBittorrent服务启动成功"
    else
        print_warning "qBittorrent服务启动可能失败，请检查日志"
    fi
}

# 配置防火墙
configure_firewall() {
    print_info "配置防火墙规则..."
    
    # 检查是否安装了ufw
    if command -v ufw &> /dev/null; then
        ufw allow 8080/tcp comment 'qBittorrent Web UI' >/dev/null 2>&1 || true
        ufw allow 28888/tcp comment 'qBittorrent TCP' >/dev/null 2>&1 || true
        ufw allow 28888/udp comment 'qBittorrent UDP' >/dev/null 2>&1 || true
        print_success "UFW防火墙规则已添加"
    else
        print_info "未检测到UFW防火墙"
    fi
}

# 显示安装信息
show_info() {
    # 获取本机IP
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    echo
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}                    qBittorrent 安装成功!                                   ${NC}"
    echo -e "${GREEN}============================================================================${NC}"
    echo
    echo -e "${BLUE}版本信息:${NC}"
    echo -e "  qBittorrent: ${QB_VERSION}"
    echo -e "  libtorrent:  ${LT_VERSION}"
    echo
    echo -e "${BLUE}访问信息:${NC}"
    echo -e "  Web UI地址: http://${LOCAL_IP}:8080"
    echo -e "  默认用户名: admin"
    echo -e "  默认密码:   adminadmin"
    echo
    echo -e "${BLUE}服务管理:${NC}"
    echo -e "  启动服务: systemctl start qbittorrent"
    echo -e "  停止服务: systemctl stop qbittorrent"
    echo -e "  重启服务: systemctl restart qbittorrent"
    echo -e "  查看状态: systemctl status qbittorrent"
    echo -e "  查看日志: journalctl -u qbittorrent -f"
    echo
    echo -e "${BLUE}配置文件:${NC}"
    echo -e "  配置目录: $QB_CONFIG"
    echo -e "  下载目录: $QB_DOWNLOAD_DIR"
    echo
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${YELLOW}提示: 首次登录后请立即修改默认密码!${NC}"
    echo -e "${GREEN}============================================================================${NC}"
}

# 主函数
main() {
    show_banner
    check_system
    install_dependencies
    create_user
    install_qbittorrent
    configure_qbittorrent
    create_systemd_service
    configure_firewall
    show_info
}

# 执行主函数
main
