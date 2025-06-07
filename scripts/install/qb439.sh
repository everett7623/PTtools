#!/bin/bash

# qBittorrent 4.3.9 专用快速安装脚本
# 确保安装正确版本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 固定配置
QB_VERSION="4.3.9"
LT_VERSION="1.2.15"
DOWNLOAD_DIR="/opt/downloads"

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

# 停止并卸载现有版本
uninstall_existing() {
    print_message $BLUE "卸载现有版本..."
    
    # 停止服务
    systemctl stop qbittorrent 2>/dev/null
    systemctl disable qbittorrent 2>/dev/null
    
    # 删除文件
    rm -f /usr/local/bin/qbittorrent-nox
    rm -f /usr/bin/qbittorrent-nox
    rm -f /etc/systemd/system/qbittorrent.service
    
    # 重载systemd
    systemctl daemon-reload
    
    print_message $GREEN "卸载完成"
}

# 安装方法1：使用jesec的预编译版本
install_method1() {
    print_message $BLUE "方法1：尝试下载 jesec 预编译版本..."
    
    cd /tmp
    # jesec的预编译版本
    local url="https://github.com/jesec/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_libtorrent1.2/qbittorrent-nox-linux-x64"
    
    if wget -q --show-progress "$url" -O qbittorrent-nox; then
        chmod +x qbittorrent-nox
        # 验证版本
        local version=$(./qbittorrent-nox --version 2>/dev/null | grep -oP 'qBittorrent v\K[\d.]+' | head -1)
        if [[ "$version" == "${QB_VERSION}"* ]]; then
            mv qbittorrent-nox /usr/local/bin/
            print_message $GREEN "✓ 安装成功！版本：$version"
            return 0
        else
            print_message $YELLOW "版本不匹配：$version"
        fi
    fi
    return 1
}

# 安装方法2：使用userdocs的预编译版本
install_method2() {
    print_message $BLUE "方法2：尝试下载 userdocs 预编译版本..."
    
    cd /tmp
    # 尝试不同的libtorrent版本组合
    local lt_versions=("1.2.15" "1.2.19" "1.2.20")
    
    for lt_ver in "${lt_versions[@]}"; do
        local url="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${QB_VERSION}_v${lt_ver}/x86_64-qbittorrent-nox"
        print_message $YELLOW "尝试 libtorrent $lt_ver..."
        
        if wget -q --show-progress "$url" -O qbittorrent-nox 2>/dev/null; then
            chmod +x qbittorrent-nox
            # 验证
            if ./qbittorrent-nox --version &>/dev/null; then
                local version=$(./qbittorrent-nox --version 2>/dev/null | grep -oP 'qBittorrent v\K[\d.]+' | head -1)
                if [[ "$version" == "${QB_VERSION}"* ]]; then
                    mv qbittorrent-nox /usr/local/bin/
                    print_message $GREEN "✓ 安装成功！版本：$version (libtorrent $lt_ver)"
                    return 0
                fi
            fi
        fi
    done
    return 1
}

# 安装方法3：编译安装
install_method3() {
    print_message $BLUE "方法3：从源码编译安装..."
    
    # 安装编译依赖
    print_message $YELLOW "安装编译依赖..."
    apt-get update >/dev/null 2>&1
    apt-get install -y build-essential pkg-config automake libtool git \
        zlib1g-dev libssl-dev libgeoip-dev libboost-dev libboost-system-dev \
        libboost-chrono-dev libboost-random-dev qtbase5-dev qttools5-dev-tools \
        libqt5svg5-dev >/dev/null 2>&1
    
    # 编译libtorrent
    print_message $YELLOW "编译 libtorrent ${LT_VERSION}..."
    cd /tmp
    wget -q https://github.com/arvidn/libtorrent/releases/download/v${LT_VERSION}/libtorrent-rasterbar-${LT_VERSION}.tar.gz
    tar -xf libtorrent-rasterbar-${LT_VERSION}.tar.gz
    cd libtorrent-rasterbar-${LT_VERSION}
    
    ./configure --disable-debug --enable-encryption >/dev/null 2>&1
    make -j$(nproc) >/dev/null 2>&1
    make install >/dev/null 2>&1
    ldconfig
    
    # 编译qBittorrent
    print_message $YELLOW "编译 qBittorrent ${QB_VERSION}..."
    cd /tmp
    wget -q https://github.com/qbittorrent/qBittorrent/archive/release-${QB_VERSION}.tar.gz
    tar -xf release-${QB_VERSION}.tar.gz
    cd qBittorrent-release-${QB_VERSION}
    
    ./configure --disable-gui --disable-debug >/dev/null 2>&1
    make -j$(nproc) >/dev/null 2>&1
    make install >/dev/null 2>&1
    
    # 清理
    cd /
    rm -rf /tmp/libtorrent-rasterbar-${LT_VERSION}* /tmp/qBittorrent-release-${QB_VERSION}*
    
    print_message $GREEN "✓ 编译完成！"
    return 0
}

# 创建配置和服务
create_config() {
    print_message $BLUE "创建配置文件..."
    
    # 创建目录
    mkdir -p /root/.config/qBittorrent
    mkdir -p $DOWNLOAD_DIR/temp
    
    # 配置文件
    cat > /root/.config/qBittorrent/qBittorrent.conf << EOF
[Preferences]
Bittorrent\MaxConnecs=-1
Bittorrent\MaxConnecsPerTorrent=-1
Bittorrent\MaxRatio=-1
Bittorrent\MaxUploads=-1
Bittorrent\MaxUploadsPerTorrent=-1
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

[BitTorrent]
Session\Port=25000
Session\QueueingSystemEnabled=false
Session\GlobalMaxSeedingMinutes=-1
EOF
    
    # systemd服务
    cat > /etc/systemd/system/qbittorrent.service << EOF
[Unit]
Description=qBittorrent-nox
After=network.target

[Service]
Type=exec
User=root
ExecStart=/usr/local/bin/qbittorrent-nox
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable qbittorrent >/dev/null 2>&1
}

# 启动服务
start_service() {
    print_message $BLUE "启动服务..."
    
    systemctl start qbittorrent
    sleep 3
    
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
    print_message $GREEN "║          qBittorrent 4.3.9 安装成功！                         ║"
    print_message $GREEN "╚═══════════════════════════════════════════════════════════════╝"
    echo
    print_message $CYAN "访问地址：http://${ip}:8080"
    print_message $CYAN "用户名：admin"
    print_message $CYAN "密码：adminadmin"
    print_message $CYAN "BT端口：25000"
    print_message $CYAN "下载目录：$DOWNLOAD_DIR"
    echo
}

# 主函数
main() {
    clear
    print_message $CYAN "╔═══════════════════════════════════════════════════════════════╗"
    print_message $CYAN "║        qBittorrent 4.3.9 专用安装脚本                         ║"
    print_message $CYAN "╚═══════════════════════════════════════════════════════════════╝"
    echo
    
    # 确认当前版本
    if command -v qbittorrent-nox &> /dev/null; then
        current_version=$(qbittorrent-nox --version 2>/dev/null | grep -oP 'qBittorrent v\K[\d.]+' | head -1)
        if [[ -n "$current_version" ]]; then
            print_message $YELLOW "当前已安装版本：$current_version"
            echo -n "是否继续安装 4.3.9？[Y/n]: "
            read -r confirm
            if [[ $confirm == "n" || $confirm == "N" ]]; then
                exit 0
            fi
        fi
    fi
    
    # 卸载现有版本
    uninstall_existing
    
    # 尝试多种安装方法
    if ! install_method1; then
        if ! install_method2; then
            print_message $YELLOW "预编译版本不可用，开始编译安装..."
            if ! install_method3; then
                print_message $RED "所有安装方法都失败了！"
                exit 1
            fi
        fi
    fi
    
    # 创建配置
    create_config
    
    # 启动服务
    if start_service; then
        show_info
    fi
}

# 运行
main
