#!/bin/bash

# Vertex + qBittorrent 4.3.8 组合安装脚本
# PTtools项目: https://github.com/everett7623/PTtools

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 基础配置
GITHUB_USER="everett7623"
GITHUB_REPO="PTtools"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main"
DOCKER_DIR="/opt/docker"

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误：此脚本必须以root用户运行！${NC}"
   exit 1
fi

# 安装qBittorrent 4.3.8
install_qb438() {
    echo -e "${CYAN}正在安装qBittorrent 4.3.8...${NC}"
    
    # 下载并执行qb438安装脚本
    wget -O /tmp/qb438_temp.sh ${GITHUB_RAW_URL}/scripts/install/qb438.sh
    chmod +x /tmp/qb438_temp.sh
    
    # 执行安装脚本
    bash /tmp/qb438_temp.sh
    
    # 清理临时文件
    rm -f /tmp/qb438_temp.sh
    
    echo -e "${GREEN}qBittorrent 4.3.8安装完成${NC}"
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker未安装，正在安装Docker...${NC}"
        curl -fsSL https://get.docker.com | bash -s docker
        systemctl start docker
        systemctl enable docker
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}Docker Compose未安装，正在安装...${NC}"
        mkdir -p /usr/local/lib/docker/cli-plugins
        curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
        chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    fi
}

# 安装Vertex
install_vertex() {
    echo -e "${CYAN}正在安装Vertex...${NC}"
    
    # 创建Vertex目录
    mkdir -p ${DOCKER_DIR}/vertex
    
    # 创建docker-compose文件
    cat > ${DOCKER_DIR}/vertex/docker-compose.yml <<EOF
version: '3.8'

services:
  vertex:
    image: lswl/vertex:stable
    container_name: vertex
    environment:
      - TZ=Asia/Shanghai
      - PUID=0
      - PGID=0
    volumes:
      - ${DOCKER_DIR}/vertex:/vertex
    ports:
      - 3333:3000
    restart: unless-stopped
EOF

    # 启动Vertex
    cd ${DOCKER_DIR}/vertex
    docker compose up -d
    
    echo -e "${GREEN}Vertex安装完成${NC}"
}

# 配置Vertex
configure_vertex() {
    echo -e "${CYAN}配置Vertex与qBittorrent连接...${NC}"
    
    # 等待Vertex启动
    echo -e "${YELLOW}等待Vertex启动...${NC}"
    sleep 10
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}Vertex配置提示：${NC}"
    echo -e "1. 访问 http://${SERVER_IP}:3333 进入Vertex"
    echo -e "2. 添加qBittorrent客户端："
    echo -e "   - 地址: http://${SERVER_IP}:8080"
    echo -e "   - 用户名: admin"
    echo -e "   - 密码: adminadmin"
    echo -e "3. 配置完成后即可使用Vertex管理qBittorrent"
}

# 显示安装信息
show_info() {
    clear
    # 获取服务器IP
    SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}   Vertex + qBittorrent 4.3.8 安装完成！${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo
    echo -e "${CYAN}访问地址：${NC}"
    echo -e "qBittorrent: http://${SERVER_IP}:8080"
    echo -e "Vertex: http://${SERVER_IP}:3333"
    echo
    echo -e "${CYAN}默认账号信息：${NC}"
    echo -e "qBittorrent用户名: admin"
    echo -e "qBittorrent密码: adminadmin"
    echo
    echo -e "${YELLOW}服务管理命令：${NC}"
    echo -e "qBittorrent:"
    echo -e "  systemctl [start|stop|restart|status] qbittorrent"
    echo -e "Vertex:"
    echo -e "  cd ${DOCKER_DIR}/vertex && docker compose [up -d|down|restart]"
    echo
    echo -e "${YELLOW}注意事项：${NC}"
    echo -e "1. 首次登录后请立即修改密码"
    echo -e "2. 在Vertex中添加qBittorrent客户端进行管理"
    echo -e "3. 确保防火墙已开放相应端口"
    echo
    echo -e "${GREEN}================================================${NC}"
}

# 主函数
main() {
    echo -e "${CYAN}开始安装Vertex + qBittorrent 4.3.8...${NC}"
    
    # 安装qBittorrent 4.3.8
    install_qb438
    
    # 检查Docker环境
    check_docker
    
    # 安装Vertex
    install_vertex
    
    # 配置Vertex
    configure_vertex
    
    # 显示安装信息
    show_info
}

# 执行主函数
main