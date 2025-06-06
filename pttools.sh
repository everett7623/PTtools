#!/bin/bash

# PTtools 一键安装脚本
# Github: https://github.com/everett7623/pttools
# 作者: everett7623

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 全局变量
DOCKER_PATH="/opt/docker"
LOG_FILE="/tmp/pttools_install.log"
GITHUB_USER="everett7623"
GITHUB_REPO="pttools"

# 显示安装成功信息
show_success_info() {
    local app_name="$1"
    local info="$2"
    
    print_color $GREEN "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_color $WHITE "🎉 $app_name 安装成功！"
    print_color $CYAN "$info"
    print_color $GREEN "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 打印带颜色的文本
print_color() {
    printf "${1}${2}${NC}\n"
}

# 日志记录函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 显示横幅
show_banner() {
    clear
    print_color $CYAN "
╔══════════════════════════════════════════════════════════════╗
║                      PTtools 一键安装脚本                      ║
║                    为PT爱好者量身定制                          ║
║              Github: everett7623/pttools                     ║
╚══════════════════════════════════════════════════════════════╝
"
}

# 检查系统环境
check_system() {
    print_color $YELLOW "正在检查系统环境..."
    
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        print_color $RED "错误: 请使用root用户运行此脚本"
        exit 1
    fi
    
    # 检查系统类型
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
    else
        print_color $RED "错误: 不支持的操作系统"
        exit 1
    fi
    
    print_color $GREEN "系统检查完成: $OS"
    log "系统检查完成: $OS"
}

# 安装Docker
install_docker() {
    if command -v docker &> /dev/null; then
        print_color $GREEN "Docker 已安装"
        return 0
    fi
    
    print_color $YELLOW "正在安装 Docker..."
    
    if [[ $OS == "debian" ]]; then
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    elif [[ $OS == "centos" ]]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi
    
    systemctl start docker
    systemctl enable docker
    
    # 安装docker-compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    print_color $GREEN "Docker 安装完成"
    log "Docker 安装完成"
}

# 创建目录结构
create_directories() {
    print_color $YELLOW "正在创建目录结构..."
    
    mkdir -p "$DOCKER_PATH"
    chmod -R 777 "$DOCKER_PATH"
    mkdir -p "$DOCKER_PATH"/{qbittorrent,transmission,emby,iyuuplus,moviepilot,vertex}
    mkdir -p /opt/downloads
    chmod -R 777 /opt/downloads
    
    print_color $GREEN "目录结构创建完成"
    log "目录结构创建完成"
}

# 获取VPS信息用于优化
get_vps_info() {
    CPU_CORES=$(nproc)
    TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    
    # 根据VPS性能设置qB缓存大小
    if [[ $TOTAL_RAM -le 1024 ]]; then
        QB_CACHE=64
    elif [[ $TOTAL_RAM -le 2048 ]]; then
        QB_CACHE=128
    elif [[ $TOTAL_RAM -le 4096 ]]; then
        QB_CACHE=256
    else
        QB_CACHE=512
    fi
    
    print_color $BLUE "VPS信息: CPU核心数=$CPU_CORES, 内存=${TOTAL_RAM}MB, 建议缓存=${QB_CACHE}MB"
    log "VPS信息: CPU=$CPU_CORES cores, RAM=${TOTAL_RAM}MB, Cache=${QB_CACHE}MB"
}

# 安装qBittorrent 4.3.8 (PT脚本)
install_qb_438() {
    local combo_mode=${1:-"single"}
    print_color $YELLOW "正在安装 qBittorrent 4.3.8 (PT脚本)..."
    
    # 生成随机用户名和密码
    QB_USER="admin"
    QB_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-10)
    QB_PORT=8080
    QB_LISTEN_PORT=23333
    
    print_color $BLUE "qBittorrent 登录信息:"
    print_color $WHITE "用户名: $QB_USER"
    print_color $WHITE "密码: $QB_PASS"
    print_color $WHITE "WebUI端口: $QB_PORT"
    print_color $WHITE "监听端口: $QB_LISTEN_PORT"
    
    # 从自己的GitHub仓库下载安装脚本
    bash <(wget -qO- https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/scripts/qb438.sh) "$QB_USER" "$QB_PASS" "$QB_PORT" "$QB_LISTEN_PORT"
    
    if [[ $? -eq 0 ]]; then
        print_color $GREEN "qBittorrent 4.3.8 安装完成"
        log "qBittorrent 4.3.8 安装完成 - 用户名: $QB_USER, 密码: $QB_PASS"
        
        # 显示安装信息
        if [[ $combo_mode == "single" ]]; then
            show_success_info "qBittorrent 4.3.8 (PT脚本版本)" "
   🌐 登录地址: http://你的服务器IP:$QB_PORT
   👤 用户名: $QB_USER
   🔑 密码: $QB_PASS
   🔧 监听端口: $QB_LISTEN_PORT"
        fi
    else
        print_color $RED "qBittorrent 4.3.8 安装失败"
        log "qBittorrent 4.3.8 安装失败"
        return 1
    fi
}

# 安装qBittorrent 4.3.9 (杰瑞大佬脚本)
install_qb_439() {
    local combo_mode=${1:-"single"}
    print_color $YELLOW "正在安装 qBittorrent 4.3.9 (杰瑞大佬脚本)..."
    
    # 生成随机用户名和密码
    QB_USER="admin"
    QB_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-10)
    
    print_color $BLUE "qBittorrent 登录信息:"
    print_color $WHITE "用户名: $QB_USER"
    print_color $WHITE "密码: $QB_PASS"
    print_color $WHITE "缓存大小: ${QB_CACHE}MB"
    
    # 从自己的GitHub仓库下载安装脚本
    bash <(wget -qO- https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/scripts/qb439.sh) \
        -u "$QB_USER" \
        -p "$QB_PASS" \
        -c "$QB_CACHE" \
        -q \
        -l \
        -3
    
    if [[ $? -eq 0 ]]; then
        print_color $GREEN "qBittorrent 4.3.9 安装完成"
        log "qBittorrent 4.3.9 安装完成 - 用户名: $QB_USER, 密码: $QB_PASS"
        
        # 显示安装信息
        if [[ $combo_mode == "single" ]]; then
            show_success_info "qBittorrent 4.3.9 (杰瑞大佬脚本)" "
   🌐 登录地址: http://你的服务器IP:8080
   👤 用户名: $QB_USER
   🔑 密码: $QB_PASS
   💾 缓存大小: ${QB_CACHE}MB
   ⚡ 已启用BBR v3优化"
        fi
    else
        print_color $RED "qBittorrent 4.3.9 安装失败"
        log "qBittorrent 4.3.9 安装失败"
        return 1
    fi
}

# 显示组合安装信息
show_combo_success() {
    local qb_version="$1"
    local qb_user="$QB_USER"
    local qb_pass="$QB_PASS"
    
    print_color $GREEN "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ $qb_version == "4.3.8" ]]; then
        print_color $WHITE "🔥 组合安装成功: qBittorrent 4.3.8 + Vertex"
        print_color $CYAN "
📥 qBittorrent 4.3.8 (PT脚本版本):
   🌐 登录地址: http://你的服务器IP:8080
   👤 用户名: $qb_user
   🔑 密码: $qb_pass
   🔧 监听端口: 23333

🔧 Vertex 媒体管理工具:
   🌐 登录地址: http://你的服务器IP:3334
   ℹ️  说明: 初次访问需要设置管理员账号密码"
    else
        print_color $WHITE "🔥 组合安装成功: qBittorrent 4.3.9 + Vertex"
        print_color $CYAN "
📥 qBittorrent 4.3.9 (杰瑞大佬脚本):
   🌐 登录地址: http://你的服务器IP:8080
   👤 用户名: $qb_user
   🔑 密码: $qb_pass
   💾 缓存大小: ${QB_CACHE}MB
   ⚡ 已启用BBR v3优化

🔧 Vertex 媒体管理工具:
   🌐 登录地址: http://你的服务器IP:3334
   ℹ️  说明: 初次访问需要设置管理员账号密码"
    fi
    print_color $GREEN "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 安装Vertex
install_vertex() {
    local combo_mode=${1:-"single"}
    print_color $YELLOW "正在安装 Vertex..."
    
    # 创建vertex目录
    mkdir -p "$DOCKER_PATH/vertex"
    
    # 创建vertex的docker-compose文件
    cat > "$DOCKER_PATH/vertex/docker-compose.yml" << EOF
version: '3'
services:
  vertex:
    image: lswl/vertex:stable
    container_name: vertex
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - $DOCKER_PATH/vertex:/vertex
    ports:
      - 3334:3000
    restart: unless-stopped
EOF
    
    cd "$DOCKER_PATH/vertex"
    docker-compose up -d
    
    if [[ $? -eq 0 ]]; then
        print_color $GREEN "Vertex 安装完成"
        log "Vertex 安装完成"
        
        # 显示安装信息
        if [[ $combo_mode == "single" ]]; then
            show_success_info "Vertex 媒体管理工具" "
   🌐 登录地址: http://你的服务器IP:3334
   ℹ️  说明: 初次访问需要设置管理员账号密码
   📁 数据目录: $DOCKER_PATH/vertex"
        fi
    else
        print_color $RED "Vertex 安装失败"
        log "Vertex 安装失败"
        return 1
    fi
}

# 显示主菜单
show_menu() {
    show_banner
    print_color $WHITE "请选择要安装的选项:"
    echo
    print_color $GREEN "▶ 核心安装选项 (PT刷流优化)"
    print_color $YELLOW "  1. qBittorrent 4.3.8 (PT脚本版本)"
    print_color $YELLOW "  2. qBittorrent 4.3.9 (杰瑞大佬脚本)"
    print_color $YELLOW "  3. qBittorrent 4.3.8 + Vertex"
    print_color $YELLOW "  4. qBittorrent 4.3.9 + Vertex"
    echo
    print_color $CYAN "▶ 管理选项"
    print_color $YELLOW "  9. 卸载应用"
    print_color $YELLOW "  0. 退出脚本"
    echo
    print_color $BLUE "选择安装的应用更多功能正在开发中..."
    echo
}

# 查看安装信息
show_info() {
    print_color $CYAN "=== 已安装应用信息 ==="
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        cat "$CREDENTIALS_FILE"
    else
        print_color $YELLOW "暂无安装记录"
    fi
    echo
    print_color $WHITE "按任意键返回主菜单..."
    read -n 1
}

# 卸载功能
uninstall_apps() {
    print_color $CYAN "=== 卸载选项 ==="
    echo "1. 卸载所有Docker应用"
    echo "2. 卸载qBittorrent"
    echo "3. 卸载Vertex"
    echo "0. 返回主菜单"
    echo
    read -p "请选择要卸载的选项: " uninstall_choice
    
    case $uninstall_choice in
        1)
            print_color $YELLOW "正在卸载所有Docker应用..."
            docker stop $(docker ps -aq) 2>/dev/null
            docker rm $(docker ps -aq) 2>/dev/null
            docker rmi $(docker images -q) 2>/dev/null
            rm -rf "$DOCKER_PATH"
            print_color $GREEN "所有Docker应用已卸载"
            ;;
        2)
            print_color $YELLOW "正在卸载qBittorrent..."
            # 停止qBittorrent相关进程
            pkill -f qbittorrent
            systemctl stop qbittorrent 2>/dev/null
            systemctl disable qbittorrent 2>/dev/null
            rm -rf /home/*/qbittorrent-nox
            print_color $GREEN "qBittorrent已卸载"
            ;;
        3)
            print_color $YELLOW "正在卸载Vertex..."
            cd "$DOCKER_PATH/vertex" 2>/dev/null && docker-compose down
            docker rmi lswl/vertex:stable 2>/dev/null
            rm -rf "$DOCKER_PATH/vertex"
            print_color $GREEN "Vertex已卸载"
            ;;
        0)
            return
            ;;
        *)
            print_color $RED "无效选择"
            ;;
    esac
    
    print_color $WHITE "按任意键继续..."
    read -n 1
}

# 主程序
main() {
    # 记录开始时间
    log "PTtools脚本开始运行"
    
    # 检查系统环境
    check_system
    
    # 获取VPS信息
    get_vps_info
    
    while true; do
        show_menu
        read -p "请输入选项 [0-9]: " choice
        
        case $choice in
            1)
                install_docker
                create_directories
                install_qb_438 "single"
                ;;
            2)
                install_docker
                create_directories
                install_qb_439 "single"
                ;;
            3)
                install_docker
                create_directories
                if install_qb_438 "combo" && install_vertex "combo"; then
                    show_combo_success "4.3.8"
                fi
                ;;
            4)
                install_docker
                create_directories
                if install_qb_439 "combo" && install_vertex "combo"; then
                    show_combo_success "4.3.9"
                fi
                ;;
            9)
                uninstall_apps
                ;;
            0)
                print_color $GREEN "感谢使用 PTtools 脚本！"
                log "PTtools脚本正常退出"
                exit 0
                ;;
            *)
                print_color $RED "无效选择，请重新输入"
                sleep 2
                ;;
        esac
# 卸载功能
uninstall_apps() {
    print_color $CYAN "=== 卸载选项 ==="
    echo "1. 卸载所有Docker应用"
    echo "2. 卸载qBittorrent"
    echo "3. 卸载Vertex"
    echo "0. 返回主菜单"
    echo
    read -p "请选择要卸载的选项: " uninstall_choice
    
    case $uninstall_choice in
        1)
            print_color $YELLOW "正在卸载所有Docker应用..."
            docker stop $(docker ps -aq) 2>/dev/null
            docker rm $(docker ps -aq) 2>/dev/null
            docker rmi $(docker images -q) 2>/dev/null
            rm -rf "$DOCKER_PATH"
            print_color $GREEN "所有Docker应用已卸载"
            ;;
        2)
            print_color $YELLOW "正在卸载qBittorrent..."
            # 停止qBittorrent相关进程
            pkill -f qbittorrent
            systemctl stop qbittorrent 2>/dev/null
            systemctl disable qbittorrent 2>/dev/null
            rm -rf /home/*/qbittorrent-nox
            print_color $GREEN "qBittorrent已卸载"
            ;;
        3)
            print_color $YELLOW "正在卸载Vertex..."
            cd "$DOCKER_PATH/vertex" 2>/dev/null && docker-compose down
            docker rmi lswl/vertex:stable 2>/dev/null
            rm -rf "$DOCKER_PATH/vertex"
            print_color $GREEN "Vertex已卸载"
            ;;
        0)
            return
            ;;
        *)
            print_color $RED "无效选择"
            ;;
    esac
    
    print_color $WHITE "按任意键继续..."
    read -n 1
}

# 显示主菜单
show_menu() {
    show_banner
    print_color $WHITE "请选择要安装的选项:"
    echo
    print_color $GREEN "▶ 核心安装选项 (PT刷流优化)"
    print_color $YELLOW "  1. qBittorrent 4.3.8 (PT脚本版本)"
    print_color $YELLOW "  2. qBittorrent 4.3.9 (杰瑞大佬脚本)"
    print_color $YELLOW "  3. qBittorrent 4.3.8 + Vertex"
    print_color $YELLOW "  4. qBittorrent 4.3.9 + Vertex"
    echo
    print_color $CYAN "▶ 管理选项"
    print_color $YELLOW "  9. 卸载应用"
    print_color $YELLOW "  0. 退出脚本"
    echo
    print_color $BLUE "选择安装的应用更多功能正在开发中..."
    echo
}

        
        if [[ $choice =~ ^[1-4]$ ]]; then
            print_color $GREEN "安装完成！"
            print_color $YELLOW "登录信息已保存到 $CREDENTIALS_FILE"
            print_color $WHITE "按任意键返回主菜单..."
            read -n 1
        fi
    done
}

# 运行主程序
main "$@"
