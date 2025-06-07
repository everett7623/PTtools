#!/bin/bash

# qBittorrent 静态版本快速安装脚本
# 使用更可靠的预编译版本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
QB_VERSION="${1:-4.3.9}"
DOWNLOAD_DIR="/opt/downloads"
INSTALL_DIR="/usr/local/bin"

# 打印消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    print_message $RED "错误：此脚本必须以root权限运行！"
    exit 1
fi

# 检查架构
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
    print_message $RED "错误：仅支持 x86_64 架构！"
    exit 1
fi

# 清理旧版本
clean_old_version() {
    print_message $BLUE "清理旧版本..."
    systemctl stop qbittorrent 2>/dev/null
    systemctl disable qbittorrent 2>/dev/null
    rm -f $INSTALL_DIR/qbittorrent-nox
    rm -f /etc/systemd/system/qbittorrent.service
    systemctl daemon-reload
}

# 下载静态编译版本
download_static_build() {
    print_message $BLUE "下载 qBittorrent ${QB_VERSION} 静态编译版本..."
    
    cd /tmp
    
    # 根据版本选择下载源
    if [[ "$QB_VERSION" == "4.3.8" ]] || [[ "$QB_VERSION" == "4.3.9" ]]; then
        # 4.3.x 版本使用特定的下载链接
        URLS=(
            "https://github.com/c0re100/qBittorrent-Enhanced-Edition/releases/download/release-${QB_VERSION}.0/qbittorrent-enhanced-nox_x86_64-linux-musl_static.zip"
            "https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v1.2.15/x86_64-qbittorrent-nox"
            "https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v1.2.19/x86_64-qbittorrent-nox"
        )
    else
        # 其他版本或最新版本
        print_message $YELLOW "警告：版本 ${QB_VERSION} 可能不受支持，尝试下载..."
        URLS=(
            "https://github.com/userdocs/qbittorrent-nox-static/releases/latest/download/x86_64-qbittorrent-nox"
        )
    fi
    
    for url in "${URLS[@]}"; do
        print_message $YELLOW "尝试下载：$url"
        if wget -q --show-progress "$url" -O qbittorrent-download 2>/dev/null; then
            # 检查文件类型
            if file qbittorrent-download | grep -q "Zip archive"; then
                # 解压zip文件
                unzip -o qbittorrent-download >/dev/null 2>&1
                mv qbittorrent-enhanced-nox_x86_64-linux-musl_static qbittorrent-nox 2>/dev/null || \
                mv qbittorrent-nox_x86_64-linux-musl_static qbittorrent-nox 2>/dev/null
            else
                mv qbittorrent-download qbittorrent-nox
            fi
            
            if [[ -f qbittorrent-nox ]]; then
                chmod +x qbittorrent-nox
                # 测试执行并验证版本
                local installed_version=$(./qbittorrent-nox --version 2>/dev/null | grep -oP 'qBittorrent v\K[\d.]+' | head -1)
                print_message $GREEN "下载成功！版本：$installed_version"
                
                # 版本警告
                if [[ "$installed_version" != "$QB_VERSION"* ]]; then
                    print_message $YELLOW "警告：安装的版本 ($installed_version) 与请求的版本 ($QB_VERSION) 不匹配"
                    echo -n "是否继续？[y/N]: "
                    read -r confirm
                    if [[ $confirm != "y" && $confirm != "Y" ]]; then
                        return 1
                    fi
                fi
                return 0
            fi
        fi
    done
    
    print_message $RED "所有下载源都失败了！"
    return 1
}

# 安装二进制文件
install_binary() {
    print_message $BLUE "安装 qBittorrent..."
    
    if [[ ! -f /tmp/qbittorrent-nox ]]; then
        print_message $RED "错误：二进制文件不存在！"
        return 1
    fi
    
    # 复制到安装目录
    cp /tmp/qbittorrent-nox $INSTALL_DIR/
    chmod +x $INSTALL_DIR/qbittorrent-nox
    
    # 验证安装
    if $INSTALL_DIR/qbittorrent-nox --version; then
        print_message $GREEN "安装成功！"
        return 0
    else
        print_message $RED "安装失败！"
        return 1
    fi
}

# 创建配置
create_config() {
    print_message $BLUE "创建配置文件..."
    
    # 创建目录
    mkdir -p /root/.config/qBittorrent
    mkdir -p $DOWNLOAD_DIR/temp
    
    # 创建配置文件
    cat > /root/.config/qBittorrent/qBittorrent.conf << EOF
[Application]
FileLogger\Enabled=true
FileLogger\Path=/var/log/qbittorrent
FileLogger\MaxSizeBytes=10485760

[BitTorrent]
Session\Port=25000
Session\QueueingSystemEnabled=false

[Preferences]
Connection\PortRangeMin=25000
Downloads\SavePath=$DOWNLOAD_DIR/
Downloads\TempPath=$DOWNLOAD_DIR/temp/
Downloads\TempPathEnabled=true
General\Locale=zh_CN
WebUI\Address=*
WebUI\LocalHostAuth=false
WebUI\Port=8080
WebUI\Username=admin
WebUI\Password_PBKDF2="@ByteArray(rDeaCtG9hVzqKpMKaLRNwg==:pQ5vr2q0J7S0IHlv88xJJh08gvjKoBCA0zRN4C8bTXGGbFe8ERlWNRra3xNhBX3x0yaSYvDONK1mlCddGndVIg==)"
EOF
    
    # 创建systemd服务
    cat > /etc/systemd/system/qbittorrent.service << 'EOF'
[Unit]
Description=qBittorrent-nox
Documentation=man:qbittorrent-nox(1)
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=exec
User=root
ExecStart=/usr/local/bin/qbittorrent-nox
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable qbittorrent
}

# 启动服务
start_service() {
    print_message $BLUE "启动 qBittorrent 服务..."
    
    systemctl start qbittorrent
    sleep 5
    
    if systemctl is-active --quiet qbittorrent; then
        print_message $GREEN "✓ 服务启动成功！"
        return 0
    else
        print_message $RED "✗ 服务启动失败！"
        journalctl -u qbittorrent -n 10 --no-pager
        return 1
    fi
}

# 显示信息
show_info() {
    local ip=$(curl -s -4 icanhazip.com || hostname -I | awk '{print $1}')
    
    echo
    print_message $GREEN "╔═══════════════════════════════════════════════════════════════╗"
    print_message $GREEN "║          qBittorrent 静态版本安装成功！                       ║"
    print_message $GREEN "╚═══════════════════════════════════════════════════════════════╝"
    echo
    print_message $CYAN "访问地址：http://${ip}:8080"
    print_message $CYAN "用户名：admin"
    print_message $CYAN "密码：adminadmin"
    print_message $CYAN "BT端口：25000"
    print_message $CYAN "下载目录：$DOWNLOAD_DIR"
    echo
    print_message $YELLOW "管理命令："
    print_message $YELLOW "• systemctl status qbittorrent  - 查看状态"
    print_message $YELLOW "• systemctl restart qbittorrent - 重启服务"
    print_message $YELLOW "• journalctl -u qbittorrent -f  - 查看日志"
    echo
}

# 主函数
main() {
    clear
    print_message $CYAN "╔═══════════════════════════════════════════════════════════════╗"
    print_message $CYAN "║        qBittorrent 静态版本快速安装脚本                       ║"
    print_message $CYAN "╚═══════════════════════════════════════════════════════════════╝"
    echo
    
    # 清理旧版本
    clean_old_version
    
    # 下载静态版本
    if ! download_static_build; then
        print_message $RED "下载失败！请使用编译安装脚本：./compile-qb.sh"
        exit 1
    fi
    
    # 安装
    if ! install_binary; then
        exit 1
    fi
    
    # 配置
    create_config
    
    # 启动
    if start_service; then
        show_info
    else
        print_message $RED "安装完成但服务启动失败，请检查日志！"
    fi
    
    # 清理
    rm -f /tmp/qbittorrent-nox /tmp/qbittorrent-download
}

# 运行
main
