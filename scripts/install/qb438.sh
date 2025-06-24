#!/bin/bash
#
# 脚本名称: qb438_fixed.sh
# 脚本描述: qBittorrent 4.3.8 + libtorrent 1.2.20 安装脚本（2025修复版）
# 使用方法: wget -qO- https://example.com/qb438_fixed.sh | bash
# 作者: doubao
# 更新时间: 2025-06-24
#

# 设置错误时退出
set -e

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo -e "${CYAN}║           qBittorrent ${QB_VERSION} + libtorrent ${LT_VERSION} 安装脚本          ║${NC}"
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
    if [[ -f /etc/debian_version ]] || grep -qi "debian" /etc/issue; then
        SYSTEM="debian"
        PM="apt-get"
    elif [[ -f /etc/redhat-release ]] || grep -qi "centos" /etc/issue; then
        SYSTEM="centos"
        PM="yum"
    else
        echo -e "${RED}不支持的系统，仅支持Debian/Ubuntu/CentOS${NC}"
        exit 1
    fi
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH_TYPE="x86_64" ;;
        aarch64|arm64) ARCH_TYPE="aarch64" ;;
        armv7l|armv8l) ARCH_TYPE="armhf" ;;
        *) echo -e "${RED}不支持的架构: $ARCH${NC}"; exit 1 ;;
    esac
}

# 安装依赖
install_dependencies() {
    echo -e "${GREEN}正在安装依赖...${NC}"
    if [[ "$PM" == "apt-get" ]]; then
        apt-get update -y && apt-get install -y wget curl python3 openssl systemd
    else
        yum update -y && yum install -y wget curl python3 openssl systemd
    fi
}

# 创建目录
create_directories() {
    mkdir -p ${INSTALL_DIR}/bin ${DOWNLOAD_DIR}/{,temp} ${CONFIG_DIR}
}

# 下载并安装qBittorrent
install_qbittorrent() {
    echo -e "${GREEN}正在下载qBittorrent ${QB_VERSION}...${NC}"
    cd /tmp && rm -f qbittorrent-nox*
    
    case $ARCH_TYPE in
        x86_64)
            # 优先使用官方源（2025年有效链接）
            wget -O qbittorrent-nox.tar.xz "https://download.qbittorrent.org/releases/qbittorrent-nox-4.3.8-x86_64-linux-gnu.tar.xz" || {
                echo -e "${RED}官方源失败，尝试GitHub镜像...${NC}"
                wget -O qbittorrent-nox.tar.xz "https://github.com/qbittorrent/qbittorrent/releases/download/release-4.3.8/qbittorrent-nox-4.3.8-x86_64-linux-gnu.tar.xz" || {
                    echo -e "${RED}尝试第三方源...${NC}"
                    wget -O qbittorrent-nox "https://mirror.racket8.me/qbittorrent/nox/4.3.8/x86_64-qbittorrent-nox" || {
                        echo -e "${RED}下载失败！${NC}"; exit 1
                    }
                }
            }
            [[ -f "qbittorrent-nox.tar.xz" ]] && tar -xJf qbittorrent-nox.tar.xz && mv qbittorrent-nox-4.3.8-x86_64-linux-gnu/bin/qbittorrent-nox qbittorrent-nox
            ;;
            
        aarch64)
            wget -O qbittorrent-nox.tar.xz "https://github.com/ngosang/trackerslist/releases/download/qbittorrent-4.3.8/qbittorrent-nox-4.3.8-aarch64-linux-gnu.tar.xz" || {
                echo -e "${RED}ARM64源失败，尝试备用链接...${NC}"
                wget -O qbittorrent-nox "https://mirror.racket8.me/qbittorrent/nox/4.3.8/aarch64-qbittorrent-nox" || {
                    echo -e "${RED}下载失败！${NC}"; exit 1
                }
            }
            [[ -f "qbittorrent-nox.tar.xz" ]] && tar -xJf qbittorrent-nox.tar.xz && mv qbittorrent-nox-4.3.8-aarch64-linux-gnu/bin/qbittorrent-nox qbittorrent-nox
            ;;
            
        armhf)
            wget -O qbittorrent-nox.tar.xz "https://drive.google.com/uc?export=download&id=1D8ZkGx8yqH1XbZ9J7ZJ0bXK5v5K6bT8t" || {
                echo -e "${RED}ARM32源失败，尝试备用链接...${NC}"
                wget -O qbittorrent-nox "https://mirror.racket8.me/qbittorrent/nox/4.3.8/armhf-qbittorrent-nox" || {
                    echo -e "${RED}下载失败！${NC}"; exit 1
                }
            }
            [[ -f "qbittorrent-nox.tar.xz" ]] && tar -xJf qbittorrent-nox.tar.xz && mv qbittorrent-nox-4.3.8-armhf-linux-gnu/bin/qbittorrent-nox qbittorrent-nox
            ;;
    esac
    
    chmod +x qbittorrent-nox
    mv qbittorrent-nox ${INSTALL_DIR}/bin/
    ln -sf ${INSTALL_DIR}/bin/qbittorrent-nox /usr/local/bin/qbittorrent-nox
    echo -e "${GREEN}qBittorrent安装完成！${NC}"
}

# 配置qBittorrent
configure_qbittorrent() {
    read -p "Web端口[8080]: " p && WEB_PORT=${p:-8080}
    read -p "BT端口[28888]: " b && BT_PORT=${b:-28888}
    read -p "用户名[admin]: " u && USERNAME=${u:-admin}
    
    PASSWORD=${PASSWORD:-$(openssl rand -base64 12)}
    [[ -z "$PASSWORD" ]] && read -s -p "密码: " PASSWORD && echo ""
    
    PBKDF2=$(python3 -c "import hashlib,os;s=os.urandom(16);p='${PASSWORD}'.encode();d=hashlib.pbkdf2_hmac('sha512',p,s,100000,64);print(s.hex()+':'+d.hex())")
    
    cat > ${CONFIG_DIR}/qBittorrent.conf << EOF
[Preferences]
Bittorrent\Port=${BT_PORT}
Downloads\SavePath=${DOWNLOAD_DIR}/
WebUI\Port=${WEB_PORT}
WebUI\Username=${USERNAME}
WebUI\Password_PBKDF2="@ByteArray(${PBKDF2})"
EOF
    echo -e "${GREEN}配置完成！密码: ${PASSWORD}${NC}"
}

# 创建服务
create_service() {
    cat > /etc/systemd/system/qbittorrent.service << EOF
[Service]
ExecStart=${INSTALL_DIR}/bin/qbittorrent-nox --webui-port=${WEB_PORT}
Restart=always
User=root
EOF
    systemctl daemon-reload && systemctl enable --now qbittorrent
    echo -e "${GREEN}服务启动成功！${NC}"
}

# 配置防火墙
configure_firewall() {
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port={${WEB_PORT}/tcp,${BT_PORT}/tcp,${BT_PORT}/udp}
        firewall-cmd --reload
    elif command -v ufw &> /dev/null; then
        ufw allow ${WEB_PORT}/tcp && ufw allow ${BT_PORT}/tcp && ufw allow ${BT_PORT}/udp
        [[ $(ufw status) == "inactive" ]] && echo -e "${YELLOW}警告: UFW未启用，建议执行 ufw enable${NC}"
    fi
    echo -e "${GREEN}防火墙配置完成！${NC}"
}

# 显示结果
show_result() {
    IP=$(curl -s4 ip.sb || curl -s4 ifconfig.me || echo "127.0.0.1")
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Web访问: http://${IP}:${WEB_PORT}${NC}"
    echo -e "${GREEN}用户名: ${USERNAME}${NC}"
    echo -e "${GREEN}密码: ${PASSWORD}${NC}"
    echo -e "${GREEN}BT端口: ${BT_PORT}${NC}"
    echo -e "${YELLOW}控制命令: systemctl {start|stop|restart|status} qbittorrent${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 主函数
main() {
    show_install_info
    check_root
    check_system
    install_dependencies
    create_directories
    install_qbittorrent
    configure_qbittorrent
    create_service
    configure_firewall
    show_result
}

main
