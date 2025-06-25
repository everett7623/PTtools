#!/bin/bash

# PTtools - PT工具一键安装脚本
# 脚本名称: pttools.sh
# 脚本描述: PT工具一键安装脚本，支持qBittorrent、Transmission、Emby等应用的快捷安装
# 脚本路径: https://raw.githubusercontent.com/everett7623/PTtools/main/pttools.sh
# 使用方法: wget -O pttools.sh https://raw.githubusercontent.com/everett7623/PTtools/main/pttools.sh && chmod +x pttools.sh && ./pttools.sh
# 作者: everett7623
# 更新时间: 2025-06-25

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 全局变量
DOCKER_DIR="/opt/docker"
DOWNLOADS_DIR="/opt/downloads"
GITHUB_RAW="https://raw.githubusercontent.com/everett7623/PTtools/main"

# 显示横幅
show_banner() {
    echo -e "${CYAN}"
    echo "=================================================="
    echo "           PTtools - PT工具一键安装脚本"
    echo "               作者: everett7623"
    echo "=================================================="
    echo -e "${NC}"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：此脚本需要root权限运行${NC}"
        echo "请使用 sudo 或切换到root用户后重新运行"
        exit 1
    fi
}

# 检查系统类型
check_system() {
    if [[ -f /etc/redhat-release ]]; then
        DISTRO="centos"
        PM="yum"
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
        PM="apt"
    else
        echo -e "${RED}不支持的系统类型${NC}"
        exit 1
    fi
    echo -e "${GREEN}系统类型: $DISTRO${NC}"
}

# 更新系统
update_system() {
    echo -e "${YELLOW}正在更新系统...${NC}"
    if [[ $DISTRO == "debian" ]]; then
        apt update -y && apt upgrade -y
    elif [[ $DISTRO == "centos" ]]; then
        yum update -y
    fi
}

# 安装基础工具
install_base_tools() {
    echo -e "${YELLOW}正在安装基础工具...${NC}"
    if [[ $DISTRO == "debian" ]]; then
        apt install -y curl wget git unzip
    elif [[ $DISTRO == "centos" ]]; then
        yum install -y curl wget git unzip
    fi
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker未安装，是否现在安装Docker？(y/n)${NC}"
        read -r install_docker
        if [[ $install_docker =~ ^[Yy]$ ]]; then
            install_docker_func
        else
            echo -e "${RED}部分功能需要Docker支持${NC}"
        fi
    else
        echo -e "${GREEN}Docker已安装${NC}"
    fi
}

# 安装Docker
install_docker_func() {
    echo -e "${YELLOW}正在安装Docker...${NC}"
    echo -e "${YELLOW}选择安装源：${NC}"
    echo "1. 官方源（默认）"
    echo "2. 阿里云镜像源"
    read -p "请选择 [1-2]: " docker_source
    
    case $docker_source in
        2)
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            ;;
        *)
            curl -fsSL https://get.docker.com | bash -s docker
            ;;
    esac
    
    systemctl start docker
    systemctl enable docker
    
    echo -e "${YELLOW}是否安装Docker Compose？(y/n)${NC}"
    read -r install_compose
    if [[ $install_compose =~ ^[Yy]$ ]]; then
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        echo -e "${GREEN}Docker Compose安装完成${NC}"
    fi
}

# 创建必要目录
create_directories() {
    echo -e "${YELLOW}正在创建必要目录...${NC}"
    mkdir -p "$DOCKER_DIR"
    mkdir -p "$DOWNLOADS_DIR"
    echo -e "${GREEN}目录创建完成${NC}"
    echo -e "${GREEN}Docker目录: $DOCKER_DIR${NC}"
    echo -e "${GREEN}下载目录: $DOWNLOADS_DIR${NC}"
}

# 安装qBittorrent 4.3.8
install_qb438() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}正在安装 qBittorrent 4.3.8${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo
    echo -e "${YELLOW}此功能将调用原作者脚本进行安装${NC}"
    echo -e "${YELLOW}原作者：iniwex5${NC}"
    echo -e "${YELLOW}脚本来源：https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh${NC}"
    echo
    echo -e "${RED}注意：安装过程中请按照原脚本提示进行操作${NC}"
    echo
    read -p "是否继续安装？(y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi
    
    echo -e "${YELLOW}正在下载并执行安装脚本...${NC}"
    
    # 下载并执行原作者脚本
    if curl -fsSL https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh | bash; then
        echo
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}qBittorrent 4.3.8 安装完成！${NC}"
        echo -e "${GREEN}================================================${NC}"
    else
        echo
        echo -e "${RED}================================================${NC}"
        echo -e "${RED}qBittorrent 4.3.8 安装失败！${NC}"
        echo -e "${RED}================================================${NC}"
    fi
    
    echo
    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
    read -n 1
}

# 显示主菜单
show_menu() {
    clear
    show_banner
    echo -e "${GREEN}请选择要安装的应用：${NC}"
    echo
    echo -e "${WHITE}├── 1. qBittorrent 4.3.8⭐${NC}"
    echo -e "${WHITE}├── 2. qBittorrent 4.3.9⭐${NC}"
    echo -e "${WHITE}├── 3. Vertex + qBittorrent 4.3.8🔥${NC}"
    echo -e "${WHITE}├── 4. Vertex + qBittorrent 4.3.9🔥${NC}"
    echo -e "${WHITE}├── 5. qBittorrent 4.6.7 + Transmission 4.0.5 + emby + iyuuplus + moviepilot🔥${NC}"
    echo -e "${WHITE}├── 6. PT Docker应用 (功能分类与工具列表, 以后添加)${NC}"
    echo -e "${WHITE}├── 7. 系统优化 (VPS性能调优, 以后添加)${NC}"
    echo -e "${WHITE}├── 8. 卸载应用${NC}"
    echo -e "${WHITE}├── 9. 卸载脚本${NC}"
    echo -e "${WHITE}└── 0. 退出脚本${NC}"
    echo
    echo -e "${BLUE}当前Docker目录: $DOCKER_DIR${NC}"
    echo -e "${BLUE}当前下载目录: $DOWNLOADS_DIR${NC}"
    echo
}

# 主程序
main() {
    # 初始化检查
    check_root
    check_system
    
    while true; do
        show_menu
        read -p "请输入选项 [0-9]: " choice
        
        case $choice in
            1)
                install_qb438
                ;;
            2)
                echo -e "${YELLOW}qBittorrent 4.3.9 功能开发中...${NC}"
                echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                read -n 1
                ;;
            3)
                echo -e "${YELLOW}Vertex + qBittorrent 4.3.8 功能开发中...${NC}"
                echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                read -n 1
                ;;
            4)
                echo -e "${YELLOW}Vertex + qBittorrent 4.3.9 功能开发中...${NC}"
                echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                read -n 1
                ;;
            5)
                echo -e "${YELLOW}全套Docker应用安装功能开发中...${NC}"
                echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                read -n 1
                ;;
            6)
                echo -e "${YELLOW}PT Docker应用功能开发中...${NC}"
                echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                read -n 1
                ;;
            7)
                echo -e "${YELLOW}系统优化功能开发中...${NC}"
                echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                read -n 1
                ;;
            8)
                echo -e "${YELLOW}卸载功能开发中...${NC}"
                echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                read -n 1
                ;;
            9)
                echo -e "${YELLOW}正在卸载脚本...${NC}"
                rm -f "$0"
                echo -e "${GREEN}脚本已删除${NC}"
                exit 0
                ;;
            0)
                echo -e "${GREEN}感谢使用PTtools！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                echo -e "${YELLOW}按任意键继续...${NC}"
                read -n 1
                ;;
        esac
    done
}

# 初始化环境
echo -e "${YELLOW}正在初始化环境...${NC}"
update_system
install_base_tools
check_docker
create_directories

echo -e "${GREEN}环境初始化完成！${NC}"
echo -e "${YELLOW}按任意键进入主菜单...${NC}"
read -n 1

# 运行主程序
main
