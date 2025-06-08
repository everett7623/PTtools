#!/bin/bash

#======================================================================================
#   qBittorrent 4.3.8 安装脚本
#   - 修改自: https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh
#
# 特性:
#   - 仅保留极速安装模式，去除编译相关代码，脚本更轻量。
#   - 默认使用静态编译的 qBittorrent-nox，以减少对系统库的依赖。
#   - 自动检测系统架构 (x86_64, aarch64)。
#   - 使用多个下载代理，提高国内服务器的下载成功率。
#   - 包含自动依赖验证 (ldd)、用户创建、服务配置等最佳实践。
#
#======================================================================================

# --- 配置区 ---
# qBittorrent 版本 - 这个版本需要与下面的下载链接匹配
QB_VERSION="4.6.5"
LT_VERSION="1.2.20" # libtorrent 版本信息仅供参考

# 预编译文件的下载地址 (静态链接版本，兼容性更好)
# 来源: https://github.com/userdocs/qbittorrent-nox-static
PRECOMPILED_URL_X86_64="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v${LT_VERSION}/x86_64-qbittorrent-nox"
PRECOMPILED_URL_AARCH64="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v${LT_VERSION}/aarch64-qbittorrent-nox"

# GitHub 资源下载代理列表 (按顺序尝试)
GH_PROXIES=("https://ghproxy.com/" "https://gh.api.99988866.xyz/")

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
    # $1: 下载URL, $2: 保存路径
    log_info "正在下载: $1"
    # 返回 true/false, 以便循环处理
    wget -q --show-progress --progress=bar:force:noscroll --tries=2 --timeout=60 -O "$2" "$1"
}

# 安装最基本的依赖
install_dependencies() {
    log_cyan "正在安装核心依赖..."
    case "$OS" in
        debian|ubuntu)
            apt-get update -qq
            # ldd 用于依赖检查, curl 用于获取IP
            apt-get install -y --no-install-recommends libc-bin curl
            ;;
        centos|rhel)
            # 静态版本几乎无依赖，只需基本工具
            yum install -y glibc-common curl
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
    log_info "依赖安装完成。"
}

# 验证二进制文件依赖
verify_binary_dependencies() {
    log_cyan "正在验证二进制文件依赖..."
    local binary_path="/usr/local/bin/qbittorrent-nox"
    if ! command -v ldd &> /dev/null; then
        log_warn "'ldd' 命令不可用，无法检查动态库依赖。将跳过此步骤。"
        return
    fi

    # 使用ldd和grep查找“not found”的库
    local missing_libs
    missing_libs=$(ldd "$binary_path" 2>/dev/null | grep -i 'not found')

    if [ -n "$missing_libs" ]; then
        log_error "依赖检查失败！预编译的 qbittorrent-nox 缺少以下库:"
        echo -e "${RED}${missing_libs}${NC}"
        log_error "这通常意味着您的系统环境过于老旧。"
        log_error "请尝试更新您的系统，或寻找其他兼容的预编译版本。"
        exit 1
    else
        log_info "依赖检查通过，二进制文件兼容当前系统。"
    fi
}

# 极速安装 (下载预编译文件)
fast_install_qbittorrent() {
    log_cyan "开始极速安装 qBittorrent..."
    local arch
    arch=$(uname -m)
    local primary_url

    if [[ "$arch" == "x86_64" ]]; then
        primary_url="${PRECOMPILED_URL_X86_64}"
    elif [[ "$arch" == "aarch64" ]]; then
        primary_url="${PRECOMPILED_URL_AARCH64}"
    else
        log_error "不支持的CPU架构: $arch"
        exit 1
    fi

    local download_success=false
    for proxy in "${GH_PROXIES[@]}"; do
        local full_url="${proxy}${primary_url}"
        log_info "尝试从代理下载: ${proxy}"
        if wget_wrapper "${full_url}" "/usr/local/bin/qbittorrent-nox"; then
            download_success=true
            break
        else
            log_warn "通过代理 ${proxy} 下载失败，正在尝试下一个..."
        fi
    done

    if [ "$download_success" = false ]; then
        log_error "从所有代理下载预编译文件均失败！请检查您的网络连接或稍后再试。"
        exit 1
    fi

    chmod +x /usr/local/bin/qbittorrent-nox
    log_info "qBittorrent-nox v${QB_VERSION} 已下载到 /usr/local/bin/"

    verify_binary_dependencies
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
RestartSec=5

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
        ufw allow 8080/tcp comment 'qB WebUI' >/dev/null
        ufw allow 8999/tcp comment 'qB Peer-TCP' >/dev/null
        ufw allow 8999/udp comment 'qB Peer-UDP' >/dev/null
        log_info "UFW 防火墙规则已添加 (端口 8080, 8999)。"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8080/tcp >/dev/null
        firewall-cmd --permanent --add-port=8999/tcp >/dev/null
        firewall-cmd --permanent --add-port=8999/udp >/dev/null
        firewall-cmd --reload
        log_info "Firewalld 防火墙规则已添加 (端口 8080, 8999)。"
    else
        log_warn "未检测到 UFW 或 Firewalld，请手动开放端口 8080 和 8999。"
    fi
}

# 显示最终结果
show_result() {
    local server_ip
    server_ip=$(curl -s --fail --connect-timeout 3 ip.sb || ip -4 addr | grep inet | grep -vE '127.0.0.1|172.' | awk '{print $2}' | cut -d'/' -f1 | head -n1)
    
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
    install_dependencies
    fast_install_qbittorrent
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
    
    show_result
}

# --- 脚本入口 ---
main "$@"
