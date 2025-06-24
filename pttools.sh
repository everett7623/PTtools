#!/bin/bash

# PTtools - PT工具一键安装脚本
# Author: everett7623
# Github: https://github.com/everett7623/PTtools

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m'

# 基础配置
GITHUB_USER="everett7623"
GITHUB_REPO="PTtools"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main"
DOCKER_DIR="/opt/docker"
DOWNLOAD_DIR="/opt/downloads"
SCRIPT_VERSION="1.0.0"

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：此脚本必须以root用户运行！${NC}"
        exit 1
    fi
}

# 检查系统类型
check_system() {
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        OS="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        OS="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        OS="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        OS="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        OS="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        OS="centos"
    else
        echo -e "${RED}未检测到系统版本，请联系脚本作者！${NC}"
        exit 1
    fi
}

# 创建必要的目录
create_directories() {
    mkdir -p ${DOCKER_DIR}
    mkdir -p ${DOWNLOAD_DIR}
    echo -e "${GREEN}目录创建完成${NC}"
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker未安装，正在安装Docker...${NC}"
        install_docker
    else
        echo -e "${GREEN}Docker已安装${NC}"
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}Docker Compose未安装，正在安装...${NC}"
        install_docker_compose
    else
        echo -e "${GREEN}Docker Compose已安装${NC}"
    fi
}

# 安装Docker
install_docker() {
    echo -e "${CYAN}正在安装Docker...${NC}"
    curl -fsSL https://get.docker.com | bash -s docker
    systemctl start docker
    systemctl enable docker
    echo -e "${GREEN}Docker安装完成${NC}"
}

# 安装Docker Compose
install_docker_compose() {
    echo -e "${CYAN}正在安装Docker Compose...${NC}"
    
    # 安装Docker Compose插件
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    
    echo -e "${GREEN}Docker Compose安装完成${NC}"
}

# 显示主菜单
show_menu() {
    clear
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${CYAN}              PTtools 安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${GREEN}Github: https://github.com/${GITHUB_USER}/${GITHUB_REPO}${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo
    echo -e "${YELLOW}请选择要安装的应用：${NC}"
    echo
    echo -e "${WHITE}1.${NC} qBittorrent 4.3.8⭐"
    echo -e "${WHITE}2.${NC} qBittorrent 4.3.9⭐"
    echo -e "${WHITE}3.${NC} Vertex + qBittorrent 4.3.8🔥"
    echo -e "${WHITE}4.${NC} Vertex + qBittorrent 4.3.9🔥"
    echo -e "${WHITE}5.${NC} qBittorrent 4.6.7+Transmission4.0.5+emby+iyuuplus+moviepilot🔥"
    echo -e "${WHITE}6.${NC} PT Docker应用"
    echo -e "${WHITE}7.${NC} 系统优化"
    echo -e "${WHITE}8.${NC} 卸载应用"
    echo -e "${WHITE}9.${NC} 卸载脚本"
    echo -e "${WHITE}0.${NC} 退出脚本"
    echo
    echo -e "${PURPLE}================================================${NC}"
}

# 安装qBittorrent 4.3.8
install_qb438() {
    echo -e "${CYAN}正在安装qBittorrent 4.3.8...${NC}"
    
    # 下载并执行安装脚本
    wget -O /tmp/qb438.sh ${GITHUB_RAW_URL}/scripts/install/qb438.sh
    chmod +x /tmp/qb438.sh
    bash /tmp/qb438.sh
    rm -f /tmp/qb438.sh
    
    echo -e "${GREEN}qBittorrent 4.3.8安装完成！${NC}"
    read -p "按任意键返回主菜单..." -n 1
}

# 安装qBittorrent 4.3.9
install_qb439() {
    echo -e "${CYAN}正在安装qBittorrent 4.3.9...${NC}"
    
    # 下载并执行安装脚本
    wget -O /tmp/qb439.sh ${GITHUB_RAW_URL}/scripts/install/qb439.sh
    chmod +x /tmp/qb439.sh
    bash /tmp/qb439.sh
    rm -f /tmp/qb439.sh
    
    echo -e "${GREEN}qBittorrent 4.3.9安装完成！${NC}"
    read -p "按任意键返回主菜单..." -n 1
}

# 安装Vertex + qBittorrent 4.3.8
install_qb438_vt() {
    echo -e "${CYAN}正在安装Vertex + qBittorrent 4.3.8...${NC}"
    
    # 下载并执行安装脚本
    wget -O /tmp/qb438_vt.sh ${GITHUB_RAW_URL}/scripts/install/qb438_vt.sh
    chmod +x /tmp/qb438_vt.sh
    bash /tmp/qb438_vt.sh
    
    # 使用docker compose安装Vertex
    mkdir -p ${DOCKER_DIR}/vertex
    wget -O ${DOCKER_DIR}/vertex/docker-compose.yml ${GITHUB_RAW_URL}/config/docker-compose/vertex.yml
    cd ${DOCKER_DIR}/vertex && docker compose up -d
    
    rm -f /tmp/qb438_vt.sh
    
    echo -e "${GREEN}Vertex + qBittorrent 4.3.8安装完成！${NC}"
    echo -e "${YELLOW}Vertex访问地址: http://你的IP:3333${NC}"
    read -p "按任意键返回主菜单..." -n 1
}

# 安装Vertex + qBittorrent 4.3.9
install_qb439_vt() {
    echo -e "${CYAN}正在安装Vertex + qBittorrent 4.3.9...${NC}"
    
    # 下载并执行安装脚本
    wget -O /tmp/qb439_vt.sh ${GITHUB_RAW_URL}/scripts/install/qb439_vt.sh
    chmod +x /tmp/qb439_vt.sh
    bash /tmp/qb439_vt.sh
    
    # 使用docker compose安装Vertex
    mkdir -p ${DOCKER_DIR}/vertex
    wget -O ${DOCKER_DIR}/vertex/docker-compose.yml ${GITHUB_RAW_URL}/config/docker-compose/vertex.yml
    cd ${DOCKER_DIR}/vertex && docker compose up -d
    
    rm -f /tmp/qb439_vt.sh
    
    echo -e "${GREEN}Vertex + qBittorrent 4.3.9安装完成！${NC}"
    echo -e "${YELLOW}Vertex访问地址: http://你的IP:3333${NC}"
    read -p "按任意键返回主菜单..." -n 1
}

# 安装PT套装
install_pt_suite() {
    echo -e "${CYAN}正在安装PT套装...${NC}"
    echo -e "${YELLOW}包含: qBittorrent 4.6.7 + Transmission 4.0.5 + Emby + iyuuplus + MoviePilot${NC}"
    
    # 创建各应用目录
    apps=("qbittorrent" "transmission" "emby" "iyuuplus" "moviepilot")
    
    for app in "${apps[@]}"; do
        mkdir -p ${DOCKER_DIR}/${app}
        wget -O ${DOCKER_DIR}/${app}/docker-compose.yml ${GITHUB_RAW_URL}/config/docker-compose/${app}.yml
        cd ${DOCKER_DIR}/${app} && docker compose up -d
        echo -e "${GREEN}${app} 安装完成${NC}"
    done
    
    echo -e "${GREEN}PT套装安装完成！${NC}"
    echo -e "${YELLOW}访问地址：${NC}"
    echo -e "${YELLOW}qBittorrent: http://你的IP:8080${NC}"
    echo -e "${YELLOW}Transmission: http://你的IP:9091 (用户名: admin 密码: adminadmin)${NC}"
    echo -e "${YELLOW}Emby: http://你的IP:8096${NC}"
    echo -e "${YELLOW}iyuuplus: http://你的IP:8780${NC}"
    echo -e "${YELLOW}MoviePilot: http://你的IP:3000${NC}"
    read -p "按任意键返回主菜单..." -n 1
}

# PT Docker应用菜单
show_pt_apps_menu() {
    clear
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${CYAN}              PT Docker应用${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo
    echo -e "${YELLOW}▶ 下载管理${NC}"
    echo -e "  1. qBittorrent (最新版)"
    echo -e "  2. Transmission (4.0.5)"
    echo
    echo -e "${YELLOW}▶ 自动化管理${NC}"
    echo -e "  3. iyuuplus - PT站点自动化管理"
    echo -e "  4. MoviePilot - 电影自动下载管理"
    echo -e "  5. Vertex - 媒体管理工具"
    echo -e "  6. Sonarr - 电视剧自动化管理"
    echo -e "  7. Radarr - 电影自动化管理"
    echo -e "  8. Prowlarr - 索引器管理"
    echo
    echo -e "${YELLOW}▶ 媒体服务器${NC}"
    echo -e "  9. Emby - 媒体服务器"
    echo -e "  10. Jellyfin - 开源媒体服务器"
    echo -e "  11. Plex - 媒体服务器"
    echo
    echo -e "${YELLOW}▶ 文件管理${NC}"
    echo -e "  12. FileBrowser - 网页文件管理器"
    echo -e "  13. Alist - 网盘文件列表"
    echo
    echo -e "${WHITE}0.${NC} 返回主菜单"
    echo
    echo -e "${PURPLE}================================================${NC}"
}

# 系统优化菜单
show_optimize_menu() {
    clear
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${CYAN}              系统优化${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo
    echo -e "${WHITE}1.${NC} VPS性能优化 - BBR、TCP调优、文件描述符"
    echo -e "${WHITE}2.${NC} qBittorrent性能优化 - PTBoost优化器"
    echo -e "${WHITE}3.${NC} 磁盘I/O优化 - 调度器、缓存优化"
    echo -e "${WHITE}4.${NC} 网络连接优化 - 连接数、缓冲区优化"
    echo -e "${WHITE}5.${NC} 内存管理优化 - 交换、缓存策略"
    echo -e "${WHITE}6.${NC} 全部优化 - 一键应用所有优化"
    echo -e "${WHITE}7.${NC} 优化状态检查 - 查看当前优化状态"
    echo -e "${WHITE}0.${NC} 返回主菜单"
    echo
    echo -e "${PURPLE}================================================${NC}"
}

# 卸载应用菜单
show_uninstall_menu() {
    clear
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${CYAN}              卸载应用${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo
    echo -e "${WHITE}1.${NC} 卸载Docker应用"
    echo -e "${WHITE}2.${NC} 卸载qBittorrent (非Docker版)"
    echo -e "${WHITE}3.${NC} 卸载所有应用"
    echo -e "${WHITE}0.${NC} 返回主菜单"
    echo
    echo -e "${PURPLE}================================================${NC}"
}

# 卸载脚本
uninstall_script() {
    echo -e "${YELLOW}确定要卸载PTtools脚本吗？(y/N)${NC}"
    read -p "" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}正在卸载PTtools脚本...${NC}"
        rm -f /usr/local/bin/pttools
        rm -rf /opt/pttools
        echo -e "${GREEN}PTtools脚本已卸载${NC}"
        exit 0
    else
        echo -e "${YELLOW}取消卸载${NC}"
    fi
}

# 主程序
main() {
    check_root
    check_system
    create_directories
    check_docker
    
    while true; do
        show_menu
        read -p "请输入选项 [0-9]: " choice
        
        case $choice in
            1)
                install_qb438
                ;;
            2)
                install_qb439
                ;;
            3)
                install_qb438_vt
                ;;
            4)
                install_qb439_vt
                ;;
            5)
                install_pt_suite
                ;;
            6)
                while true; do
                    show_pt_apps_menu
                    read -p "请输入选项: " app_choice
                    if [[ $app_choice == "0" ]]; then
                        break
                    fi
                    # TODO: 实现各应用安装
                    echo -e "${YELLOW}功能开发中...${NC}"
                    read -p "按任意键继续..." -n 1
                done
                ;;
            7)
                while true; do
                    show_optimize_menu
                    read -p "请输入选项: " opt_choice
                    if [[ $opt_choice == "0" ]]; then
                        break
                    fi
                    # TODO: 实现系统优化
                    echo -e "${YELLOW}功能开发中...${NC}"
                    read -p "按任意键继续..." -n 1
                done
                ;;
            8)
                while true; do
                    show_uninstall_menu
                    read -p "请输入选项: " uninstall_choice
                    if [[ $uninstall_choice == "0" ]]; then
                        break
                    fi
                    # TODO: 实现卸载功能
                    echo -e "${YELLOW}功能开发中...${NC}"
                    read -p "按任意键继续..." -n 1
                done
                ;;
            9)
                uninstall_script
                ;;
            0)
                echo -e "${GREEN}感谢使用PTtools！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                read -p "按任意键继续..." -n 1
                ;;
        esac
    done
}

# 运行主程序
main