#!/bin/bash
#
# 脚本名称: pttools.sh
# 脚本描述: PTtools - PT常用工具一键安装脚本
# 脚本路径: https://github.com/everett7623/PTtools/blob/main/pttools.sh
# 使用方法: bash <(wget -qO- https://raw.githubusercontent.com/everett7623/PTtools/main/pttools.sh)
# 作者: everett7623
# 更新时间: 2025-06-24
# 版本: v1.0.0
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
GITHUB_USER="everett7623"
GITHUB_REPO="PTtools"
GITHUB_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main"
DOCKER_DIR="/opt/docker"
DOWNLOAD_DIR="/opt/downloads"
SCRIPT_VERSION="v1.0.0"

# 显示logo
show_logo() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║                      PTtools 一键安装脚本                      ║"
    echo "║                                                               ║"
    echo "║                    Version: ${SCRIPT_VERSION}                          ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        echo -e "${YELLOW}请使用 sudo -i 切换到root用户后再运行${NC}"
        exit 1
    fi
}

# 检查系统
check_system() {
    if [[ -f /etc/redhat-release ]]; then
        SYSTEM="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        SYSTEM="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        SYSTEM="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        SYSTEM="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        SYSTEM="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        SYSTEM="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        SYSTEM="centos"
    else
        echo -e "${RED}不支持的操作系统！${NC}"
        exit 1
    fi
}

# 创建必要的目录
create_directories() {
    mkdir -p ${DOCKER_DIR}
    mkdir -p ${DOWNLOAD_DIR}
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}检测到Docker未安装${NC}"
        echo -e "${CYAN}请选择Docker安装方式:${NC}"
        echo "1) 官方源安装（国外服务器推荐）"
        echo "2) 阿里云镜像安装（国内服务器推荐）"
        echo "3) 跳过Docker安装"
        read -p "请选择 [1-3]: " docker_choice
        
        case $docker_choice in
            1)
                echo -e "${GREEN}正在从官方源安装Docker...${NC}"
                curl -fsSL https://get.docker.com | bash -s docker
                ;;
            2)
                echo -e "${GREEN}正在从阿里云镜像安装Docker...${NC}"
                curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
                ;;
            3)
                echo -e "${YELLOW}跳过Docker安装${NC}"
                ;;
            *)
                echo -e "${RED}无效选择，跳过Docker安装${NC}"
                ;;
        esac
        
        # 检查是否需要安装docker-compose
        if command -v docker &> /dev/null && ! command -v docker-compose &> /dev/null; then
            echo -e "${YELLOW}检测到docker-compose未安装${NC}"
            read -p "是否安装docker-compose? [y/N]: " install_compose
            if [[ "$install_compose" =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}正在安装docker-compose...${NC}"
                curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                chmod +x /usr/local/bin/docker-compose
            fi
        fi
        
        # 启动Docker服务
        if command -v docker &> /dev/null; then
            systemctl enable docker
            systemctl start docker
            echo -e "${GREEN}Docker服务已启动${NC}"
        fi
    fi
}

# 显示主菜单
show_menu() {
    echo ""
    echo -e "${PURPLE}==================== PTtools 主菜单 ====================${NC}"
    echo -e "${GREEN}1.${NC} qBittorrent 4.3.8⭐"
    echo -e "${GREEN}2.${NC} qBittorrent 4.3.9⭐"
    echo -e "${GREEN}3.${NC} Vertex + qBittorrent 4.3.8🔥"
    echo -e "${GREEN}4.${NC} Vertex + qBittorrent 4.3.9🔥"
    echo -e "${GREEN}5.${NC} qBittorrent 4.6.7 + Transmission 4.0.5 + emby + iyuuplus + moviepilot🔥"
    echo -e "${GREEN}6.${NC} PT Docker应用 ${YELLOW}(待开发)${NC}"
    echo -e "${GREEN}7.${NC} 系统优化 ${YELLOW}(待开发)${NC}"
    echo -e "${GREEN}8.${NC} 卸载应用"
    echo -e "${GREEN}9.${NC} 卸载脚本"
    echo -e "${GREEN}0.${NC} 退出脚本"
    echo -e "${PURPLE}=======================================================${NC}"
}

# 执行安装脚本
execute_install_script() {
    local script_name=$1
    local script_url="${GITHUB_RAW_URL}/scripts/install/${script_name}"
    
    echo -e "${GREEN}正在下载并执行安装脚本: ${script_name}${NC}"
    
    # 下载并执行脚本
    if wget -qO- ${script_url} | bash; then
        echo -e "${GREEN}安装完成！${NC}"
    else
        echo -e "${RED}安装失败！${NC}"
    fi
    
    read -p "按任意键返回主菜单..." -n 1 -r
}

# 卸载应用菜单
uninstall_menu() {
    clear
    show_logo
    echo -e "${PURPLE}==================== 卸载应用 ====================${NC}"
    echo -e "${GREEN}1.${NC} 卸载 qBittorrent"
    echo -e "${GREEN}2.${NC} 卸载 Transmission"
    echo -e "${GREEN}3.${NC} 卸载 Emby"
    echo -e "${GREEN}4.${NC} 卸载 iyuuplus"
    echo -e "${GREEN}5.${NC} 卸载 MoviePilot"
    echo -e "${GREEN}6.${NC} 卸载 Vertex"
    echo -e "${GREEN}7.${NC} 卸载所有Docker容器和镜像"
    echo -e "${GREEN}0.${NC} 返回主菜单"
    echo -e "${PURPLE}=================================================${NC}"
    
    read -p "请选择要卸载的应用 [0-7]: " uninstall_choice
    
    case $uninstall_choice in
        1)
            echo -e "${YELLOW}正在卸载 qBittorrent...${NC}"
            systemctl stop qbittorrent 2>/dev/null || true
            systemctl disable qbittorrent 2>/dev/null || true
            rm -rf /usr/local/qbittorrent
            rm -f /etc/systemd/system/qbittorrent.service
            docker stop qbittorrent 2>/dev/null || true
            docker rm qbittorrent 2>/dev/null || true
            echo -e "${GREEN}qBittorrent 已卸载${NC}"
            ;;
        2)
            echo -e "${YELLOW}正在卸载 Transmission...${NC}"
            docker stop transmission 2>/dev/null || true
            docker rm transmission 2>/dev/null || true
            rm -rf ${DOCKER_DIR}/transmission
            echo -e "${GREEN}Transmission 已卸载${NC}"
            ;;
        3)
            echo -e "${YELLOW}正在卸载 Emby...${NC}"
            docker stop emby 2>/dev/null || true
            docker rm emby 2>/dev/null || true
            rm -rf ${DOCKER_DIR}/emby
            echo -e "${GREEN}Emby 已卸载${NC}"
            ;;
        4)
            echo -e "${YELLOW}正在卸载 iyuuplus...${NC}"
            docker stop iyuuplus 2>/dev/null || true
            docker rm iyuuplus 2>/dev/null || true
            rm -rf ${DOCKER_DIR}/iyuuplus
            echo -e "${GREEN}iyuuplus 已卸载${NC}"
            ;;
        5)
            echo -e "${YELLOW}正在卸载 MoviePilot...${NC}"
            docker stop moviepilot 2>/dev/null || true
            docker rm moviepilot 2>/dev/null || true
            rm -rf ${DOCKER_DIR}/moviepilot
            echo -e "${GREEN}MoviePilot 已卸载${NC}"
            ;;
        6)
            echo -e "${YELLOW}正在卸载 Vertex...${NC}"
            docker stop vertex 2>/dev/null || true
            docker rm vertex 2>/dev/null || true
            rm -rf ${DOCKER_DIR}/vertex
            echo -e "${GREEN}Vertex 已卸载${NC}"
            ;;
        7)
            echo -e "${RED}警告: 这将删除所有Docker容器和镜像！${NC}"
            read -p "确定要继续吗? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                docker stop $(docker ps -aq) 2>/dev/null || true
                docker rm $(docker ps -aq) 2>/dev/null || true
                docker rmi $(docker images -q) 2>/dev/null || true
                echo -e "${GREEN}所有Docker容器和镜像已删除${NC}"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            ;;
    esac
    
    read -p "按任意键继续..." -n 1 -r
    uninstall_menu
}

# 卸载脚本
uninstall_script() {
    clear
    show_logo
    echo -e "${RED}警告: 这将完全卸载PTtools脚本及其所有组件！${NC}"
    echo -e "${YELLOW}这包括:${NC}"
    echo "- 所有已安装的应用"
    echo "- 所有配置文件"
    echo "- 所有下载的文件"
    echo ""
    read -p "确定要完全卸载PTtools吗? [y/N]: " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}正在卸载PTtools...${NC}"
        
        # 停止所有相关服务
        systemctl stop qbittorrent 2>/dev/null || true
        systemctl disable qbittorrent 2>/dev/null || true
        
        # 停止并删除所有相关Docker容器
        docker stop $(docker ps -a | grep -E "qbittorrent|transmission|emby|iyuuplus|moviepilot|vertex" | awk '{print $1}') 2>/dev/null || true
        docker rm $(docker ps -a | grep -E "qbittorrent|transmission|emby|iyuuplus|moviepilot|vertex" | awk '{print $1}') 2>/dev/null || true
        
        # 删除目录
        rm -rf ${DOCKER_DIR}
        rm -rf ${DOWNLOAD_DIR}
        rm -rf /usr/local/qbittorrent
        
        # 删除脚本自身
        SCRIPT_PATH="$0"
        rm -f "$SCRIPT_PATH"
        
        echo -e "${GREEN}PTtools已完全卸载！${NC}"
        echo -e "${YELLOW}感谢使用PTtools！${NC}"
        exit 0
    else
        echo -e "${GREEN}已取消卸载${NC}"
        read -p "按任意键返回主菜单..." -n 1 -r
    fi
}

# 主函数
main() {
    check_root
    check_system
    create_directories
    
    while true; do
        show_logo
        show_menu
        
        read -p "请输入选项 [0-9]: " choice
        
        case $choice in
            1)
                check_docker
                execute_install_script "qb438.sh"
                ;;
            2)
                check_docker
                execute_install_script "qb439.sh"
                ;;
            3)
                check_docker
                execute_install_script "qb438_vt.sh"
                ;;
            4)
                check_docker
                execute_install_script "qb439_vt.sh"
                ;;
            5)
                check_docker
                echo -e "${YELLOW}功能开发中...${NC}"
                read -p "按任意键返回主菜单..." -n 1 -r
                ;;
            6)
                echo -e "${YELLOW}功能开发中...${NC}"
                read -p "按任意键返回主菜单..." -n 1 -r
                ;;
            7)
                echo -e "${YELLOW}功能开发中...${NC}"
                read -p "按任意键返回主菜单..." -n 1 -r
                ;;
            8)
                uninstall_menu
                ;;
            9)
                uninstall_script
                ;;
            0)
                echo -e "${GREEN}感谢使用PTtools！再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择，请重新输入${NC}"
                read -p "按任意键继续..." -n 1 -r
                ;;
        esac
    done
}

# 运行主函数
main
