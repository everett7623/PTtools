#!/usr/bin/env bash

#================================================================
#   
#   项目名称：qBittorrent 4.3.8 二进制安装脚本 (优化版)
#   功能描述：为 PTtools 项目提供一个健壮、优化且独立的 qb 4.3.8 安装程序
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
QB_WEBUI_PORT=8080
QB_INCOMING_PORT=23333
SYSTEM_USER="qb438" # 用于运行服务的系统账户
DOWNLOADS_DIR="/opt/downloads"
CONFIG_DIR="/home/${SYSTEM_USER}/.config/qBittorrent"
ENABLE_BBR=true # 默认开启BBR

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
    echo "  --web-port <port>           设置 WebUI 端口 (默认: 8080)"
    echo "  --bt-port <port>            设置 BT 传入端口 (默认: 23333)"
    echo "  --no-bbr                    禁用 BBR 网络优化"
    echo "  -h, --help                  显示此帮助菜单"
    exit 0
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user) QB_USER="$2"; shift 2 ;;
            -p|--password) QB_PASS="$2"; shift 2 ;;
            --web-port) QB_WEBUI_PORT="$2"; shift 2 ;;
            --bt-port) QB_INCOMING_PORT="$2"; shift 2 ;;
            --no-bbr) ENABLE_BBR=false; shift ;;
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
    apt-get install -y wget curl # 基础依赖
    msg "success" "依赖包已安装。"
}

# 系统网络优化
system_tuning() {
    if [[ "$ENABLE_BBR" = false ]]; then
        msg "info" "用户已禁用BBR，跳过网络优化。"
        return
    fi
    
    msg "title" "进行系统网络优化 (BBR)"
    # 移除旧的配置，避免重复
    sed -i '/# qBittorrent-tuning-start/,/# qBittorrent-tuning-end/d' /etc/sysctl.conf
    
    cat >> /etc/sysctl.conf <<EOF
# qBittorrent-tuning-start
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
# qBittorrent-tuning-end
EOF
    sysctl -p
    msg "success" "BBR 网络优化已启用。"
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

# 下载并安装 qBittorrent-nox 二进制文件
download_and_install_qb() {
    msg "title" "下载并安装 qBittorrent-nox v4.3.8"
    
    local system_arch
    system_arch=$(uname -m)
    local download_url=""
    
    if [[ "$system_arch" == "x86_64" ]]; then
        download_url="https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox"
    elif [[ "$system_arch" == "aarch64" ]]; then
        download_url="https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox"
    else
        msg "error" "不支持的系统架构: ${system_arch}。脚本退出。"
        exit 1
    fi

    msg "info" "正在从 GitHub 下载预编译的二进制文件..."
    wget -qO /usr/bin/qbittorrent-nox "$download_url"
    chmod +x /usr/bin/qbittorrent-nox
    msg "success" "qBittorrent-nox v4.3.8 安装完成。"
}

# 创建配置文件
create_config_file() {
    msg "title" "生成 qBittorrent 配置文件"
    mkdir -p "${CONFIG_DIR}"
    
    # 生成高强度随机密码
    if [[ -z "${QB_PASS}" ]]; then
        QB_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
        msg "warn" "未提供密码，已为您生成一个随机密码。"
    fi

    # qBittorrent v4.3.x 使用 MD5 哈希存储密码
    local pass_hash
    pass_hash=$(echo -n "${QB_PASS}" | md5sum | cut -d' ' -f1)

    # 直接生成完整的优化配置文件
    cat > "${CONFIG_DIR}/qBittorrent.conf" << EOF
[LegalNotice]
Accepted=true

[Preferences]
Connection\PortRangeMin=${QB_INCOMING_PORT}
Downloads\PreAllocation=false
Downloads\SavePath=${DOWNLOADS_DIR}
General\Locale=zh
WebUI\Address=*
WebUI\CSRFProtection=false
WebUI\Port=${QB_WEBUI_PORT}
WebUI\Username=${QB_USER}
WebUI\Password_ha1=@ByteArray(${pass_hash})
EOF

    chown -R "${SYSTEM_USER}:${SYSTEM_USER}" "/home/${SYSTEM_USER}"
    mkdir -p "${DOWNLOADS_DIR}"
    chown -R "${SYSTEM_USER}:${SYSTEM_USER}" "${DOWNLOADS_DIR}"
    msg "success" "配置文件创建完成。"
}

# 创建 systemd 服务
create_systemd_service() {
    msg "title" "创建 systemd 服务"
    cat > /etc/systemd/system/qb438.service << EOF
[Unit]
Description=qBittorrent-nox Daemon (v4.3.8)
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=forking
User=${SYSTEM_USER}
Group=${SYSTEM_USER}
UMask=0022
ExecStart=/usr/bin/qbittorrent-nox -d --profile=/home/${SYSTEM_USER}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    msg "success" "systemd 服务 (qb438.service) 创建成功。"
}


# --- 主程序 ---
main() {
    check_root
    check_os
    parse_args "$@"

    msg "title" "安装配置预览"
    echo "qBittorrent 版本: 4.3.8"
    echo "WebUI 用户名: ${QB_USER}"
    echo "WebUI 端口: ${QB_WEBUI_PORT}"
    echo "下载目录: ${DOWNLOADS_DIR}"
    echo "系统服务用户: ${SYSTEM_USER}"
    [[ "$ENABLE_BBR" = true ]] && echo "BBR 优化: 启用" || echo "BBR 优化: 禁用"
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
    download_and_install_qb
    create_config_file
    create_systemd_service

    # 启动服务
    msg "title" "启动并验证服务"
    systemctl enable qb438.service
    systemctl start qb438.service

    sleep 5
    if systemctl is-active --quiet qb438; then
        PUBLIC_IP=$(curl -s4 https://ipinfo.io/ip)
        msg "success" "qBittorrent v4.3.8 安装成功并已启动！"
        msg "title" "访问信息"
        echo -e "WebUI 地址: ${GREEN}http://${PUBLIC_IP}:${QB_WEBUI_PORT}${PLAIN}"
        echo -e "用户名:    ${GREEN}${QB_USER}${PLAIN}"
        echo -e "密码:        ${GREEN}${QB_PASS}${PLAIN} ${YELLOW}(如果是随机生成的，请妥善保管)${PLAIN}"
        echo -e "下载目录:   ${GREEN}${DOWNLOADS_DIR}${PLAIN}"
    else
        msg "error" "qBittorrent 服务启动失败！"
        msg "info" "请运行 'journalctl -u qb438 --no-pager -l' 查看详细日志。"
        exit 1
    fi
    
    msg "info" "安装脚本执行完毕。没有进行自动重启。"
}

# 脚本入口
main "$@"
