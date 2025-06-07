#!/bin/bash

# qBittorrent 4.3.8 Installation Script for VPS (Debian/Ubuntu based)
# This script installs qBittorrent-nox from PPA, sets up a user, and configures basic settings.

# --- Configuration ---
QB_USER="qbittorrent"
QB_HOME_DIR="/home/$QB_USER"
QB_CONFIG_DIR="$QB_HOME_DIR/.config/qBittorrent"
QB_DOWNLOAD_DIR="/opt/downloads" # As per your main script's default

QB_WEBUI_PORT="8080"
QB_WEBUI_USERNAME="admin"
# For security, prompt for password instead of hardcoding or using a default
# Default if user doesn't enter: adminadmin
QB_WEBUI_PASSWORD_DEFAULT="adminadmin"

# --- Functions ---

# Print info message
print_info() {
    echo -e "\e[1;32m[INFO]\e[0m $1"
}

# Print error message
print_error() {
    echo -e "\e[1;31m[ERROR]\e[0m $1"
}

# Print warning message
print_warning() {
    echo -e "\e[1;33m[WARNING]\e[0m $1"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Pre-checks and Setup ---

print_info "开始安装 qBittorrent 4.3.8..."

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    print_error "此脚本需要root权限运行。请使用 sudo 或以 root 用户身份运行。"
    exit 1
fi

# Determine OS and install necessary packages
if command_exists apt; then
    print_info "检测到 Debian/Ubuntu 系统。"
    apt update || { print_error "apt update 失败。请检查网络或软件源。"; exit 1; }
    apt install -y software-properties-common wget curl ca-certificates gnupg2 || \
        { print_error "安装基本依赖失败。"; exit 1; }
elif command_exists yum; then
    print_error "CentOS/RHEL 系统暂不支持 PPA 安装 qBittorrent-nox。请手动安装或使用 Docker 版本。"
    exit 1
else
    print_error "不支持的操作系统类型。请手动安装 qBittorrent-nox。"
    exit 1
fi

# --- User Setup ---
print_info "创建 qBittorrent 运行用户: ${QB_USER}..."
id -u "$QB_USER" &>/dev/null || adduser --system --no-create-home --shell /bin/false "$QB_USER"

# Create necessary directories and set permissions
print_info "创建下载目录 ${QB_DOWNLOAD_DIR} 和配置目录 ${QB_CONFIG_DIR}..."
mkdir -p "${QB_DOWNLOAD_DIR}" "${QB_CONFIG_DIR}"
chown -R "${QB_USER}:${QB_USER}" "${QB_DOWNLOAD_DIR}" "${QB_CONFIG_DIR}"
chmod -R 777 "${QB_DOWNLOAD_DIR}" # Ensure download path has full access for all users for torrent client
chmod -R 755 "${QB_CONFIG_DIR}"

# --- Install qBittorrent-nox ---
print_info "添加 qBittorrent PPA 并安装 qBittorrent-nox..."
add-apt-repository ppa:qbittorrent-team/qbittorrent-stable -y || { print_error "添加 PPA 失败。"; exit 1; }
apt update || { print_error "apt update (PPA 后) 失败。"; exit 1; }
apt install -y qbittorrent-nox || { print_error "安装 qbittorrent-nox 失败。"; exit 1; }

# --- Configure qBittorrent-nox Systemd Service ---
print_info "配置 qBittorrent-nox systemd 服务..."
cat <<EOF > /etc/systemd/system/qbittorrent.service
[Unit]
Description=qBittorrent Command Line Client
After=network.target

[Service]
Type=forking
User=${QB_USER}
ExecStart=/usr/bin/qbittorrent-nox --webui-port=${QB_WEBUI_PORT}
ExecStop=/usr/bin/killall -w qbittorrent-nox
Restart=on-failure
WorkingDirectory=${QB_HOME_DIR}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable qbittorrent || { print_error "启用 qbittorrent 服务失败。"; exit 1; }

# --- Initial qBittorrent Config (optional but recommended) ---
# This part is a bit tricky as qBittorrent-nox needs to be run once to generate default config.
# Or we can manually create a basic config.
# Let's create a minimal config file to set download path and initial webui user/pass.

print_info "设置 qBittorrent Web UI 用户名和密码..."
read -p "请输入 qBittorrent Web UI 的密码 (留空则使用默认密码 ${QB_WEBUI_PASSWORD_DEFAULT}): " user_input_password
QB_WEBUI_PASSWORD=${user_input_password:-$QB_WEBUI_PASSWORD_DEFAULT}

# Hash the password. For qBittorrent 4.3.x, it's SHA1
QB_WEBUI_PASSWORD_HASH=$(echo -n "${QB_WEBUI_PASSWORD}" | sha1sum | awk '{print $1}')

cat <<EOF > "${QB_CONFIG_DIR}/qBittorrent.conf"
[LegalNotice]
Accepted=true

[Preferences]
Bittorrent/Session/Port=25000
Downloads/SavePath=${QB_DOWNLOAD_DIR}/
WebUI/AuthSubnetWhitelist=*
WebUI/Port=${QB_WEBUI_PORT}
WebUI/Username=${QB_WEBUI_USERNAME}
WebUI/Password_HB=${QB_WEBUI_PASSWORD_HASH}
WebUI/CSRFProtection=false # Set to true after initial setup if exposed to public
EOF

chown "${QB_USER}:${QB_USER}" "${QB_CONFIG_DIR}/qBittorrent.conf"
chmod 600 "${QB_CONFIG_DIR}/qBittorrent.conf" # Only owner can read/write

# --- Start qBittorrent Service ---
print_info "启动 qBittorrent 服务..."
systemctl start qbittorrent || { print_error "启动 qbittorrent 服务失败。"; exit 1; }
sleep 5 # Give it a moment to start

# --- Firewall Configuration ---
print_info "配置防火墙规则..."

# Install iptables-persistent if not installed
if ! command_exists iptables-save; then
    print_info "安装 iptables-persistent 以保存防火墙规则..."
    DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent || { print_error "安装 iptables-persistent 失败。"; }
fi

if command_exists iptables; then
    print_info "添加防火墙规则 (允许 qBittorrent Web UI 端口 ${QB_WEBUI_PORT} 和 BT 端口 25000)..."
    iptables -A INPUT -p tcp --dport "${QB_WEBUI_PORT}" -j ACCEPT
    iptables -A INPUT -p udp --dport "${QB_WEBUI_PORT}" -j ACCEPT # UDP for WebUI (if enabled, though mostly TCP)
    iptables -A INPUT -p tcp --dport 25000 -j ACCEPT
    iptables -A INPUT -p udp --dport 25000 -j ACCEPT

    # Save iptables rules
    if command_exists netfilter-persistent; then
        print_info "保存 iptables 规则..."
        netfilter-persistent save || print_warning "保存 iptables 规则失败，可能需要手动保存或检查 netfilter-persistent。"
    elif command_exists iptables-save; then
        print_info "保存 iptables 规则到 /etc/iptables/rules.v4..."
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4 || print_warning "保存 iptables 规则到 rules.v4 失败。"
    else
        print_warning "未找到保存 iptables 规则的工具。请手动保存防火墙规则，否则重启后会失效。"
    fi
else
    print_warning "未检测到 iptables 命令。请手动配置防火墙。"
fi

# --- Post-installation Information ---
print_info "等待 qBittorrent 启动..."
sleep 10 # Give qBittorrent some more time to initialize

if systemctl is-active --quiet qbittorrent; then
    print_info "qBittorrent 服务运行正常。"
else
    print_error "qBittorrent 服务启动失败或未正常运行。请检查日志：journalctl -u qbittorrent -f"
fi

echo "
================================================================================
                           qBittorrent 4.3.8 安装成功！
================================================================================
访问地址: http://你的VPS_IP:${QB_WEBUI_PORT}
用户名: ${QB_WEBUI_USERNAME}
密码: ${QB_WEBUI_PASSWORD}

配置信息:
  BT 端口: 25000
  下载目录: ${QB_DOWNLOAD_DIR}
  Web UI 端口: ${QB_WEBUI_PORT}

管理命令:
  启动: systemctl start qbittorrent
  停止: systemctl stop qbittorrent
  重启: systemctl restart qbittorrent
  状态: systemctl status qbittorrent
  日志: journalctl -u qbittorrent -f

优化建议:
  - 登录后检查并调整连接数限制
  - 根据服务器性能调整缓存大小
  - 定期清理临时文件
================================================================================
"
print_info "qBittorrent 4.3.8 安装完成！"
