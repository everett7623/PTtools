#!/usr/bin/env bash

#================================================================
#   
#   项目名称：qBittorrent 4.3.9 编译安装脚本 (优化版)
#   功能描述：为 PTtools 项目提供一个健壮、优化且独立的 qb 安装程序
#   作    者：everett7623 (基于社区脚本优化)
#   Github：https://github.com/everett7623/PTtools
#   版    本：v2.0.0
#
#================================================================

# --- 脚本设置 ---
# 如果任何命令返回非零退出状态，立即退出
set -e
# 如果管道中的任何命令失败，则整个管道的退出状态为非零
set -o pipefail

# --- 字体颜色定义 ---
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"
PLAIN="\033[0m"

# --- 默认参数 ---
QB_USER="admin"
QB_PASS="" # 将在后面生成随机密码
QB_CACHE=2048 # 单位 MB
QB_WEBUI_PORT=8080
QB_INCOMING_PORT=23333
QB_VERSION="4.3.9"
LIBTORRENT_VERSION="1.2.19" # 与 qb 4.3.9 兼容性较好的版本
SYSTEM_USER="qb" # 用于运行服务的系统账户
DOWNLOADS_DIR="/opt/downloads"
CONFIG_DIR="/home/${SYSTEM_USER}/.config/qBittorrent"
DATA_DIR="/home/${SYSTEM_USER}/.local/share/data/qBittorrent"
ENABLE_BBR=false

# --- 工具函数 ---

# 统一输出函数
msg() {
    local type="$1"
    local message="$2"
    case "$type" in
        "info") echo -e "${BLUE}[信息]${PLAIN} ${message}" ;;
        "success") echo -e "${GREEN}[成功]${PLAIN} ${message}" ;;
        "warn") echo -e "${YELLOW}[警告]${PLAIN} ${message}" ;;
        "error") echo -e "${RED}[错误]${PLAIN} ${message}" ;;
        "title") echo -e "\n${YELLOW}================= ${message} =================${PLAIN}" ;;
        *) echo "${message}" ;;
    esac
}

# 帮助菜单
show_help() {
    msg "info" "用法: $0 [选项]"
    echo "选项:"
    echo "  -u, --user <username>       设置 qBittorrent WebUI 用户名 (默认: admin)"
    echo "  -p, --password <password>   设置 qBittorrent WebUI 密码 (默认: 自动生成)"
    echo "  -c, --cache <size_mb>       设置磁盘写入缓存大小 (MB) (默认: 2048)"
    echo "  --web-port <port>           设置 WebUI 端口 (默认: 8080)"
    echo "  --bt-port <port>            设置 BT 传入端口 (默认: 23333)"
    echo "  -b, --bbr                   启用 BBR 网络优化"
    echo "  -h, --help                  显示此帮助菜单"
    exit 0
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user) QB_USER="$2"; shift 2 ;;
            -p|--password) QB_PASS="$2"; shift 2 ;;
            -c|--cache) QB_CACHE="$2"; shift 2 ;;
            --web-port) QB_WEBUI_PORT="$2"; shift 2 ;;
            --bt-port) QB_INCOMING_PORT="$2"; shift 2 ;;
            -b|--bbr) ENABLE_BBR=true; shift ;;
            -h|--help) show_help ;;
            *) msg "error" "未知参数: $1"; show_help ;;
        esac
    done
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg "error" "此脚本需要以 root 权限运行！"
        exit 1
    fi
}

# 检查操作系统
check_os() {
    if ! grep -qiE "debian|ubuntu" /etc/os-release; then
        msg "error" "此脚本仅支持 Debian 和 Ubuntu 系统。"
        exit 1
    fi
    msg "success" "操作系统检查通过。"
}

# 安装依赖
install_dependencies() {
    msg "title" "更新软件源并安装依赖"
    apt-get update
    apt-get install -y \
        build-essential pkg-config automake libtool \
        cmake git curl wget \
        libboost-dev libboost-system-dev libboost-chrono-dev \
        libboost-random-dev libssl-dev zlib1g-dev \
        qtbase5-dev qttools5-dev-tools libqt5svg5-dev \
        python3-dev python3-setuptools
    msg "success" "所有依赖包已安装。"
}

# 系统网络优化
system_tuning() {
    msg "title" "进行系统网络优化"
    # 移除旧的配置，避免重复
    sed -i '/# qBittorrent-tuning-start/,/# qBittorrent-tuning-end/d' /etc/sysctl.conf
    
    cat >> /etc/sysctl.conf <<EOF
# qBittorrent-tuning-start
# 增大TCP连接队列
net.core.somaxconn = 262144
# 增大网络设备接收队列
net.core.netdev_max_backlog = 262144
# 增大TCP读写缓冲区
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
# 启用TCP窗口缩放和时间戳
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
# 允许TCP连接快速回收
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
# qBittorrent-tuning-end
EOF

    if [[ "$ENABLE_BBR" = true ]]; then
        msg "info" "启用 BBR..."
        sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    fi
    
    sysctl -p
    msg "success" "系统内核参数优化完成。"

    msg "info" "提高文件描述符限制..."
    sed -i '/# qb-file-limit/d' /etc/security/limits.conf
    echo "* soft nofile 65536 # qb-file-limit" >> /etc/security/limits.conf
    echo "* hard nofile 65536 # qb-file-limit" >> /etc/security/limits.conf
    msg "success" "文件描述符限制已设置。"
}

# 创建专用系统用户
create_system_user() {
    msg "title" "创建专用系统用户"
    if id "$SYSTEM_USER" &>/dev/null; then
        msg "info" "用户 ${SYSTEM_USER} 已存在，跳过创建。"
    else
        useradd -r -m -s /usr/sbin/nologin "$SYSTEM_USER"
        msg "success" "成功创建用户: ${SYSTEM_USER}"
    fi
}

# 编译安装 libtorrent
compile_libtorrent() {
    msg "title" "编译安装 libtorrent v${LIBTORRENT_VERSION}"
    cd /tmp
    if [[ ! -d "libtorrent" ]]; then
        git clone --depth 1 --branch "v${LIBTORRENT_VERSION}" https://github.com/arvidn/libtorrent.git
    fi
    cd libtorrent
    ./bootstrap.sh
    ./configure --prefix=/usr \
        --enable-static=no \
        --with-libiconv \
        --with-boost-system=mt \
        --with-libssl \
        CXXFLAGS="-O3 -g" CFLAGS="-O3 -g"
        
    make -j"$(nproc)"
    make install
    ldconfig
    msg "success" "libtorrent-rasterbar 编译安装完成。"
}

# 编译安装 qBittorrent
compile_qbittorrent() {
    msg "title" "编译安装 qBittorrent v${QB_VERSION}"
    cd /tmp
    if [[ ! -d "qBittorrent" ]]; then
        git clone --depth 1 --branch "release-${QB_VERSION}" https://github.com/qbittorrent/qBittorrent.git
    fi
    cd qBittorrent
    ./configure --prefix=/usr \
        --disable-gui \
        --enable-systemd \
        --with-boost-libdir=/usr/lib/x86_64-linux-gnu
    
    make -j"$(nproc)"
    make install
    msg "success" "qBittorrent-nox 编译安装完成。"
}

# 创建配置文件
create_config_file() {
    msg "title" "生成 qBittorrent 配置文件"
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${DATA_DIR}"
    mkdir -p "${DOWNLOADS_DIR}"

    # 生成高强度随机密码
    if [[ -z "${QB_PASS}" ]]; then
        QB_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
        msg "warn" "未提供密码，已为您生成一个随机密码。"
    fi
    
    # 使用 qbittorrent-nox 自身生成带密码哈希的配置，这是最安全的方式
    /usr/bin/qbittorrent-nox --export-conf="${CONFIG_DIR}/qBittorrent.conf" --webui-port=-1 --profile="${CONFIG_DIR}"
    
    # 停止临时进程 (如果它还在运行)
    pkill -f "qbittorrent-nox --export-conf" || true
    sleep 1

    # 在生成的配置基础上应用优化
    cat > "${CONFIG_DIR}/qBittorrent.conf" << EOF
[Application]
FileLogger\Enabled=false

[BitTorrent]
Session\AnnounceToAllTiers=true
Session\AsyncIOThreadsCount=16
Session\CheckingMemUsageSize=${QB_CACHE}
Session\FilePoolSize=100
Session\SendBufferWatermark=10240
Session\SendBufferLowWatermark=2048
Session\SendBufferWatermarkFactor=150
Session\SocketBacklogSize=200
Session\UseOSCache=false
Session\UploadChokingAlgorithm=AntiLeech

[Preferences]
Advanced\AnnounceToAllTrackers=true
Advanced\RecheckOnCompletion=false
Connection\PortRangeMin=${QB_INCOMING_PORT}
Downloads\DiskWriteCacheSize=${QB_CACHE}
Downloads\DiskWriteCacheTTL=60
Downloads\SavePath=${DOWNLOADS_DIR}
Queueing\QueueingSystemEnabled=false
WebUI\Address=*
WebUI\Port=${QB_WEBUI_PORT}
WebUI\Username=${QB_USER}
EOF

    # 使用 qbittorrent-nox 的 --password-hash 参数设置密码 (v4.2.0+ 支持)
    # 这是比手动修改配置文件更安全的方式，但需要先启动一次。
    # 更简单的方法是让用户首次登录后修改。这里我们先设置好，然后通过systemd启动。
    # 由于直接生成PBKDF2哈希在bash中很复杂，我们采用让程序自管理的方式。
    # 以上配置已写入用户名，但密码需在首次运行时由程序处理。
    # 为了更稳定，我们直接写入，但需注意此方法可能在未来版本变化。
    QB_PASS_HASH=$(/usr/bin/qbittorrent-nox --password-hash="${QB_PASS}")
    echo "WebUI\Password_PBKDF2=${QB_PASS_HASH}" >> "${CONFIG_DIR}/qBittorrent.conf"

    chown -R "${SYSTEM_USER}:${SYSTEM_USER}" "/home/${SYSTEM_USER}"
    chown -R "${SYSTEM_USER}:${SYSTEM_USER}" "${DOWNLOADS_DIR}"
    msg "success" "配置文件创建并优化完成。"
}

# 创建 systemd 服务
create_systemd_service() {
    msg "title" "创建 systemd 服务"
    cat > /etc/systemd/system/qb.service << EOF
[Unit]
Description=qBittorrent-nox Daemon
Documentation=man:qbittorrent-nox(1)
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=forking
User=${SYSTEM_USER}
Group=${SYSTEM_USER}
UMask=0007
ExecStart=/usr/bin/qbittorrent-nox --daemon --profile=/home/${SYSTEM_USER}
Restart=on-failure
RestartSec=5
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    msg "success" "systemd 服务 (qb.service) 创建成功。"
}


# --- 主程序 ---
main() {
    check_root
    check_os
    parse_args "$@"

    # 显示将要执行的配置
    msg "title" "安装配置预览"
    echo "qBittorrent 版本: ${QB_VERSION}"
    echo "libtorrent 版本: ${LIBTORRENT_VERSION}"
    echo "WebUI 用户名: ${QB_USER}"
    echo "WebUI 端口: ${QB_WEBUI_PORT}"
    echo "缓存大小: ${QB_CACHE} MB"
    echo "下载目录: ${DOWNLOADS_DIR}"
    echo "系统服务用户: ${SYSTEM_USER}"
    [[ "$ENABLE_BBR" = true ]] && echo "BBR 优化: 启用"
    echo "-----------------------------------------------"
    read -rp "确认开始安装吗? [Y/n]: " confirm
    if [[ "${confirm}" =~ ^[nN]$ ]]; then
        msg "info" "操作已取消。"
        exit 0
    fi

    # 执行安装步骤
    install_dependencies
    system_tuning
    create_system_user
    compile_libtorrent
    compile_qbittorrent
    create_config_file
    create_systemd_service

    # 启动服务
    msg "title" "启动并验证服务"
    systemctl enable qb.service
    systemctl start qb.service

    sleep 5
    if systemctl is-active --quiet qb; then
        PUBLIC_IP=$(curl -s4 https://ipinfo.io/ip)
        msg "success" "qBittorrent 安装成功并已启动！"
        msg "title" "访问信息"
        echo -e "WebUI 地址: ${GREEN}http://${PUBLIC_IP}:${QB_WEBUI_PORT}${PLAIN}"
        echo -e "用户名:    ${GREEN}${QB_USER}${PLAIN}"
        echo -e "密码:        ${GREEN}${QB_PASS}${PLAIN} ${YELLOW}(如果是随机生成的，请妥善保管)${PLAIN}"
        echo -e "下载目录:   ${GREEN}${DOWNLOADS_DIR}${PLAIN}"
    else
        msg "error" "qBittorrent 服务启动失败！"
        msg "info" "请运行 'journalctl -u qb --no-pager -l' 查看详细日志。"
        exit 1
    fi
}

# 脚本入口
main "$@"
