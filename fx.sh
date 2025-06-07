#!/bin/bash

# PTtools 快速修复脚本
# 用于修复常见的安装问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 修复qBittorrent无法启动
fix_qbittorrent() {
    print_message $BLUE "尝试修复 qBittorrent..."
    
    # 停止服务
    systemctl stop qbittorrent 2>/dev/null
    
    # 检查二进制文件
    if [[ ! -f /usr/local/bin/qbittorrent-nox ]]; then
        print_message $RED "qBittorrent 二进制文件不存在！"
        print_message $YELLOW "建议重新运行安装脚本"
        return 1
    fi
    
    # 检查配置目录
    if [[ ! -d /root/.config/qBittorrent ]]; then
        print_message $YELLOW "配置目录不存在，创建中..."
        mkdir -p /root/.config/qBittorrent
    fi
    
    # 检查下载目录
    if [[ ! -d /opt/downloads ]]; then
        print_message $YELLOW "下载目录不存在，创建中..."
        mkdir -p /opt/downloads
        chmod -R 755 /opt/downloads
    fi
    
    # 重置配置文件
    print_message $YELLOW "重置配置文件..."
    cat > /root/.config/qBittorrent/qBittorrent.conf << 'EOF'
[Preferences]
WebUI\Port=8080
WebUI\Username=admin
WebUI\Password_PBKDF2="@ByteArray(rDeaCtG9hVzqKpMKaLRNwg==:pQ5vr2q0J7S0IHlv88xJJh08gvjKoBCA0zRN4C8bTXGGbFe8ERlWNRra3xNhBX3x0yaSYvDONK1mlCddGndVIg==)"
WebUI\LocalHostAuth=false
WebUI\Address=*
Downloads\SavePath=/opt/downloads/
Downloads\TempPath=/opt/downloads/temp/
EOF
    
    # 启动服务
    print_message $BLUE "启动 qBittorrent 服务..."
    systemctl daemon-reload
    systemctl start qbittorrent
    sleep 3
    
    # 检查状态
    if systemctl is-active --quiet qbittorrent; then
        print_message $GREEN "✓ qBittorrent 服务已启动"
        print_message $CYAN "访问地址：http://$(curl -s -4 icanhazip.com):8080"
        print_message $CYAN "用户名：admin"
        print_message $CYAN "密码：adminadmin"
    else
        print_message $RED "✗ qBittorrent 服务启动失败"
        print_message $YELLOW "查看错误日志："
        journalctl -u qbittorrent -n 20 --no-pager
    fi
}

# 修复Vertex
fix_vertex() {
    print_message $BLUE "尝试修复 Vertex..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        print_message $RED "Docker 未安装！"
        return 1
    fi
    
    # 停止并删除旧容器
    docker stop vertex 2>/dev/null
    docker rm vertex 2>/dev/null
    
    # 创建目录
    mkdir -p /opt/docker/vertex
    cd /opt/docker/vertex
    
    # 创建docker-compose文件
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  vertex:
    image: lswl/vertex:stable
    container_name: vertex
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - /opt/docker/vertex:/vertex
      - /opt/downloads:/downloads
    ports:
      - 3334:3000
    restart: unless-stopped
EOF
    
    # 启动容器
    print_message $BLUE "启动 Vertex..."
    docker-compose up -d
    
    sleep 3
    if docker ps | grep -q vertex; then
        print_message $GREEN "✓ Vertex 已启动"
        print_message $CYAN "访问地址：http://$(curl -s -4 icanhazip.com):3334"
    else
        print_message $RED "✗ Vertex 启动失败"
        docker logs vertex
    fi
}

# 检查端口占用
check_ports() {
    print_message $BLUE "检查端口占用情况..."
    
    # 检查8080端口
    if netstat -tuln | grep -q ":8080 "; then
        print_message $GREEN "✓ 端口 8080 正在使用"
        netstat -tulnp | grep :8080
    else
        print_message $YELLOW "- 端口 8080 未使用"
    fi
    
    # 检查3334端口
    if netstat -tuln | grep -q ":3334 "; then
        print_message $GREEN "✓ 端口 3334 正在使用"
        netstat -tulnp | grep :3334
    else
        print_message $YELLOW "- 端口 3334 未使用"
    fi
}

# 主菜单
main() {
    clear
    print_message $CYAN "╔═══════════════════════════════════════════════════════════════╗"
    print_message $CYAN "║                    PTtools 快速修复工具                       ║"
    print_message $CYAN "╚═══════════════════════════════════════════════════════════════╝"
    echo
    echo "1. 修复 qBittorrent"
    echo "2. 修复 Vertex"
    echo "3. 检查端口占用"
    echo "4. 修复所有服务"
    echo "0. 退出"
    echo
    echo -n "请选择 [0-4]: "
    read -r choice
    
    case $choice in
        1)
            fix_qbittorrent
            ;;
        2)
            fix_vertex
            ;;
        3)
            check_ports
            ;;
        4)
            fix_qbittorrent
            echo
            fix_vertex
            echo
            check_ports
            ;;
        0)
            exit 0
            ;;
        *)
            print_message $RED "无效的选择"
            ;;
    esac
    
    echo
    echo -n "按任意键继续..."
    read -n 1
    main
}

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    print_message $RED "错误：此脚本必须以root权限运行！"
    exit 1
fi

# 运行主菜单
main
