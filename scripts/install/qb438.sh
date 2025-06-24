#!/bin/bash
#
# 脚本名称: qb438.sh
# 脚本描述: qBittorrent 4.3.8 + libtorrent 1.2.20 快速安装脚本
# 脚本路径: https://github.com/everett7623/PTtools/blob/main/scripts/install/qb438.sh
# 使用方法: wget -qO- https://raw.githubusercontent.com/everett7623/PTtools/main/scripts/install/qb438.sh | bash
# 作者: everett7623
# 更新时间: 2024-06-24
# 版本: v1.0.1 (修复版)
#

# 设置错误时退出
set -e

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 定义全局变量
QB_VERSION="4.3.8"
LT_VERSION="1.2.20"
INSTALL_DIR="/usr/local/qbittorrent"
DOWNLOAD_DIR="/opt/downloads"
CONFIG_DIR="/root/.config/qBittorrent"
WEB_PORT="8080"
BT_PORT="28888"
USERNAME="admin"
PASSWORD=""

# 显示安装信息
show_install_info() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}║           qBittorrent ${QB_VERSION} + libtorrent ${LT_VERSION} 安装脚本          ║${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        exit 1
    fi
}

# 检查系统
check_system() {
    # 检测Debian/Ubuntu系列
    if [[ -f /etc/debian_version ]] || cat /etc/issue | grep -q -E -i "debian|ubuntu"; then
        SYSTEM="debian"
        PM="apt-get"
    # 检测CentOS/RHEL系列
    elif [[ -f /etc/redhat-release ]] || cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        SYSTEM="centos"
        PM="yum"
    else
        echo -e "${RED}不支持的操作系统！仅支持Debian/Ubuntu/CentOS${NC}"
        exit 1
    fi
    
    # 获取系统架构
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        ARCH_TYPE="x86_64"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        ARCH_TYPE="aarch64"
    elif [[ "$ARCH" == "armv7l" || "$ARCH" == "armv8l" ]]; then
        ARCH_TYPE="armhf"
    else
        echo -e "${RED}不支持的系统架构: $ARCH，仅支持x86_64/aarch64/armhf${NC}"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${GREEN}正在安装依赖包...${NC}"
    
    if [[ "$PM" == "apt-get" ]]; then
        apt-get update -y
        apt-get install -y wget curl ca-certificates python3 python3-pip systemd
    elif [[ "$PM" == "yum" ]]; then
        yum update -y
        yum install -y wget curl ca-certificates python3 python3-pip systemd
    fi
}

# 创建必要的目录
create_directories() {
    mkdir -p ${INSTALL_DIR}/bin
    mkdir -p ${INSTALL_DIR}/lib
    mkdir -p ${DOWNLOAD_DIR}
    mkdir -p ${CONFIG_DIR}
}

# 下载并安装qBittorrent二进制文件
install_qbittorrent() {
    echo -e "${GREEN}正在下载qBittorrent ${QB_VERSION}...${NC}"
    
    # 这里使用预编译的二进制文件
    # 根据参考脚本，我们需要下载预编译的qbittorrent-nox
    cd /tmp
    
    # 下载URL根据架构选择
    if [[ "$ARCH_TYPE" == "x86_64" ]]; then
        # x86_64架构下载链接
        wget -O qbittorrent-nox "https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v${LT_VERSION}/x86_64-qbittorrent-nox" || {
            echo -e "${RED}主下载地址失败，尝试备用地址...${NC}"
            wget -O qbittorrent-nox "https://sourceforge.net/projects/qbittorrent/files/qbittorrent-linux/qbittorrent-${QB_VERSION}/qbittorrent-nox" || {
                echo -e "${RED}下载qBittorrent失败！${NC}"
                exit 1
            }
        }
    elif [[ "$ARCH_TYPE" == "aarch64" ]]; then
        # aarch64(ARM64)架构下载链接
        wget -O qbittorrent-nox "https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v${LT_VERSION}/aarch64-qbittorrent-nox" || {
            echo -e "${RED}主下载地址失败，尝试备用地址...${NC}"
            wget -O qbittorrent-nox "https://github.com/ngosang/trackerslist/wiki/qBittorrent-ARM#download" || {
                echo -e "${RED}下载qBittorrent失败！${NC}"
                exit 1
            }
        }
    elif [[ "$ARCH_TYPE" == "armhf" ]]; then
        # armhf(32位ARM)架构下载链接
        wget -O qbittorrent-nox "https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v${LT_VERSION}/armhf-qbittorrent-nox" || {
            echo -e "${RED}主下载地址失败，尝试备用地址...${NC}"
            wget -O qbittorrent-nox "https://github.com/ngosang/trackerslist/wiki/qBittorrent-ARM#download" || {
                echo -e "${RED}下载qBittorrent失败！${NC}"
                exit 1
            }
        }
    else
        echo -e "${RED}暂不支持 ${ARCH_TYPE} 架构的自动安装${NC}"
        exit 1
    fi
    
    # 安装二进制文件
    chmod +x qbittorrent-nox
    mv qbittorrent-nox ${INSTALL_DIR}/bin/
    
    # 创建符号链接
    ln -sf ${INSTALL_DIR}/bin/qbittorrent-nox /usr/local/bin/qbittorrent-nox
    
    echo -e "${GREEN}qBittorrent ${QB_VERSION} 安装完成！${NC}"
}

# 配置qBittorrent
configure_qbittorrent() {
    echo -e "${GREEN}正在配置qBittorrent...${NC}"
    
    # 获取用户输入
    read -p "请输入Web UI端口 [默认: 8080]: " input_port
    WEB_PORT=${input_port:-8080}
    
    read -p "请输入BT监听端口 [默认: 28888]: " input_bt_port
    BT_PORT=${input_bt_port:-28888}
    
    read -p "请输入Web UI用户名 [默认: admin]: " input_username
    USERNAME=${input_username:-admin}
    
    # 生成随机密码
    if [[ -z "$PASSWORD" ]]; then
        PASSWORD=$(openssl rand -base64 12)
        echo -e "${YELLOW}已生成随机密码: ${PASSWORD}${NC}"
    else
        read -s -p "请输入Web UI密码: " input_password
        echo ""
        PASSWORD=${input_password}
    fi
    
    # 生成密码哈希
    PBKDF2_PASSWORD=$(python3 -c "
import hashlib
import os
salt = os.urandom(16)
password = '${PASSWORD}'.encode('utf-8')
dk = hashlib.pbkdf2_hmac('sha512', password, salt, 100000, dklen=64)
print(salt.hex() + ':' + dk.hex())
")
    
    # 创建配置文件
    cat > ${CONFIG_DIR}/qBittorrent.conf << EOF
[AutoRun]
enabled=false
program=

[LegalNotice]
Accepted=true

[Preferences]
Bittorrent\MaxRatio=-1
Bittorrent\Port=${BT_PORT}
Connection\PortRangeMin=${BT_PORT}
Downloads\SavePath=${DOWNLOAD_DIR}/
Downloads\TempPath=${DOWNLOAD_DIR}/temp/
General\Locale=zh_CN
WebUI\Address=*
WebUI\AlternativeUIEnabled=false
WebUI\AuthSubnetWhitelist=
WebUI\AuthSubnetWhitelistEnabled=false
WebUI\BanDuration=3600
WebUI\CSRFProtection=true
WebUI\ClickjackingProtection=true
WebUI\CustomHTTPHeaders=
WebUI\CustomHTTPHeadersEnabled=false
WebUI\HTTPS\Enabled=false
WebUI\HostHeaderValidation=true
WebUI\LocalHostAuth=false
WebUI\MaxAuthenticationFailCount=5
WebUI\Password_PBKDF2="@ByteArray(${PBKDF2_PASSWORD})"
WebUI\Port=${WEB_PORT}
WebUI\RootFolder=
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\UseUPnP=false
WebUI\Username=${USERNAME}
EOF

    # 创建下载目录
    mkdir -p ${DOWNLOAD_DIR}/temp
    
    echo -e "${GREEN}qBittorrent配置完成！${NC}"
}

# 创建systemd服务
create_service() {
    echo -e "${GREEN}正在创建systemd服务...${NC}"
    
    cat > /etc/systemd/system/qbittorrent.service << EOF
[Unit]
Description=qBittorrent-nox service
Documentation=https://github.com/qbittorrent/qBittorrent
After=network.target

[Service]
Type=simple
User=root
ExecStart=${INSTALL_DIR}/bin/qbittorrent-nox --webui-port=${WEB_PORT}
Restart=on-failure
RestartSec=5s
WorkingDirectory=${INSTALL_DIR}
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd并启动服务
    systemctl daemon-reload
    systemctl enable qbittorrent
    systemctl start qbittorrent
    
    echo -e "${GREEN}qBittorrent服务已启动！${NC}"
}

# 配置防火墙
configure_firewall() {
    echo -e "${GREEN}正在配置防火墙...${NC}"
    
    # 检查防火墙类型
    if command -v firewall-cmd &> /dev/null; then
        # firewalld (CentOS 7+)
        firewall-cmd --permanent --add-port=${WEB_PORT}/tcp
        firewall-cmd --permanent --add-port=${BT_PORT}/tcp
        firewall-cmd --permanent --add-port=${BT_PORT}/udp
        firewall-cmd --reload
    elif command -v ufw &> /dev/null; then
        # ufw (Debian/Ubuntu)
        ufw allow ${WEB_PORT}/tcp || true
        ufw allow ${BT_PORT}/tcp || true
        ufw allow ${BT_PORT}/udp || true
        if [[ "$(ufw status)" == "inactive" ]]; then
            echo -e "${YELLOW}注意: UFW防火墙未启用，建议手动启用: ufw enable${NC}"
        fi
    elif command -v iptables &> /dev/null; then
        # iptables (旧系统)
        iptables -I INPUT -p tcp --dport ${WEB_PORT} -j ACCEPT
        iptables -I INPUT -p tcp --dport ${BT_PORT} -j ACCEPT
        iptables -I INPUT -p udp --dport ${BT_PORT} -j ACCEPT
        
        # 保存规则
        if [[ "$SYSTEM" == "centos" ]]; then
            service iptables save
        elif [[ "$SYSTEM" == "debian" ]] || [[ "$SYSTEM" == "ubuntu" ]]; then
            iptables-save > /etc/iptables/rules.v4
        fi
    else
        echo -e "${YELLOW}警告: 未检测到防火墙管理工具，需手动开放端口 ${WEB_PORT}(TCP) 和 ${BT_PORT}(TCP/UDP)${NC}"
    fi
    
    echo -e "${GREEN}防火墙配置完成！${NC}"
}

# 显示安装信息
show_install_result() {
    # 获取服务器IP
    SERVER_IP=$(curl -s4 ip.sb || curl -s4 ipinfo.io/ip || curl -s4 ifconfig.me || echo "localhost")
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    qBittorrent 安装成功！                      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}访问地址:${NC} http://${SERVER_IP}:${WEB_PORT}"
    echo -e "${GREEN}用户名:${NC} ${USERNAME}"
    echo -e "${GREEN}密码:${NC} ${PASSWORD}"
    echo -e "${GREEN}BT端口:${NC} ${BT_PORT}"
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo -e "启动: systemctl start qbittorrent"
    echo -e "停止: systemctl stop qbittorrent"
    echo -e "重启: systemctl restart qbittorrent"
    echo -e "状态: systemctl status qbittorrent"
    echo -e "日志: journalctl -u qbittorrent -f"
    echo ""
    echo -e "${PURPLE}请保存以上信息！建议首次登录后修改密码${NC}"
    echo ""
}

# 主函数
main() {
    show_install_info
    check_root
    check_system
    
    # 检查是否已安装
    if systemctl is-active --quiet qbittorrent; then
        echo -e "${YELLOW}检测到qBittorrent已安装并运行中${NC}"
        read -p "是否要重新安装? [y/N]: " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}已取消安装${NC}"
            exit 0
        fi
        
        # 停止并删除旧版本
        systemctl stop qbittorrent
        systemctl disable qbittorrent
        rm -rf ${INSTALL_DIR}
        rm -f /etc/systemd/system/qbittorrent.service
        systemctl daemon-reload
    fi
    
    # 开始安装
    install_dependencies
    create_directories
    install_qbittorrent
    configure_qbittorrent
    create_service
    configure_firewall
    show_install_result
}

# 运行主函数
main
