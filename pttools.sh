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
        
        # 等待容器完全启动并生成密码文件
        echo -e "${YELLOW}正在等待Vertex初始化...${NC}"
        sleep 10
        
        # 尝试读取密码文件
        if [ -f "/opt/docker/vertex/data/password" ]; then
            vertex_password=$(cat /opt/docker/vertex/data/password 2>/dev/null)
            if [ -n "$vertex_password" ]; then
                echo -e "${GREEN}初始密码: ${vertex_password}${NC}"
                echo -e "${CYAN}================================================${NC}"
                echo -e "${CYAN}Vertex登录信息${NC}"
                echo -e "${CYAN}地址: http://你的服务器IP:3333${NC}"
                echo -e "${CYAN}用户名: admin${NC}"
                echo -e "${CYAN}密码: ${vertex_password}${NC}"
                echo -e "${CYAN}================================================${NC}"
            else
                echo -e "${YELLOW}密码文件为空，请稍后查看 /opt/docker/vertex/data/password${NC}"
            fi
        else
            echo -e "${YELLOW}密码文件尚未生成，请稍后查看 /opt/docker/vertex/data/password${NC}"
            echo -e "${YELLOW}或执行命令: cat /opt/docker/vertex/data/password${NC}"
        fi
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
            install_docker_func
            
            # 检查Docker是否安装成功
            if ! command -v docker &> /dev/null; then
                echo -e "${RED}Docker安装失败，无法继续安装Vertex${NC}"
                echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                read -n 1
                return
            else
                echo -e "${GREEN}Docker安装成功！${NC}"
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
            echo -e "${GREEN}Vertex密码: 查看上方显示或执行 cat /opt/docker/vertex/data/password${NC}"
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
                    install_docker_func
                    
                    # 检查Docker是否安装成功
                    if ! command -v docker &> /dev/null; then
                        echo -e "${RED}Docker安装失败，无法继续安装Vertex${NC}"
                        echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                        read -n 1
                        return
                    else
                        echo -e "${GREEN}Docker安装成功！${NC}"
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
            echo -e "${GREEN}Vertex密码: 查看上方显示或执行 cat /opt/docker/vertex/data/password${NC}"
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
