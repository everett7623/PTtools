#!/bin/bash

# Vertex 安装脚本
# 通过Docker Compose安装

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
DOCKER_DIR="/opt/docker"
VERTEX_DIR="$DOCKER_DIR/vertex"
GITHUB_RAW_URL="https://raw.githubusercontent.com/everett7623/PTtools/main"

# 打印消息函数
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 检查Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_message $RED "错误：Docker 未安装！"
        print_message $YELLOW "请先安装 Docker 后再运行此脚本"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_message $RED "错误：docker-compose 未安装！"
        print_message $YELLOW "请先安装 docker-compose 后再运行此脚本"
        exit 1
    fi
}

# 创建目录
create_directories() {
    print_message $BLUE "创建 Vertex 目录..."
    mkdir -p $VERTEX_DIR
    chmod -R 755 $VERTEX_DIR
}

# 下载配置文件
download_config() {
    print_message $BLUE "下载 Vertex 配置文件..."
    wget -O $VERTEX_DIR/docker-compose.yml "${GITHUB_RAW_URL}/configs/docker-compose/vertex.yml"
    
    if [[ ! -f $VERTEX_DIR/docker-compose.yml ]]; then
        print_message $RED "错误：配置文件下载失败！"
        exit 1
    fi
}

# 配置Vertex
configure_vertex() {
    print_message $BLUE "配置 Vertex..."
    
    # 询问是否需要自定义配置
    echo -n "是否需要自定义配置？[y/N]: "
    read -r custom_config
    
    if [[ $custom_config == "y" || $custom_config == "Y" ]]; then
        # 端口配置
        echo -n "请输入 Web UI 端口 [默认: 3334]: "
        read -r web_port
        web_port=${web_port:-3334}
        
        # 修改docker-compose.yml中的端口
        sed -i "s/3334:3000/${web_port}:3000/g" $VERTEX_DIR/docker-compose.yml
        
        print_message $GREEN "自定义配置完成！"
    fi
}

# 启动Vertex
start_vertex() {
    print_message $BLUE "启动 Vertex..."
    cd $VERTEX_DIR
    docker-compose up -d
    
    # 检查容器状态
    sleep 3
    if docker ps | grep -q vertex; then
        print_message $GREEN "Vertex 启动成功！"
    else
        print_message $RED "Vertex 启动失败！"
        print_message $YELLOW "请检查日志：docker logs vertex"
        exit 1
    fi
}

# 配置防火墙
configure_firewall() {
    print_message $BLUE "配置防火墙..."
    
    # 获取端口
    local port=$(grep -oP '\d+(?=:3000)' $VERTEX_DIR/docker-compose.yml | head -1)
    port=${port:-3334}
    
    if command -v ufw &> /dev/null; then
        ufw allow $port/tcp comment "Vertex Web UI"
        print_message $GREEN "UFW 防火墙规则已添加"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$port/tcp
        firewall-cmd --reload
        print_message $GREEN "Firewalld 防火墙规则已添加"
    fi
}

# 获取服务器IP
get_server_ip() {
    local ip=$(curl -s -4 icanhazip.com || curl -s -4 ifconfig.me || curl -s -4 ipinfo.io/ip)
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    echo $ip
}

# 显示安装信息
show_install_info() {
    local server_ip=$(get_server_ip)
    local port=$(grep -oP '\d+(?=:3000)' $VERTEX_DIR/docker-compose.yml | head -1)
    port=${port:-3334}
    
    echo
    print_message $GREEN "╔═══════════════════════════════════════════════════════════════╗"
    print_message $GREEN "║                  Vertex 安装成功！                            ║"
    print_message $GREEN "╚═══════════════════════════════════════════════════════════════╝"
    echo
    print_message $CYAN "访问地址：http://${server_ip}:${port}"
    print_message $CYAN "配置目录：$VERTEX_DIR"
    echo
    print_message $GREEN "管理命令："
    print_message $GREEN "查看状态：docker ps | grep vertex"
    print_message $GREEN "查看日志：docker logs -f vertex"
    print_message $GREEN "停止服务：cd $VERTEX_DIR && docker-compose down"
    print_message $GREEN "启动服务：cd $VERTEX_DIR && docker-compose up -d"
    print_message $GREEN "重启服务：cd $VERTEX_DIR && docker-compose restart"
    echo
    print_message $YELLOW "提示："
    print_message $YELLOW "1. Vertex 数据存储在：$VERTEX_DIR"
    print_message $YELLOW "2. 下载目录映射到：/opt/downloads"
    print_message $YELLOW "3. 确保 qBittorrent 已正确配置并运行"
    echo
}

# 主函数
main() {
    print_message $BLUE "开始安装 Vertex..."
    
    # 检查Docker
    check_docker
    
    # 创建目录
    create_directories
    
    # 下载配置
    download_config
    
    # 配置Vertex
    configure_vertex
    
    # 启动Vertex
    start_vertex
    
    # 配置防火墙
    configure_firewall
    
    # 显示安装信息
    show_install_info
    
    print_message $GREEN "Vertex 安装完成！"
}

# 执行主函数
main
