#!/bin/bash

#======================================================================================
#   qBittorrent 4.3.8 安装脚本
#   - 修改自: https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh
#   - 适配PTtools项目
#   - 提供 "极速安装" (预编译) 和 "编译安装" (源码) 两种模式
#   - 默认采用极速安装，解决国内服务器编译慢、下载慢的问题
#   - 使用 ghproxy.com 代理加速 GitHub 资源下载
#   - 脚本结构清晰，日志完备，错误处理友好
#   - 集成用户创建、systemd 服务配置、防火墙设置等最佳实践
#======================================================================================

# --- 配置区 ---
# 默认使用极速安装。如果需要编译安装，请修改为 "compile"
INSTALL_MODE="fast" # 可选: "fast" (极速安装) 或 "compile" (编译安装)

# 版本定义 (编译安装时生效)
QB_VERSION="4.3.9"
LT_VERSION="1.2.20"

# 预编译文件的下载地址 (极速安装时生效)
# 您可以替换为其他可靠的、更新的预编译文件源
PRECOMPILED_URL_X86_64="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v${LT_VERSION}/x86_64-qbittorrent-nox"
PRECOMPILED_URL_AARCH64="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v${LT_VERSION}/aarch64-qbittorrent-nox"

# GitHub 资源下载代理
GH_PROXY="https://ghproxy.com/"

# --- 脚本核心 ---

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_cyan() { echo -e "${CYAN}[>>>>]${NC} $1"; }

# 错误处理
set -e
trap 'log_error "脚本在第 $LINENO 行执行失败"; exit 1' ERR

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行，请使用 sudo ./script.sh"
        exit 1
    fi
}

# 检查并设置系统类型
check_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        log_error "无法检测到操作系统类型。"
        exit 1
    fi
    log_info "检测到操作系统: ${OS}"
}

# 包装 wget 命令，增加重试和代理功能
wget_wrapper() {
    log_info "正在下载: $1"
    wget -q --show-progress --progress=bar:force:noscroll --tries=3 --timeout=60 -O "$2" "$1"
}

# 安装依赖
install_dependencies() {
    log_cyan "正在安装依赖..."
    case "$OS" in
        debian|ubuntu)
            apt-get update -qq
            if [ "$INSTALL_MODE" = "compile" ]; then
                log_info "为[编译模式]安装完整依赖..."
                apt-get install -y build-essential cmake git pkg-config automake libtool \
                                   libboost-dev libboost-system-dev libboost-chrono-dev \
                                   libboost-random-dev libssl-dev qtbase5-dev \
                                   qttools5-dev-tools zlib1g-dev libqt5svg5-dev python3 curl
            else
                log_info "为[极速模式]安装核心依赖..."
                apt-get install -y libboost-system1.74.0 libboost-chrono1.74.0 libssl3 libqt5core5a libqt5dbus5 libqt5network5 libqt5sql5 libqt5svg5 zlib1g curl
            fi
            ;;
        centos|rhel)
            # CentOS 的依赖处理较为复杂，这里仅为示例
            if [ "$INSTALL_MODE" = "compile" ]; then
                log_warn "CentOS/RHEL 的编译模式依赖较为复杂，请确保已启用EPEL源"
                yum groupinstall -y "Development Tools"
                yum install -y cmake git pkgconfig automake libtool boost-devel openssl-devel qt5-qtbase-devel qt5-qttools-devel zlib-devel qt5-qtsvg-devel python3 curl
            else
                log_info "为[极速模式]安装核心依赖..."
                yum install -y boost-system boost-chrono openssl-libs qt5-qtbase qt5-qtsvg zlib curl
            fi
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
    log_info "依赖安装完成。"
}

# 极速安装 (下载预编译文件)
fast_install_qbittorrent() {
    log_cyan "开始极速安装 qBittorrent..."
    local arch=$(uname -m)
    local download_url

    if [[ "$arch" == "x86_64" ]]; then
        download_url="${PRECOMPILED_URL_X86_64}"
    elif [[ "$arch" == "aarch64" ]]; then
        download_url="${PRECOMPILED_URL_AARCH64}"
    else
        log_error "不支持的架构: $arch"
        exit 1
    fi

    # 使用代理下载
    download_url="${GH_PROXY}${download_url}"
    
    wget_wrapper "${download_url}" "/usr/local/bin/qbittorrent-nox"

    if [ ! -f "/usr/local/bin/qbittorrent-nox" ]; then
        log_error "下载预编译文件失败！"
        exit 1
    fi

    chmod +x /usr/local/bin/qbittorrent-nox
    log_info "qBittorrent-nox v${QB_VERSION} 已安装到 /usr/local/bin/"
}

# 编译安装 libtorrent
compile_libtorrent() {
    log_cyan "编译安装 libtorrent v${LT_VERSION} (这可能需要很长时间)..."
    cd /tmp
    wget_wrapper "${GH_PROXY}https://github.com/arvidn/libtorrent/releases/download/v${LT_VERSION}/libtorrent-rasterbar-${LT_VERSION}.tar.gz" "libtorrent-rasterbar-${LT_VERSION}.tar.gz"
    tar xf libtorrent-rasterbar-${LT_VERSION}.tar.gz
    cd libtorrent-rasterbar-${LT_VERSION}
    ./configure --prefix=/usr/local --disable-debug --enable-encryption --with-libiconv CXXFLAGS="-std=c++17"
    make -j$(nproc)
    make install
    ldconfig
    log_info "libtorrent 安装完成。"
}

# 编译安装 qBittorrent
compile_qbittorrent() {
    log_cyan "编译安装 qBittorrent v${QB_VERSION} (这可能需要很长时间)..."
    cd /tmp
    wget_wrapper "${GH_PROXY}https://github.com/qbittorrent/qBittorrent/archive/refs/tags/release-${QB_VERSION}.tar.gz" "qbittorrent-${QB_VERSION}.tar.gz"
    tar xf qbittorrent-${QB_VERSION}.tar.gz
    cd qBittorrent-release-${QB_VERSION}
    ./configure --prefix=/usr/local --disable-gui --enable-systemd CXXFLAGS="-std=c++17"
    make -j$(nproc)
    make install
    log_info "qBittorrent 安装完成。"
}

# 创建用户和目录
create_user_and_dirs() {
    log_cyan "创建 qbittorrent 用户和相关目录..."
    if id "qbittorrent" &>/dev/null; then
        log_warn "用户 'qbittorrent' 已存在，将跳过创建。"
    else
        useradd --system --shell /usr/sbin/nologin --home-dir /home/qbittorrent --create-home qbittorrent
        log_info "用户 'qbittorrent' 创建成功。"
    fi

    mkdir -p /home/qbittorrent/.config/qBittorrent
    mkdir -p /home/qbittorrent/downloads
    chown -R qbittorrent:qbittorrent /home/qbittorrent
    chmod -R 750 /home/qbittorrent
    log_info "目录权限设置完成。"
}

# 创建配置文件
create_config_file() {
    log_cyan "创建 qBittorrent 配置文件..."
    local conf_file="/home/qbittorrent/.config/qBittorrent/qBittorrent.conf"
    
    if [ -f "$conf_file" ]; then
        log_warn "配置文件已存在，将进行备份并创建新配置。"
        mv "$conf_file" "${conf_file}.bak.$(date +%s)"
    fi

    cat > "$conf_file" << EOF
[Preferences]
WebUI\Port=8080
WebUI\Username=admin
# 默认密码 adminadmin
WebUI\Password_PBKDF2="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)"
WebUI\LocalHostAuth=false
Downloads\SavePath=/home/qbittorrent/downloads
Downloads\TempPathEnabled=false
Connection\PortRangeMin=8999
Connection\PortRangeMax=8999
EOF

    chown qbittorrent:qbittorrent "$conf_file"
    chmod 600 "$conf_file"
    log_info "配置文件创建成功。默认密码: adminadmin"
}

# 创建 systemd 服务
create_systemd_service() {
    log_cyan "创建 systemd 服务..."
    cat > /etc/systemd/system/qbittorrent.service << EOF
[Unit]
Description=qBittorrent-nox Command Line Client
After=network.target

[Service]
Type=forking
User=qbittorrent
Group=qbittorrent
UMask=007
ExecStart=/usr/local/bin/qbittorrent-nox --daemon --webui-port=8080 --profile=/home/qbittorrent
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable qbittorrent
    log_info "systemd 服务创建并已设置为开机自启。"
}

# 配置防火墙
configure_firewall() {
    log_cyan "配置防火墙..."
    if command -v ufw &> /dev/null; then
        ufw allow 8080/tcp comment 'qB WebUI'
        ufw allow 8999/tcp comment 'qB Peer-TCP'
        ufw allow 8999/udp comment 'qB Peer-UDP'
        log_info "UFW 防火墙规则已添加。"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=8999/tcp
        firewall-cmd --permanent --add-port=8999/udp
        firewall-cmd --reload
        log_info "Firewalld 防火墙规则已添加。"
    else
        log_warn "未检测到 UFW 或 Firewalld，请手动开放端口 8080 和 8999。"
    fi
}

# 清理临时文件
cleanup() {
    log_cyan "清理临时文件..."
    rm -rf /tmp/libtorrent-rasterbar-*
    rm -rf /tmp/qBittorrent-release-*
    log_info "清理完成。"
}

# 显示最终结果
show_result() {
    local server_ip
    server_ip=$(curl -s --fail --connect-timeout 2 ip.sb || ip -4 addr | grep inet | grep -vE '127.0.0.1|172.' | awk '{print $2}' | cut -d'/' -f1 | head -n1)
    
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║             qBittorrent-nox 安装成功!                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}WebUI 地址: ${WHITE}http://${server_ip}:8080${NC}"
    echo -e "${CYAN}用户名:     ${WHITE}admin${NC}"
    echo -e "${CYAN}密  码:     ${WHITE}adminadmin${NC}"
    echo ""
    echo -e "${CYAN}下载目录:   ${WHITE}/home/qbittorrent/downloads${NC}"
    echo -e "${CYAN}配置文件:   ${WHITE}/home/qbittorrent/.config/qBittorrent/qBittorrent.conf${NC}"
    echo ""
    echo -e "${YELLOW}重要提示: 请立即登录WebUI并修改默认的用户名和密码！${NC}"
    echo ""
    echo -e "常用命令:"
    echo -e "  启动服务: ${WHITE}systemctl start qbittorrent${NC}"
    echo -e "  停止服务: ${WHITE}systemctl stop qbittorrent${NC}"
    echo -e "  查看状态: ${WHITE}systemctl status qbittorrent${NC}"
    echo ""
}


# 主函数
main() {
    check_root
    check_system
    
    # 交互式选择安装模式
    if [[ -t 0 ]]; then # 判断是否在交互式终端中运行
        read -p "$(echo -e ${BLUE}"请选择安装模式 [1]极速安装 (默认) [2]编译安装: "${NC})" choice
        case "$choice" in
            2)
                INSTALL_MODE="compile"
                log_info "已选择 [编译安装] 模式。"
                ;;
            *)
                INSTALL_MODE="fast"
                log_info "已选择 [极速安装] 模式。"
                ;;
        esac
    else
        log_info "非交互式环境，将使用默认模式: [${INSTALL_MODE}]"
    fi
    
    install_dependencies
    
    if [ "$INSTALL_MODE" = "compile" ]; then
        compile_libtorrent
        compile_qbittorrent
    else
        fast_install_qbittorrent
    fi

    create_user_and_dirs
    create_config_file
    create_systemd_service
    configure_firewall
    
    log_cyan "正在启动 qBittorrent 服务..."
    systemctl restart qbittorrent
    sleep 3

    if ! systemctl is-active --quiet qbittorrent; then
        log_error "qBittorrent 服务启动失败！"
        log_warn "请使用 'systemctl status qbittorrent' 和 'journalctl -u qbittorrent -n 50' 查看详细日志。"
        exit 1
    fi
    
    cleanup
    show_result
}

# --- 脚本入口 ---
main "$@"
