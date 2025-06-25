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
GRAY='\033[0;90m'
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
        OS_VERSION=$(cat /etc/redhat-release)
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
        PM="apt"
        if [[ -f /etc/os-release ]]; then
            OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
        else
            OS_VERSION="Debian $(cat /etc/debian_version)"
        fi
    else
        echo -e "${RED}不支持的系统类型${NC}"
        echo -e "${YELLOW}当前支持的系统：${NC}"
        echo -e "${WHITE}- Debian/Ubuntu 系列${NC}"
        echo -e "${WHITE}- CentOS/RHEL 系列${NC}"
        echo
        echo -e "${YELLOW}当前系统信息：${NC}"
        uname -a
        exit 1
    fi
    echo -e "${GREEN}系统类型: $DISTRO${NC}"
    echo -e "${GREEN}系统版本: $OS_VERSION${NC}"
    echo -e "${GREEN}包管理器: $PM${NC}"
}

# 更新系统
update_system() {
    echo -e "${YELLOW}正在更新系统...${NC}"
    if [[ $DISTRO == "debian" ]]; then
        if apt update -y; then
            echo -e "${GREEN}系统更新成功${NC}"
        else
            echo -e "${RED}系统更新失败，但继续安装${NC}"
        fi
    elif [[ $DISTRO == "centos" ]]; then
        if yum update -y; then
            echo -e "${GREEN}系统更新成功${NC}"
        else
            echo -e "${RED}系统更新失败，但继续安装${NC}"
        fi
    fi
}

# 安装基础工具
install_base_tools() {
    echo -e "${YELLOW}正在安装基础工具...${NC}"
    if [[ $DISTRO == "debian" ]]; then
        if apt install -y curl wget git unzip; then
            echo -e "${GREEN}基础工具安装成功${NC}"
        else
            echo -e "${RED}基础工具安装失败${NC}"
            return 1
        fi
    elif [[ $DISTRO == "centos" ]]; then
        if yum install -y curl wget git unzip; then
            echo -e "${GREEN}基础工具安装成功${NC}"
        else
            echo -e "${RED}基础工具安装失败${NC}"
            return 1
        fi
    fi
    
    # 验证关键工具是否安装成功
    for tool in curl wget; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${RED}关键工具 $tool 安装失败${NC}"
            return 1
        fi
    done
    
    echo -e "${GREEN}所有基础工具验证通过${NC}"
    return 0
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker未安装，是否现在安装Docker？[Y/n]: ${NC}"
        read -r install_docker
        install_docker=${install_docker:-Y}
        if [[ $install_docker =~ ^[Yy]$ ]]; then
            if install_docker_func; then
                echo -e "${GREEN}Docker安装成功${NC}"
            else
                echo -e "${RED}Docker安装失败，部分功能需要Docker支持${NC}"
            fi
        else
            echo -e "${RED}部分功能需要Docker支持${NC}"
        fi
    else
        echo -e "${GREEN}Docker已安装${NC}"
        docker --version
    fi
}

# 安装Docker
install_docker_func() {
    echo -e "${YELLOW}正在安装Docker...${NC}"
    
    # 首先确保基础工具已安装
    echo -e "${YELLOW}检查基础工具...${NC}"
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}curl未安装，正在安装基础工具...${NC}"
        if [[ $DISTRO == "debian" ]]; then
            apt update -y
            apt install -y curl wget git unzip
        elif [[ $DISTRO == "centos" ]]; then
            yum update -y
            yum install -y curl wget git unzip
        fi
        
        # 再次检查curl是否安装成功
        if ! command -v curl &> /dev/null; then
            echo -e "${RED}基础工具安装失败，无法继续安装Docker${NC}"
            return 1
        fi
    fi
    
    echo -e "${YELLOW}选择安装源：${NC}"
    echo "1. 官方源（默认）"
    echo "2. 阿里云镜像源"
    read -p "请选择 [1-2]: " docker_source
    
    case $docker_source in
        2)
            echo -e "${YELLOW}使用阿里云镜像源安装Docker...${NC}"
            if ! curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun; then
                echo -e "${RED}Docker安装失败${NC}"
                return 1
            fi
            ;;
        *)
            echo -e "${YELLOW}使用官方源安装Docker...${NC}"
            if ! curl -fsSL https://get.docker.com | bash -s docker; then
                echo -e "${RED}Docker安装失败${NC}"
                return 1
            fi
            ;;
    esac
    
    # 启动Docker服务
    echo -e "${YELLOW}启动Docker服务...${NC}"
    if systemctl start docker; then
        echo -e "${GREEN}Docker服务启动成功${NC}"
    else
        echo -e "${RED}Docker服务启动失败${NC}"
        echo -e "${YELLOW}尝试手动启动Docker...${NC}"
        service docker start
    fi
    
    if systemctl enable docker; then
        echo -e "${GREEN}Docker开机自启设置成功${NC}"
    else
        echo -e "${YELLOW}Docker开机自启设置失败，但不影响使用${NC}"
    fi
    
    # 验证Docker是否安装成功
    sleep 3
    if command -v docker &> /dev/null && docker --version &> /dev/null; then
        echo -e "${GREEN}Docker安装成功${NC}"
        docker --version
    else
        echo -e "${RED}Docker安装验证失败${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}是否安装Docker Compose？[Y/n]: ${NC}"
    read -r install_compose
    install_compose=${install_compose:-Y}
    if [[ $install_compose =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}正在安装Docker Compose...${NC}"
        
        # 获取最新版本号
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
        if [ -z "$COMPOSE_VERSION" ]; then
            COMPOSE_VERSION="v2.24.0"  # 备用版本
            echo -e "${YELLOW}无法获取最新版本，使用备用版本 $COMPOSE_VERSION${NC}"
        fi
        
        if curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; then
            chmod +x /usr/local/bin/docker-compose
            echo -e "${GREEN}Docker Compose安装完成${NC}"
            /usr/local/bin/docker-compose --version
        else
            echo -e "${RED}Docker Compose安装失败，但不影响Docker使用${NC}"
        fi
    fi
    
    return 0
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
    echo -e "${BLUE}安装参数说明：${NC}"
    echo -e "${WHITE}- 用户名：qBittorrent Web界面登录用户名${NC}"
    echo -e "${WHITE}- 密码：qBittorrent Web界面登录密码${NC}"
    echo -e "${WHITE}- Web端口：qBittorrent Web界面访问端口${NC}"
    echo -e "${WHITE}- BT端口：qBittorrent BT下载监听端口${NC}"
    echo
    
    # 获取用户输入参数
    read -p "请输入用户名 [默认: admin]: " username
    username=${username:-admin}
    
    read -p "请输入密码 [默认: adminadmin]: " password
    password=${password:-adminadmin}
    
    read -p "请输入Web访问端口 [默认: 8080]: " web_port
    web_port=${web_port:-8080}
    
    read -p "请输入BT监听端口 [默认: 23333]: " bt_port
    bt_port=${bt_port:-23333}
    
    echo
    echo -e "${GREEN}安装参数确认：${NC}"
    echo -e "${WHITE}用户名: ${username}${NC}"
    echo -e "${WHITE}密码: ${password}${NC}"
    echo -e "${WHITE}Web端口: ${web_port}${NC}"
    echo -e "${WHITE}BT端口: ${bt_port}${NC}"
    echo
    
    read -p "确认安装？[Y/n]: " confirm
    confirm=${confirm:-Y}
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi
    
    echo -e "${YELLOW}正在下载并执行安装脚本...${NC}"
    echo -e "${BLUE}执行命令: bash <(wget -qO- https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh) $username $password $web_port $bt_port${NC}"
    echo
    
    # 下载并执行原作者脚本，传递参数
    if bash <(wget -qO- https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh) "$username" "$password" "$web_port" "$bt_port"; then
        echo
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}qBittorrent 4.3.8 安装完成！${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}访问地址: http://你的服务器IP:${web_port}${NC}"
        echo -e "${GREEN}用户名: ${username}${NC}"
        echo -e "${GREEN}密码: ${password}${NC}"
        echo -e "${GREEN}BT端口: ${bt_port}${NC}"
        echo -e "${GREEN}================================================${NC}"
    else
        echo
        echo -e "${RED}================================================${NC}"
        echo -e "${RED}qBittorrent 4.3.8 安装失败！${NC}"
        echo -e "${RED}请检查网络连接和系统兼容性${NC}"
        echo -e "${RED}================================================${NC}"
    fi
    
    echo
    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
    read -n 1
}

# 卸载应用
uninstall_apps() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}卸载应用${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo
    
    # 检测Docker应用
    echo -e "${YELLOW}正在检测已安装的应用...${NC}"
    echo
    
    # 检测Docker应用
    docker_apps=()
    if command -v docker &> /dev/null; then
        echo -e "${BLUE}检测到的Docker应用：${NC}"
        
        # 检查常见的PT相关容器
        containers=("vertex" "qbittorrent" "transmission" "emby" "iyuuplus" "moviepilot")
        found_docker=false
        
        for container in "${containers[@]}"; do
            if docker ps -a --format "table {{.Names}}" | grep -q "^${container}$"; then
                status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "^${container}" | awk '{print $2}')
                if [ -n "$status" ]; then
                    echo -e "${GREEN}  ✓ ${container} (运行中)${NC}"
                else
                    echo -e "${YELLOW}  ✓ ${container} (已停止)${NC}"
                fi
                docker_apps+=("$container")
                found_docker=true
            fi
        done
        
        if [ "$found_docker" = false ]; then
            echo -e "${GRAY}  未检测到相关Docker应用${NC}"
        fi
    else
        echo -e "${GRAY}Docker未安装，跳过Docker应用检测${NC}"
    fi
    
    echo
    echo -e "${BLUE}原作者脚本安装的应用：${NC}"
    echo -e "${WHITE}  • qBittorrent (原生安装)${NC}"
    echo -e "${WHITE}  • Vertex (原生安装)${NC}"
    echo -e "${WHITE}  • 其他jerry048脚本安装的组件${NC}"
    
    echo
    echo -e "${GREEN}请选择卸载类型：${NC}"
    echo "1. 卸载Docker应用"
    echo "2. 卸载原作者脚本应用"
    echo "3. 返回主菜单"
    
    read -p "请选择 [1-3]: " uninstall_choice
    
    case $uninstall_choice in
        1)
            uninstall_docker_apps
            ;;
        2)
            uninstall_script_apps
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            echo -e "${YELLOW}按任意键返回...${NC}"
            read -n 1
            ;;
    esac
}

# 卸载Docker应用
uninstall_docker_apps() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}卸载Docker应用${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker未安装，无法卸载Docker应用${NC}"
        echo -e "${YELLOW}按任意键返回...${NC}"
        read -n 1
        return
    fi
    
    # 重新检测Docker应用
    containers=("vertex" "qbittorrent" "transmission" "emby" "iyuuplus" "moviepilot")
    found_containers=()
    
    echo -e "${YELLOW}检测Docker应用中...${NC}"
    for container in "${containers[@]}"; do
        if docker ps -a --format "table {{.Names}}" | grep -q "^${container}$"; then
            found_containers+=("$container")
        fi
    done
    
    if [ ${#found_containers[@]} -eq 0 ]; then
        echo -e "${YELLOW}未发现相关Docker应用${NC}"
        echo -e "${YELLOW}按任意键返回...${NC}"
        read -n 1
        return
    fi
    
    echo -e "${GREEN}发现以下Docker应用：${NC}"
    for i in "${!found_containers[@]}"; do
        status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "^${found_containers[$i]}" | awk '{print $2}')
        if [ -n "$status" ]; then
            echo -e "${GREEN}  $((i+1)). ${found_containers[$i]} (运行中)${NC}"
        else
            echo -e "${YELLOW}  $((i+1)). ${found_containers[$i]} (已停止)${NC}"
        fi
    done
    echo -e "${WHITE}  $((${#found_containers[@]}+1)). 全部卸载${NC}"
    echo -e "${WHITE}  $((${#found_containers[@]}+2)). 返回上级菜单${NC}"
    
    read -p "请选择要卸载的应用: " docker_choice
    
    if [[ $docker_choice -eq $((${#found_containers[@]}+1)) ]]; then
        # 全部卸载
        echo -e "${RED}警告：这将卸载所有检测到的Docker应用！${NC}"
        read -p "确认卸载所有应用？[y/N]: " confirm_all
        if [[ $confirm_all =~ ^[Yy]$ ]]; then
            for container in "${found_containers[@]}"; do
                uninstall_single_docker_app "$container"
            done
        else
            echo -e "${YELLOW}已取消卸载${NC}"
        fi
    elif [[ $docker_choice -eq $((${#found_containers[@]}+2)) ]]; then
        # 返回上级菜单
        return
    elif [[ $docker_choice -ge 1 && $docker_choice -le ${#found_containers[@]} ]]; then
        # 卸载单个应用
        selected_container="${found_containers[$((docker_choice-1))]}"
        uninstall_single_docker_app "$selected_container"
    else
        echo -e "${RED}无效选择${NC}"
    fi
    
    echo -e "${YELLOW}按任意键返回...${NC}"
    read -n 1
}

# 卸载单个Docker应用
uninstall_single_docker_app() {
    local container_name="$1"
    echo -e "${YELLOW}正在卸载 ${container_name}...${NC}"
    
    # 停止容器
    if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "${YELLOW}停止容器 ${container_name}...${NC}"
        docker stop "$container_name"
    fi
    
    # 删除容器
    if docker ps -a --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "${YELLOW}删除容器 ${container_name}...${NC}"
        docker rm "$container_name"
    fi
    
    # 询问是否删除数据目录
    echo -e "${YELLOW}是否同时删除数据目录 /opt/docker/${container_name}？[y/N]: ${NC}"
    read -r delete_data
    if [[ $delete_data =~ ^[Yy]$ ]]; then
        if [ -d "/opt/docker/${container_name}" ]; then
            echo -e "${YELLOW}删除数据目录 /opt/docker/${container_name}...${NC}"
            rm -rf "/opt/docker/${container_name}"
            echo -e "${GREEN}数据目录已删除${NC}"
        fi
    else
        echo -e "${BLUE}数据目录已保留：/opt/docker/${container_name}${NC}"
    fi
    
    echo -e "${GREEN}${container_name} 卸载完成${NC}"
}

# 卸载原作者脚本应用
uninstall_script_apps() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}卸载原作者脚本应用${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo
    
    echo -e "${YELLOW}注意：原作者脚本安装的应用卸载需要手动操作${NC}"
    echo
    echo -e "${BLUE}常见卸载方法：${NC}"
    echo -e "${WHITE}1. qBittorrent (原生安装):${NC}"
    echo -e "${WHITE}   systemctl stop qbittorrent${NC}"
    echo -e "${WHITE}   systemctl disable qbittorrent${NC}"
    echo -e "${WHITE}   apt remove qbittorrent (Debian/Ubuntu)${NC}"
    echo -e "${WHITE}   yum remove qbittorrent (CentOS/RHEL)${NC}"
    echo
    echo -e "${WHITE}2. Vertex (原生安装):${NC}"
    echo -e "${WHITE}   需要查看jerry048脚本的具体安装方式${NC}"
    echo -e "${WHITE}   通常涉及停止服务和删除相关文件${NC}"
    echo
    echo -e "${WHITE}3. 其他组件:${NC}"
    echo -e "${WHITE}   autobrr、autoremove-torrents等${NC}"
    echo -e "${WHITE}   需要根据具体安装方式进行卸载${NC}"
    echo
    
    echo -e "${RED}建议：${NC}"
    echo -e "${WHITE}1. 查看系统服务：systemctl list-units --type=service${NC}"
    echo -e "${WHITE}2. 查看安装的软件包${NC}"
    echo -e "${WHITE}3. 查看相关进程：ps aux | grep qbittorrent${NC}"
    echo -e "${WHITE}4. 查看开机启动项${NC}"
    echo
    
    echo -e "${YELLOW}是否要显示当前运行的相关服务？[Y/n]: ${NC}"
    read -r show_services
    show_services=${show_services:-Y}
    
    if [[ $show_services =~ ^[Yy]$ ]]; then
        echo
        echo -e "${BLUE}当前运行的相关服务：${NC}"
        systemctl list-units --type=service --state=running | grep -E "(qbittorrent|transmission|emby|vertex)" || echo -e "${GRAY}未找到相关服务${NC}"
        
        echo
        echo -e "${BLUE}相关进程：${NC}"
        ps aux | grep -E "(qbittorrent|transmission|emby|vertex)" | grep -v grep || echo -e "${GRAY}未找到相关进程${NC}"
    fi
    
    echo
    echo -e "${YELLOW}按任意键返回...${NC}"
    read -n 1
}

# 使用Docker安装Vertex
install_vertex_docker() {
    echo -e "${YELLOW}正在创建Vertex目录...${NC}"
    mkdir -p /opt/docker/vertex
    
    echo -e "${YELLOW}正在下载Vertex Docker Compose配置...${NC}"
    cat > /tmp/vertex-compose.yml << 'EOF'
version: '3.8'

services:
  vertex:
    image: lswl/vertex:stable
    container_name: vertex
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - /opt/docker/vertex:/vertex
    ports:
      - 3333:3000
    restart: unless-stopped
EOF

    echo -e "${YELLOW}正在启动Vertex容器...${NC}"
    if command -v docker-compose &> /dev/null; then
        docker-compose -f /tmp/vertex-compose.yml up -d
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker compose -f /tmp/vertex-compose.yml up -d
    else
        echo -e "${RED}Docker Compose未找到，使用docker run命令启动...${NC}"
        docker run -d \
            --name vertex \
            --restart unless-stopped \
            -p 3333:3000 \
            -v /opt/docker/vertex:/vertex \
            -e TZ=Asia/Shanghai \
            lswl/vertex:stable
    fi
    
    # 清理临时文件
    rm -f /tmp/vertex-compose.yml
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Vertex Docker安装完成${NC}"
        echo -e "${GREEN}访问地址: http://你的服务器IP:3333${NC}"
        echo -e "${GREEN}默认用户名: admin${NC}"
        return 0
    else
        echo -e "${RED}Vertex Docker安装失败${NC}"
        return 1
    fi
}

# 安装Vertex + qBittorrent 4.3.8
install_qb438_vt() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}正在安装 Vertex + qBittorrent 4.3.8${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo
    echo -e "${YELLOW}此功能将先安装Vertex，然后安装qBittorrent 4.3.8${NC}"
    echo -e "${YELLOW}qBittorrent 4.3.8 作者：iniwex5${NC}"
    echo
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}检测到未安装Docker，Vertex需要Docker支持${NC}"
        echo -e "${YELLOW}是否现在安装Docker？[Y/n]: ${NC}"
        read -r install_docker_choice
        install_docker_choice=${install_docker_choice:-Y}
        
        if [[ $install_docker_choice =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}正在安装Docker...${NC}"
            if install_docker_func; then
                echo -e "${GREEN}Docker安装成功！${NC}"
            else
                echo -e "${RED}Docker安装失败，无法继续安装Vertex${NC}"
                echo -e "${YELLOW}建议：${NC}"
                echo -e "${WHITE}1. 检查网络连接${NC}"
                echo -e "${WHITE}2. 确认系统源配置正确${NC}"
                echo -e "${WHITE}3. 手动安装Docker后重试${NC}"
                echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                read -n 1
                return
            fi
        else
            echo -e "${RED}用户取消Docker安装，无法安装Vertex${NC}"
            echo -e "${YELLOW}按任意键返回主菜单...${NC}"
            read -n 1
            return
        fi
    fi
    
    echo -e "${BLUE}Vertex安装方式选择：${NC}"
    echo "1. Docker方式（推荐）"
    echo "2. 原脚本方式"
    read -p "请选择 [1-2, 默认: 1]: " vertex_choice
    vertex_choice=${vertex_choice:-1}
    
    case $vertex_choice in
        1)
            echo -e "${GREEN}选择：Docker方式安装Vertex${NC}"
            vertex_install_type="docker"
            ;;
        2)
            echo -e "${GREEN}选择：原脚本方式安装Vertex${NC}"
            vertex_install_type="script"
            ;;
        *)
            echo -e "${YELLOW}无效选择，使用默认Docker方式${NC}"
            vertex_install_type="docker"
            ;;
    esac
    
    echo
    echo -e "${BLUE}qBittorrent 4.3.8 安装参数配置：${NC}"
    echo
    
    # 获取用户输入参数
    read -p "请输入用户名 [默认: admin]: " username
    username=${username:-admin}
    
    read -p "请输入密码 [默认: adminadmin]: " password
    password=${password:-adminadmin}
    
    read -p "请输入Web访问端口 [默认: 8080]: " web_port
    web_port=${web_port:-8080}
    
    read -p "请输入BT监听端口 [默认: 23333]: " bt_port
    bt_port=${bt_port:-23333}
    
    echo
    echo -e "${GREEN}安装配置确认：${NC}"
    echo -e "${WHITE}Vertex: $([ "$vertex_install_type" == "docker" ] && echo "Docker方式安装 (端口3333)" || echo "原脚本方式安装")${NC}"
    echo -e "${WHITE}qBittorrent 4.3.8:${NC}"
    echo -e "${WHITE}  - 用户名: ${username}${NC}"
    echo -e "${WHITE}  - 密码: ${password}${NC}"
    echo -e "${WHITE}  - Web端口: ${web_port}${NC}"
    echo -e "${WHITE}  - BT端口: ${bt_port}${NC}"
    echo
    
    read -p "确认安装？[Y/n]: " confirm
    confirm=${confirm:-Y}
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi
    
    # 步骤1: 安装Vertex
    echo -e "${YELLOW}步骤1: 正在安装Vertex...${NC}"
    
    if [ "$vertex_install_type" == "docker" ]; then
        # Docker方式安装Vertex
        if install_vertex_docker; then
            echo -e "${GREEN}Vertex Docker安装成功${NC}"
        else
            echo -e "${RED}Vertex Docker安装失败，终止安装${NC}"
            echo -e "${YELLOW}按任意键返回主菜单...${NC}"
            read -n 1
            return
        fi
    else
        # 原脚本方式安装Vertex
        echo -e "${YELLOW}使用原脚本方式安装Vertex...${NC}"
        echo -e "${BLUE}执行命令: bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u admin -p adminadmin -v${NC}"
        
        if bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u admin -p adminadmin -v; then
            echo -e "${GREEN}Vertex原脚本安装成功${NC}"
            echo -e "${GREEN}Vertex访问地址: http://你的服务器IP:3333${NC}"
            echo -e "${GREEN}Vertex用户名: admin${NC}"
            echo -e "${GREEN}Vertex密码: adminadmin${NC}"
        else
            echo -e "${RED}Vertex原脚本安装失败，终止安装${NC}"
            echo -e "${YELLOW}按任意键返回主菜单...${NC}"
            read -n 1
            return
        fi
    fi
    
    echo
    echo -e "${YELLOW}步骤2: 正在安装qBittorrent 4.3.8...${NC}"
    echo -e "${BLUE}执行命令: bash <(wget -qO- https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh) $username $password $web_port $bt_port${NC}"
    echo
    
    # 步骤2: 安装qBittorrent 4.3.8
    if bash <(wget -qO- https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh) "$username" "$password" "$web_port" "$bt_port"; then
        echo
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}Vertex + qBittorrent 4.3.8 安装完成！${NC}"
        echo -e "${GREEN}================================================${NC}"
        if [ "$vertex_install_type" == "docker" ]; then
            echo -e "${GREEN}Vertex访问地址: http://你的服务器IP:3333${NC}"
            echo -e "${GREEN}Vertex用户名: admin${NC}"
            # 等待并直接显示密码
            echo -e "${YELLOW}正在获取Vertex密码...${NC}"
            sleep 5
            if [ -f "/opt/docker/vertex/data/password" ]; then
                vertex_password=$(cat /opt/docker/vertex/data/password 2>/dev/null)
                if [ -n "$vertex_password" ]; then
                    echo -e "${GREEN}Vertex密码: ${vertex_password}${NC}"
                else
                    echo -e "${YELLOW}Vertex密码: 密码文件为空，请执行 cat /opt/docker/vertex/data/password${NC}"
                fi
            else
                echo -e "${YELLOW}Vertex密码: 密码文件未生成，请执行 cat /opt/docker/vertex/data/password${NC}"
            fi
        else
            echo -e "${GREEN}Vertex访问地址: http://你的服务器IP:3333${NC}"
            echo -e "${GREEN}Vertex用户名: admin${NC}"
            echo -e "${GREEN}Vertex密码: adminadmin${NC}"
        fi
        echo -e "${GREEN}qBittorrent访问地址: http://你的服务器IP:${web_port}${NC}"
        echo -e "${GREEN}qBittorrent用户名: ${username}${NC}"
        echo -e "${GREEN}qBittorrent密码: ${password}${NC}"
        echo -e "${GREEN}qBittorrent BT端口: ${bt_port}${NC}"
        echo -e "${GREEN}================================================${NC}"
    else
        echo
        echo -e "${RED}================================================${NC}"
        echo -e "${RED}qBittorrent 4.3.8 安装失败！${NC}"
        echo -e "${RED}Vertex已安装成功，但qBittorrent安装失败${NC}"
        echo -e "${RED}================================================${NC}"
    fi
    
    echo
    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
    read -n 1
}

# 安装Vertex + qBittorrent 4.3.9
install_qb439_vt() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}正在安装 Vertex + qBittorrent 4.3.9${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo
    echo -e "${YELLOW}此功能将安装Vertex和qBittorrent 4.3.9${NC}"
    echo -e "${YELLOW}qBittorrent 4.3.9 作者：jerry048${NC}"
    echo
    
    # 检查Docker（仅在选择Docker方式时需要）
    docker_available=true
    if ! command -v docker &> /dev/null; then
        docker_available=false
    fi
    
    echo -e "${BLUE}Vertex安装方式选择：${NC}"
    echo "1. Docker方式（推荐）"
    echo "2. 原脚本方式"
    if [ "$docker_available" = false ]; then
        echo -e "${RED}注意：Docker未安装，选择1将自动安装Docker${NC}"
    fi
    read -p "请选择 [1-2, 默认: 1]: " vertex_choice
    vertex_choice=${vertex_choice:-1}
    
    case $vertex_choice in
        1)
            echo -e "${GREEN}选择：Docker方式安装Vertex${NC}"
            vertex_install_type="docker"
            
            # 检查并安装Docker
            if [ "$docker_available" = false ]; then
                echo -e "${YELLOW}检测到未安装Docker，Vertex需要Docker支持${NC}"
                echo -e "${YELLOW}是否现在安装Docker？[Y/n]: ${NC}"
                read -r install_docker_choice
                install_docker_choice=${install_docker_choice:-Y}
                
                if [[ $install_docker_choice =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}正在安装Docker...${NC}"
                    if install_docker_func; then
                        echo -e "${GREEN}Docker安装成功！${NC}"
                    else
                        echo -e "${RED}Docker安装失败，无法继续安装Vertex${NC}"
                        echo -e "${YELLOW}建议：${NC}"
                        echo -e "${WHITE}1. 检查网络连接${NC}"
                        echo -e "${WHITE}2. 确认系统源配置正确${NC}"
                        echo -e "${WHITE}3. 手动安装Docker后重试${NC}"
                        echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                        read -n 1
                        return
                    fi
                else
                    echo -e "${RED}用户取消Docker安装，无法安装Vertex${NC}"
                    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                    read -n 1
                    return
                fi
            fi
            ;;
        2)
            echo -e "${GREEN}选择：原脚本方式安装Vertex${NC}"
            vertex_install_type="script"
            ;;
        *)
            echo -e "${YELLOW}无效选择，使用默认Docker方式${NC}"
            vertex_install_type="docker"
            ;;
    esac
    
    echo
    echo -e "${BLUE}qBittorrent 4.3.9 安装参数配置：${NC}"
    echo
    
    # 基础参数配置
    read -p "请输入用户名 [默认: admin]: " username
    username=${username:-admin}
    
    read -p "请输入密码 [默认: adminadmin]: " password
    password=${password:-adminadmin}
    
    read -p "请输入缓存大小(MiB) [默认: 3072]: " cache_size
    cache_size=${cache_size:-3072}
    
    read -p "请输入libtorrent版本 [默认: v1.2.20]: " libtorrent_ver
    libtorrent_ver=${libtorrent_ver:-v1.2.20}
    
    echo
    echo -e "${BLUE}可选功能配置：${NC}"
    
    # 可选功能
    read -p "是否安装autobrr？[y/N]: " install_autobrr
    install_autobrr=${install_autobrr:-N}
    autobrr_flag=""
    [[ $install_autobrr =~ ^[Yy]$ ]] && autobrr_flag="-b"
    
    read -p "是否安装autoremove-torrents？[y/N]: " install_autoremove
    install_autoremove=${install_autoremove:-N}
    autoremove_flag=""
    [[ $install_autoremove =~ ^[Yy]$ ]] && autoremove_flag="-r"
    
    read -p "是否启用BBRx？[y/N]: " enable_bbrx
    enable_bbrx=${enable_bbrx:-N}
    bbrx_flag=""
    [[ $enable_bbrx =~ ^[Yy]$ ]] && bbrx_flag="-x"
    
    echo
    echo -e "${GREEN}安装配置确认：${NC}"
    echo -e "${WHITE}Vertex: $([ "$vertex_install_type" == "docker" ] && echo "Docker方式安装 (端口3333)" || echo "原脚本方式安装")${NC}"
    echo -e "${WHITE}qBittorrent 4.3.9:${NC}"
    echo -e "${WHITE}  - 用户名: ${username}${NC}"
    echo -e "${WHITE}  - 密码: ${password}${NC}"
    echo -e "${WHITE}  - 缓存大小: ${cache_size} MiB${NC}"
    echo -e "${WHITE}  - libtorrent版本: ${libtorrent_ver}${NC}"
    echo -e "${WHITE}  - autobrr: $([[ $install_autobrr =~ ^[Yy]$ ]] && echo "是" || echo "否")${NC}"
    echo -e "${WHITE}  - autoremove-torrents: $([[ $install_autoremove =~ ^[Yy]$ ]] && echo "是" || echo "否")${NC}"
    echo -e "${WHITE}  - BBRx: $([[ $enable_bbrx =~ ^[Yy]$ ]] && echo "是" || echo "否")${NC}"
    echo
    
    read -p "确认安装？[Y/n]: " confirm
    confirm=${confirm:-Y}
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi
    
    if [ "$vertex_install_type" == "docker" ]; then
        # Docker方式：先安装Vertex，再安装qBittorrent
        echo -e "${YELLOW}步骤1: 正在使用Docker安装Vertex...${NC}"
        if install_vertex_docker; then
            echo -e "${GREEN}Vertex Docker安装成功${NC}"
        else
            echo -e "${RED}Vertex Docker安装失败，终止安装${NC}"
            echo -e "${YELLOW}按任意键返回主菜单...${NC}"
            read -n 1
            return
        fi
        
        echo
        echo -e "${YELLOW}步骤2: 正在安装qBittorrent 4.3.9...${NC}"
        
        # 构建安装命令（不带-v参数，因为Vertex已经安装了）
        install_cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u $username -p $password -c $cache_size -q 4.3.9 -l $libtorrent_ver"
        
        # 添加可选参数
        [[ -n "$autobrr_flag" ]] && install_cmd="$install_cmd $autobrr_flag"
        [[ -n "$autoremove_flag" ]] && install_cmd="$install_cmd $autoremove_flag"
        [[ -n "$bbrx_flag" ]] && install_cmd="$install_cmd $bbrx_flag"
        
        echo -e "${BLUE}命令: $install_cmd${NC}"
        echo
        
        if eval "$install_cmd"; then
            echo
            echo -e "${GREEN}================================================${NC}"
            echo -e "${GREEN}Vertex + qBittorrent 4.3.9 安装完成！${NC}"
            echo -e "${GREEN}================================================${NC}"
            echo -e "${GREEN}Vertex访问地址: http://你的服务器IP:3333${NC}"
            echo -e "${GREEN}Vertex用户名: admin${NC}"
            # 等待并直接显示密码
            echo -e "${YELLOW}正在获取Vertex密码...${NC}"
            sleep 5
            if [ -f "/opt/docker/vertex/data/password" ]; then
                vertex_password=$(cat /opt/docker/vertex/data/password 2>/dev/null)
                if [ -n "$vertex_password" ]; then
                    echo -e "${GREEN}Vertex密码: ${vertex_password}${NC}"
                else
                    echo -e "${YELLOW}Vertex密码: 密码文件为空，请执行 cat /opt/docker/vertex/data/password${NC}"
                fi
            else
                echo -e "${YELLOW}Vertex密码: 密码文件未生成，请执行 cat /opt/docker/vertex/data/password${NC}"
            fi
            echo -e "${GREEN}qBittorrent用户名: ${username}${NC}"
            echo -e "${GREEN}qBittorrent密码: ${password}${NC}"
            echo -e "${GREEN}qBittorrent缓存大小: ${cache_size} MiB${NC}"
            echo -e "${GREEN}================================================${NC}"
        else
            echo
            echo -e "${RED}================================================${NC}"
            echo -e "${RED}qBittorrent 4.3.9 安装失败！${NC}"
            echo -e "${RED}Vertex已安装成功，但qBittorrent安装失败${NC}"
            echo -e "${RED}================================================${NC}"
        fi
        
    else
        # 原脚本方式：一次性安装Vertex和qBittorrent
        echo -e "${YELLOW}正在使用原脚本方式安装Vertex + qBittorrent 4.3.9...${NC}"
        
        # 构建安装命令（带-v参数，同时安装Vertex和qBittorrent）
        install_cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u $username -p $password -c $cache_size -q 4.3.9 -l $libtorrent_ver -v"
        
        # 添加可选参数
        [[ -n "$autobrr_flag" ]] && install_cmd="$install_cmd $autobrr_flag"
        [[ -n "$autoremove_flag" ]] && install_cmd="$install_cmd $autoremove_flag"
        [[ -n "$bbrx_flag" ]] && install_cmd="$install_cmd $bbrx_flag"
        
        echo -e "${BLUE}命令: $install_cmd${NC}"
        echo
        
        if eval "$install_cmd"; then
            echo
            echo -e "${GREEN}================================================${NC}"
            echo -e "${GREEN}Vertex + qBittorrent 4.3.9 安装完成！${NC}"
            echo -e "${GREEN}================================================${NC}"
            echo -e "${GREEN}Vertex访问地址: http://你的服务器IP:3333${NC}"
            echo -e "${GREEN}Vertex用户名: admin${NC}"
            echo -e "${GREEN}Vertex密码: adminadmin${NC}"
            echo -e "${GREEN}qBittorrent用户名: ${username}${NC}"
            echo -e "${GREEN}qBittorrent密码: ${password}${NC}"
            echo -e "${GREEN}qBittorrent缓存大小: ${cache_size} MiB${NC}"
            echo -e "${GREEN}================================================${NC}"
        else
            echo
            echo -e "${RED}================================================${NC}"
            echo -e "${RED}Vertex + qBittorrent 4.3.9 安装失败！${NC}"
            echo -e "${RED}请检查网络连接和系统兼容性${NC}"
            echo -e "${RED}================================================${NC}"
        fi
    fi
    
    echo
    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
    read -n 1
}

# 安装qBittorrent 4.3.9
install_qb439() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}正在安装 qBittorrent 4.3.9${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo
    echo -e "${YELLOW}此功能将调用原作者脚本进行安装${NC}"
    echo -e "${YELLOW}原作者：jerry048${NC}"
    echo -e "${YELLOW}脚本来源：https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh${NC}"
    echo
    echo -e "${BLUE}安装参数配置：${NC}"
    echo
    
    # 基础参数配置
    read -p "请输入用户名 [默认: admin]: " username
    username=${username:-admin}
    
    read -p "请输入密码 [默认: adminadmin]: " password
    password=${password:-adminadmin}
    
    read -p "请输入缓存大小(MiB) [默认: 3072]: " cache_size
    cache_size=${cache_size:-3072}
    
    read -p "请输入libtorrent版本 [默认: v1.2.20]: " libtorrent_ver
    libtorrent_ver=${libtorrent_ver:-v1.2.20}
    
    echo
    echo -e "${BLUE}可选功能配置：${NC}"
    
    # 可选功能
    read -p "是否安装autobrr？[y/N]: " install_autobrr
    install_autobrr=${install_autobrr:-N}
    autobrr_flag=""
    [[ $install_autobrr =~ ^[Yy]$ ]] && autobrr_flag="-b"
    
    read -p "是否安装autoremove-torrents？[y/N]: " install_autoremove
    install_autoremove=${install_autoremove:-N}
    autoremove_flag=""
    [[ $install_autoremove =~ ^[Yy]$ ]] && autoremove_flag="-r"
    
    read -p "是否启用BBRx？[y/N]: " enable_bbrx
    enable_bbrx=${enable_bbrx:-N}
    bbrx_flag=""
    [[ $enable_bbrx =~ ^[Yy]$ ]] && bbrx_flag="-x"
    
    echo
    echo -e "${GREEN}安装配置确认：${NC}"
    echo -e "${WHITE}用户名: ${username}${NC}"
    echo -e "${WHITE}密码: ${password}${NC}"
    echo -e "${WHITE}缓存大小: ${cache_size} MiB${NC}"
    echo -e "${WHITE}qBittorrent版本: 4.3.9${NC}"
    echo -e "${WHITE}libtorrent版本: ${libtorrent_ver}${NC}"
    echo -e "${WHITE}autobrr: $([[ $install_autobrr =~ ^[Yy]$ ]] && echo "是" || echo "否")${NC}"
    echo -e "${WHITE}autoremove-torrents: $([[ $install_autoremove =~ ^[Yy]$ ]] && echo "是" || echo "否")${NC}"
    echo -e "${WHITE}BBRx: $([[ $enable_bbrx =~ ^[Yy]$ ]] && echo "是" || echo "否")${NC}"
    echo
    
    read -p "确认安装？[Y/n]: " confirm
    confirm=${confirm:-Y}
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi
    
    # 构建安装命令
    install_cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u $username -p $password -c $cache_size -q 4.3.9 -l $libtorrent_ver"
    
    # 添加可选参数
    [[ -n "$autobrr_flag" ]] && install_cmd="$install_cmd $autobrr_flag"
    [[ -n "$autoremove_flag" ]] && install_cmd="$install_cmd $autoremove_flag"
    [[ -n "$bbrx_flag" ]] && install_cmd="$install_cmd $bbrx_flag"
    
    echo -e "${YELLOW}正在执行安装命令...${NC}"
    echo -e "${BLUE}命令: $install_cmd${NC}"
    echo
    
    # 执行安装
    if eval "$install_cmd"; then
        echo
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}qBittorrent 4.3.9 安装完成！${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}用户名: ${username}${NC}"
        echo -e "${GREEN}密码: ${password}${NC}"
        echo -e "${GREEN}缓存大小: ${cache_size} MiB${NC}"
        echo -e "${GREEN}================================================${NC}"
    else
        echo
        echo -e "${RED}================================================${NC}"
        echo -e "${RED}qBittorrent 4.3.9 安装失败！${NC}"
        echo -e "${RED}请检查网络连接和系统兼容性${NC}"
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
                install_qb439
                ;;
            3)
                install_qb438_vt
                ;;
            4)
                install_qb439_vt
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
                uninstall_apps
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

if ! install_base_tools; then
    echo -e "${RED}基础工具安装失败！${NC}"
    echo -e "${YELLOW}请检查网络连接和系统源配置${NC}"
    echo -e "${YELLOW}您可以手动执行以下命令安装基础工具：${NC}"
    if [[ $DISTRO == "debian" ]]; then
        echo -e "${WHITE}apt update && apt install -y curl wget git unzip${NC}"
    elif [[ $DISTRO == "centos" ]]; then
        echo -e "${WHITE}yum update && yum install -y curl wget git unzip${NC}"
    fi
    echo
    echo -e "${YELLOW}安装完成后可重新运行此脚本${NC}"
    exit 1
fi

check_docker
create_directories

echo -e "${GREEN}环境初始化完成！${NC}"
echo -e "${YELLOW}按任意键进入主菜单...${NC}"
read -n 1

# 运行主程序
main
