#!/bin/bash

# PTtools - PT工具一键安装脚本
# 作者：everett7623
# GitHub：https://github.com/everett7623/PTtools

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 基础配置
DOCKER_DIR="/opt/docker"
GITHUB_RAW_URL="https://raw.githubusercontent.com/everett7623/PTtools/main"
SCRIPT_VERSION="1.0.0"

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}║${YELLOW}                    PTtools 一键安装脚本                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN}                     版本：${SCRIPT_VERSION}                                ${CYAN}║${NC}"
    echo -e "${CYAN}║${BLUE}              作者：everett7623                                ${CYAN}║${NC}"
    echo -e "${CYAN}║${PURPLE}     GitHub：https://github.com/everett7623/PTtools          ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "错误：此脚本必须以root权限运行！"
        print_message $YELLOW "请使用 'sudo' 或切换到root用户后再运行"
        exit 1
    fi
}

# 检查系统
check_system() {
    if [[ ! -f /etc/os-release ]]; then
        print_message $RED "错误：无法识别操作系统！"
        exit 1
    fi
    
    source /etc/os-release
    OS=$NAME
    print_message $GREEN "检测到系统：$OS"
}

# 检查Docker是否安装
check_docker() {
    if command -v docker &> /dev/null; then
        print_message $GREEN "Docker 已安装"
        docker --version
        return 0
    else
        print_message $YELLOW "Docker 未安装"
        return 1
    fi
}

# 安装Docker
install_docker() {
    print_message $BLUE "正在安装 Docker..."
    
    echo -e "${CYAN}请选择安装方式：${NC}"
    echo "1. 直接安装（默认）"
    echo "2. 使用阿里云镜像安装（国内推荐）"
    echo -n "请输入选择 [1-2]: "
    read -r docker_choice
    
    case $docker_choice in
        2)
            print_message $YELLOW "使用阿里云镜像安装 Docker..."
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            ;;
        *)
            print_message $YELLOW "直接安装 Docker..."
            curl -fsSL https://get.docker.com | bash -s docker
            ;;
    esac
    
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
    
    # 安装docker-compose
    print_message $BLUE "正在安装 docker-compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    print_message $GREEN "Docker 和 docker-compose 安装完成！"
}

# 创建Docker工作目录
create_docker_dir() {
    print_message $BLUE "创建 Docker 工作目录..."
    mkdir -p $DOCKER_DIR
    chmod -R 777 $DOCKER_DIR
    print_message $GREEN "Docker 工作目录创建完成：$DOCKER_DIR"
}

# 安装qBittorrent 4.3.8
install_qb438() {
    print_message $BLUE "正在安装 qBittorrent 4.3.8..."
    
    # 下载并执行安装脚本
    wget -O /tmp/qb438.sh "${GITHUB_RAW_URL}/scripts/install/qb438.sh"
    chmod +x /tmp/qb438.sh
    bash /tmp/qb438.sh
    rm -f /tmp/qb438.sh
}

# 安装qBittorrent 4.3.9
install_qb439() {
    print_message $BLUE "正在安装 qBittorrent 4.3.9..."
    
    # 下载并执行安装脚本
    wget -O /tmp/qb439.sh "${GITHUB_RAW_URL}/scripts/install/qb439.sh"
    chmod +x /tmp/qb439.sh
    bash /tmp/qb439.sh
    rm -f /tmp/qb439.sh
}

# 安装Vertex
install_vertex() {
    print_message $BLUE "正在安装 Vertex..."
    
    # 创建Vertex目录
    mkdir -p $DOCKER_DIR/vertex
    
    # 下载docker-compose配置
    wget -O $DOCKER_DIR/vertex/docker-compose.yml "${GITHUB_RAW_URL}/configs/docker-compose/vertex.yml"
    
    # 启动Vertex
    cd $DOCKER_DIR/vertex
    docker-compose up -d
    
    print_message $GREEN "Vertex 安装完成！"
    print_message $YELLOW "访问地址：http://你的服务器IP:3334"
}

# 安装qBittorrent 4.3.8 + Vertex
install_qb438_vertex() {
    install_qb438
    install_vertex
    print_message $GREEN "qBittorrent 4.3.8 + Vertex 安装完成！"
}

# 安装qBittorrent 4.3.9 + Vertex
install_qb439_vertex() {
    install_qb439
    install_vertex
    print_message $GREEN "qBittorrent 4.3.9 + Vertex 安装完成！"
}

# 卸载功能
uninstall_app() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                         卸载管理                              ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "1. 卸载 qBittorrent"
    echo "2. 卸载 Vertex"
    echo "3. 卸载所有应用"
    echo "0. 返回主菜单"
    echo
    echo -n "请选择要卸载的应用 [0-3]: "
    read -r uninstall_choice
    
    case $uninstall_choice in
        1)
            print_message $YELLOW "卸载 qBittorrent..."
            systemctl stop qbittorrent
            systemctl disable qbittorrent
            rm -rf /usr/local/qbittorrent
            rm -f /etc/systemd/system/qbittorrent.service
            systemctl daemon-reload
            print_message $GREEN "qBittorrent 卸载完成！"
            ;;
        2)
            print_message $YELLOW "卸载 Vertex..."
            cd $DOCKER_DIR/vertex && docker-compose down
            rm -rf $DOCKER_DIR/vertex
            print_message $GREEN "Vertex 卸载完成！"
            ;;
        3)
            print_message $RED "警告：这将卸载所有已安装的应用！"
            echo -n "确定要继续吗？[y/N]: "
            read -r confirm
            if [[ $confirm == "y" || $confirm == "Y" ]]; then
                # 卸载qBittorrent
                systemctl stop qbittorrent 2>/dev/null
                systemctl disable qbittorrent 2>/dev/null
                rm -rf /usr/local/qbittorrent
                rm -f /etc/systemd/system/qbittorrent.service
                
                # 卸载所有Docker容器
                cd $DOCKER_DIR
                for dir in */; do
                    if [[ -f "$dir/docker-compose.yml" ]]; then
                        cd "$DOCKER_DIR/$dir" && docker-compose down
                    fi
                done
                
                # 清理目录
                rm -rf $DOCKER_DIR/*
                systemctl daemon-reload
                print_message $GREEN "所有应用卸载完成！"
            else
                print_message $YELLOW "取消卸载操作"
            fi
            ;;
        0)
            return
            ;;
        *)
            print_message $RED "无效的选择！"
            ;;
    esac
    
    echo
    echo -n "按任意键继续..."
    read -n 1
}

# 显示主菜单
show_main_menu() {
    while true; do
        show_welcome
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                     核心项目安装选项                          ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo "1. 安装 qBittorrent 4.3.8"
        echo "2. 安装 qBittorrent 4.3.9"
        echo "3. 安装 qBittorrent 4.3.8 + Vertex"
        echo "4. 安装 qBittorrent 4.3.9 + Vertex"
        echo "5. 选择安装应用（功能开发中...）"
        echo
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                        系统管理                               ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo "6. 卸载管理"
        echo "0. 退出脚本"
        echo
        echo -n "请输入选项 [0-6]: "
        read -r choice
        
        case $choice in
            1)
                install_qb438
                ;;
            2)
                install_qb439
                ;;
            3)
                install_qb438_vertex
                ;;
            4)
                install_qb439_vertex
                ;;
            5)
                print_message $YELLOW "功能开发中，敬请期待..."
                ;;
            6)
                uninstall_app
                continue
                ;;
            0)
                print_message $GREEN "感谢使用 PTtools！"
                exit 0
                ;;
            *)
                print_message $RED "无效的选择，请重新输入！"
                ;;
        esac
        
        echo
        echo -n "按任意键返回主菜单..."
        read -n 1
    done
}

# 主函数
main() {
    # 检查权限
    check_root
    
    # 检查系统
    check_system
    
    # 检查并安装Docker
    if ! check_docker; then
        echo -n "是否安装 Docker？[Y/n]: "
        read -r install_docker_choice
        if [[ $install_docker_choice != "n" && $install_docker_choice != "N" ]]; then
            install_docker
        else
            print_message $RED "Docker 是必需的，退出安装！"
            exit 1
        fi
    fi
    
    # 创建Docker工作目录
    create_docker_dir
    
    # 显示主菜单
    show_main_menu
}

# 运行主函数
main