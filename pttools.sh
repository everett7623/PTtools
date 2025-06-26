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

# 检查端口冲突
check_port_conflicts() {
    local ports=(8080 9091 8096 8780 3000 6881 51413 8920 3001)
    local port_names=("qBittorrent" "Transmission" "Emby" "IYUUPlus" "MoviePilot" "qBittorrent-BT" "Transmission-BT" "Emby-HTTPS" "MoviePilot-Backend")
    local conflicts=()
    
    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local name="${port_names[$i]}"
        
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            conflicts+=("$name (端口 $port)")
        fi
    done
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        echo -e "${YELLOW}检测到端口冲突：${NC}"
        for conflict in "${conflicts[@]}"; do
            echo -e "${RED}  ✗ $conflict${NC}"
        done
        echo
        echo -e "${YELLOW}建议：${NC}"
        echo -e "${WHITE}1. 停止占用端口的服务${NC}"
        echo -e "${WHITE}2. 或者修改应用配置使用其他端口${NC}"
        echo
        read -p "是否继续安装？可能会导致部分应用无法访问 [y/N]: " continue_install
        if [[ ! $continue_install =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}安装已取消${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}端口检查通过，无冲突${NC}"
    fi
    
    return 0
}

# 安装全套Docker应用
install_full_docker_suite() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}安装全套Docker应用${NC}"
    echo -e "${CYAN}qBittorrent 4.6.7 + Transmission 4.0.5 + Emby + IYUUPlus + MoviePilot${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}检测到未安装Docker，全套应用需要Docker支持${NC}"
        echo -e "${YELLOW}是否现在安装Docker？[Y/n]: ${NC}"
        read -r install_docker_choice
        install_docker_choice=${install_docker_choice:-Y}
        
        if [[ $install_docker_choice =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}正在安装Docker...${NC}"
            if install_docker_func; then
                echo -e "${GREEN}Docker安装成功！${NC}"
            else
                echo -e "${RED}Docker安装失败，无法继续安装${NC}"
                echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                read -n 1
                return
            fi
        else
            echo -e "${RED}用户取消Docker安装，无法安装全套应用${NC}"
            echo -e "${YELLOW}按任意键返回主菜单...${NC}"
            read -n 1
            return
        fi
    fi
    
    echo -e "${BLUE}应用配置说明：${NC}"
    echo -e "${WHITE}本功能将安装以下应用：${NC}"
    echo -e "${WHITE}• qBittorrent 4.6.7 (端口: 8080)${NC}"
    echo -e "${WHITE}• Transmission 4.0.5 (端口: 9091, 用户名: admin, 密码: adminadmin)${NC}"
    echo -e "${WHITE}• Emby (端口: 8096)${NC}"
    echo -e "${WHITE}• IYUUPlus (端口: 8780)${NC}"
    echo -e "${WHITE}• MoviePilot (端口: 3000)${NC}"
    echo
    echo -e "${YELLOW}注意：所有应用将使用Docker安装，数据目录为 /opt/docker，下载目录为 /opt/downloads${NC}"
    echo
    
    read -p "确认安装全套Docker应用？[Y/n]: " confirm
    confirm=${confirm:-Y}
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi
    
    # 检查端口冲突
    echo -e "${YELLOW}正在检查端口占用情况...${NC}"
    if ! check_port_conflicts; then
        echo -e "${YELLOW}按任意键返回主菜单...${NC}"
        read -n 1
        return
    fi
    
    # 创建所有必要目录
    echo -e "${YELLOW}正在创建应用目录...${NC}"
    create_app_directories
    
    # 安装应用
    local failed_apps=()
    local success_apps=()
    
    # 1. 安装 qBittorrent
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}步骤 1/5: 安装 qBittorrent 4.6.7${NC}"
    echo -e "${CYAN}================================================${NC}"
    if install_single_app "qbittorrent" "create_qbittorrent_compose"; then
        success_apps+=("qBittorrent")
    else
        failed_apps+=("qBittorrent")
    fi
    
    # 2. 安装 Transmission
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}步骤 2/5: 安装 Transmission 4.0.5${NC}"
    echo -e "${CYAN}================================================${NC}"
    if install_single_app "transmission" "create_transmission_compose"; then
        success_apps+=("Transmission")
    else
        failed_apps+=("Transmission")
    fi
    
    # 3. 安装 Emby
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}步骤 3/5: 安装 Emby${NC}"
    echo -e "${CYAN}================================================${NC}"
    if install_single_app "emby" "create_emby_compose"; then
        success_apps+=("Emby")
    else
        failed_apps+=("Emby")
    fi
    
    # 4. 安装 IYUUPlus
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}步骤 4/5: 安装 IYUUPlus${NC}"
    echo -e "${CYAN}================================================${NC}"
    if install_single_app "iyuuplus" "create_iyuuplus_compose"; then
        success_apps+=("IYUUPlus")
    else
        failed_apps+=("IYUUPlus")
    fi
    
    # 5. 安装 MoviePilot
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}步骤 5/5: 安装 MoviePilot${NC}"
    echo -e "${CYAN}================================================${NC}"
    if install_single_app "moviepilot-v2" "create_moviepilot_compose"; then
        success_apps+=("MoviePilot")
    else
        failed_apps+=("MoviePilot")
    fi
    
    # 显示安装结果
    show_full_suite_results
    
    echo
    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
    read -n 1
}

# 创建应用目录
create_app_directories() {
    local directories=(
        "/opt/docker/qbittorrent/config"
        "/opt/docker/transmission/config"
        "/opt/docker/emby/config"
        "/opt/docker/iyuuplus/iyuu"
        "/opt/docker/iyuuplus/data"
        "/opt/docker/moviepilot/config"
        "/opt/docker/moviepilot/core"
        "/opt/downloads"
    )
    
    for dir in "${directories[@]}"; do
        if mkdir -p "$dir"; then
            echo -e "${GREEN}创建目录: $dir${NC}"
        else
            echo -e "${RED}创建目录失败: $dir${NC}"
        fi
    done
}

# 安装单个应用
install_single_app() {
    local app_name="$1"
    local compose_function="$2"
    
    echo -e "${YELLOW}正在安装 $app_name...${NC}"
    
    # 创建compose文件
    if ! $compose_function; then
        echo -e "${RED}创建 $app_name compose文件失败${NC}"
        return 1
    fi
    
    # 启动容器
    if start_docker_app "$app_name"; then
        echo -e "${YELLOW}等待 $app_name 启动...${NC}"
        sleep 5
        
        # 检查容器是否启动成功
        local container_name="$app_name"
        if [[ "$app_name" == "moviepilot-v2" ]]; then
            container_name="moviepilot-v2"
        fi
        
        if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
            echo -e "${GREEN}$app_name 安装并启动成功${NC}"
            return 0
        else
            echo -e "${RED}$app_name 启动失败，请检查日志: docker logs $container_name${NC}"
            return 1
        fi
    else
        echo -e "${RED}$app_name 安装失败${NC}"
        return 1
    fi
}

# 启动Docker应用
start_docker_app() {
    local app_name="$1"
    # 处理特殊情况：moviepilot-v2的compose文件名是moviepilot
    local compose_name="$app_name"
    if [[ "$app_name" == "moviepilot-v2" ]]; then
        compose_name="moviepilot"
    fi
    
    local compose_file="/tmp/${compose_name}-compose.yml"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$compose_file" up -d
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker compose -f "$compose_file" up -d
    else
        echo -e "${RED}Docker Compose未找到${NC}"
        return 1
    fi
    
    local result=$?
    rm -f "$compose_file"
    return $result
}

# 下载并创建compose文件
download_compose_file() {
    local app_name="$1"
    local compose_file="/tmp/${app_name}-compose.yml"
    local github_url="$GITHUB_RAW/configs/docker-compose/${app_name}.yml"
    
    echo -e "${YELLOW}正在下载 ${app_name} 配置文件...${NC}"
    
    if curl -fsSL "$github_url" -o "$compose_file"; then
        echo -e "${GREEN}${app_name} 配置文件下载成功${NC}"
        return 0
    else
        echo -e "${RED}${app_name} 配置文件下载失败${NC}"
        return 1
    fi
}

# 创建qBittorrent compose文件
create_qbittorrent_compose() {
    download_compose_file "qbittorrent"
}

# 创建Transmission compose文件
create_transmission_compose() {
    download_compose_file "transmission"
}

# 创建Emby compose文件
create_emby_compose() {
    download_compose_file "emby"
}

# 创建IYUUPlus compose文件
create_iyuuplus_compose() {
    download_compose_file "iyuuplus"
}

# 创建MoviePilot compose文件
create_moviepilot_compose() {
    download_compose_file "moviepilot"
}

# 显示全套安装结果
show_full_suite_results() {
    echo
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}全套Docker应用安装完成！${NC}"
    echo -e "${GREEN}================================================${NC}"
    
    # 检查每个应用的安装状态
    local apps=("qBittorrent" "Transmission" "Emby" "IYUUPlus" "MoviePilot")
    local containers=("qbittorrent" "transmission" "emby" "iyuuplus" "moviepilot-v2")
    local success_count=0
    local failed_count=0
    
    echo -e "${BLUE}应用状态检查：${NC}"
    
    for i in "${!apps[@]}"; do
        local app="${apps[$i]}"
        local container="${containers[$i]}"
        
        if docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
            case $app in
                "qBittorrent")
                    echo -e "${GREEN}✓ qBittorrent 4.6.7: http://你的服务器IP:8080${NC}"
                    echo -e "${WHITE}  默认用户名/密码: admin/adminadmin${NC}"
                    ;;
                "Transmission")
                    echo -e "${GREEN}✓ Transmission 4.0.5: http://你的服务器IP:9091${NC}"
                    echo -e "${WHITE}  用户名/密码: admin/adminadmin${NC}"
                    ;;
                "Emby")
                    echo -e "${GREEN}✓ Emby: http://你的服务器IP:8096${NC}"
                    echo -e "${WHITE}  首次访问需要配置管理员账户${NC}"
                    ;;
                "IYUUPlus")
                    echo -e "${GREEN}✓ IYUUPlus: http://你的服务器IP:8780${NC}"
                    echo -e "${WHITE}  自动辅种工具${NC}"
                    ;;
                "MoviePilot")
                    echo -e "${GREEN}✓ MoviePilot: http://你的服务器IP:3000${NC}"
                    echo -e "${WHITE}  影视自动化管理工具${NC}"
                    ;;
            esac
            ((success_count++))
        else
            echo -e "${RED}✗ $app (容器未运行)${NC}"
            ((failed_count++))
        fi
    done
    
    echo
    echo -e "${BLUE}安装统计：${NC}"
    echo -e "${GREEN}成功: $success_count 个应用${NC}"
    if [[ $failed_count -gt 0 ]]; then
        echo -e "${RED}失败: $failed_count 个应用${NC}"
        echo -e "${YELLOW}建议查看Docker日志排查问题：docker logs <容器名>${NC}"
    fi
    
    echo
    echo -e "${BLUE}重要信息：${NC}"
    echo -e "${WHITE}• 数据目录: /opt/docker${NC}"
    echo -e "${WHITE}• 下载目录: /opt/downloads${NC}"
    echo -e "${WHITE}• IYUUPlus和MoviePilot已自动关联qBittorrent和Transmission${NC}"
    echo -e "${WHITE}• 查看容器状态: docker ps${NC}"
    echo -e "${WHITE}• 查看容器日志: docker logs <容器名>${NC}"
    echo -e "${GREEN}================================================${NC}"
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
    
    # 检测原作者脚本安装的qBittorrent
    echo -e "${YELLOW}正在检测原作者脚本安装的应用...${NC}"
    
    local qb_detected=false
    local qb_services=()
    local qb_processes=()
    local other_services=()
    
    # 检测qBittorrent相关服务
    if systemctl list-units --type=service --all | grep -q "qbittorrent"; then
        while IFS= read -r service; do
            if [[ -n "$service" ]]; then
                qb_services+=("$service")
                qb_detected=true
            fi
        done < <(systemctl list-units --type=service --all | grep "qbittorrent" | awk '{print $1}')
    fi
    
    # 检测qBittorrent进程
    if pgrep -f "qbittorrent" >/dev/null; then
        while IFS= read -r process; do
            if [[ -n "$process" ]]; then
                qb_processes+=("$process")
                qb_detected=true
            fi
        done < <(ps aux | grep qbittorrent | grep -v grep | awk '{print $2 " " $11}')
    fi
    
    # 检测其他相关服务
    for service in vertex autobrr autoremove-torrents; do
        if systemctl list-units --type=service --all | grep -q "$service"; then
            other_services+=("$service")
        fi
    done
    
    if [[ "$qb_detected" == true ]]; then
        echo -e "${GREEN}检测到原作者脚本安装的qBittorrent：${NC}"
        
        if [[ ${#qb_services[@]} -gt 0 ]]; then
            echo -e "${WHITE}服务：${NC}"
            for service in "${qb_services[@]}"; do
                local status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
                echo -e "${WHITE}  • $service ($status)${NC}"
            done
        fi
        
        if [[ ${#qb_processes[@]} -gt 0 ]]; then
            echo -e "${WHITE}进程：${NC}"
            for process in "${qb_processes[@]}"; do
                echo -e "${WHITE}  • $process${NC}"
            done
        fi
        
        echo
        echo -e "${GREEN}选择qBittorrent卸载方式：${NC}"
        echo "1. 自动卸载qBittorrent（推荐）"
        echo "2. 手动卸载指导"
        echo "3. 返回上级菜单"
        
        read -p "请选择 [1-3]: " qb_choice
        
        case $qb_choice in
            1)
                uninstall_qbittorrent_auto
                ;;
            2)
                show_manual_uninstall_guide
                ;;
            3)
                return
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                ;;
        esac
    else
        echo -e "${GRAY}未检测到原作者脚本安装的qBittorrent${NC}"
        echo
        
        if [[ ${#other_services[@]} -gt 0 ]]; then
            echo -e "${YELLOW}检测到其他相关服务：${NC}"
            for service in "${other_services[@]}"; do
                echo -e "${WHITE}  • $service${NC}"
            done
            echo
        fi
        
        echo -e "${BLUE}提供手动卸载指导：${NC}"
        show_manual_uninstall_guide
    fi
    
    echo -e "${YELLOW}按任意键返回...${NC}"
    read -n 1
}

# 自动卸载qBittorrent
uninstall_qbittorrent_auto() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}自动卸载qBittorrent${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo
    
    echo -e "${RED}警告：此操作将完全删除qBittorrent及其配置！${NC}"
    echo -e "${YELLOW}包括：${NC}"
    echo -e "${WHITE}• 停止所有qBittorrent服务和进程${NC}"
    echo -e "${WHITE}• 删除systemd服务文件${NC}"
    echo -e "${WHITE}• 删除程序文件${NC}"
    echo -e "${WHITE}• 删除配置文件和数据${NC}"
    echo -e "${WHITE}• 清理用户和组${NC}"
    echo
    
    read -p "确认卸载qBittorrent？[y/N]: " confirm_uninstall
    if [[ ! $confirm_uninstall =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}卸载已取消${NC}"
        return
    fi
    
    echo
    echo -e "${YELLOW}开始彻底卸载qBittorrent...${NC}"
    
    # 1. 暴力停止所有qBittorrent相关内容
    force_stop_all_qbittorrent
    
    # 2. 彻底删除所有服务文件
    force_remove_all_services
    
    # 3. 删除程序文件
    remove_qbittorrent_binaries
    
    # 4. 删除配置文件
    remove_qbittorrent_configs
    
    # 5. 清理用户和组
    cleanup_qbittorrent_user
    
    # 6. 清理其他残留
    cleanup_qbittorrent_misc
    
    # 7. 最终清理
    final_cleanup
    
    echo
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}qBittorrent卸载完成！${NC}"
    echo -e "${GREEN}================================================${NC}"
    
    # 验证卸载结果
    verify_qbittorrent_removal
}

# 暴力停止所有qBittorrent相关内容
force_stop_all_qbittorrent() {
    echo -e "${YELLOW}正在暴力停止所有qBittorrent相关内容...${NC}"
    
    # 1. 先停止所有可能的服务
    echo -e "${YELLOW}停止所有qBittorrent服务...${NC}"
    
    # 获取所有qbittorrent相关服务
    systemctl list-units --type=service --all | grep -i qbittorrent | awk '{print $1}' | while read -r service; do
        if [[ -n "$service" ]]; then
            echo -e "${GRAY}  停止服务: $service${NC}"
            systemctl stop "$service" 2>/dev/null
            systemctl disable "$service" 2>/dev/null
            systemctl mask "$service" 2>/dev/null
        fi
    done
    
    # 停止常见服务名的所有可能实例
    local service_patterns=("qbittorrent*" "qbittorrent-nox*")
    for pattern in "${service_patterns[@]}"; do
        systemctl stop "$pattern" 2>/dev/null
        systemctl disable "$pattern" 2>/dev/null
        systemctl mask "$pattern" 2>/dev/null
    done
    
    # 2. 强制杀死所有qBittorrent进程
    echo -e "${YELLOW}强制终止所有qBittorrent进程...${NC}"
    
    # 使用多种方式杀死进程
    pkill -9 -f "qbittorrent" 2>/dev/null
    pkill -9 "qbittorrent" 2>/dev/null  
    pkill -9 "qbittorrent-nox" 2>/dev/null
    killall -9 qbittorrent 2>/dev/null
    killall -9 qbittorrent-nox 2>/dev/null
    
    # 等待进程彻底结束
    sleep 2
    
    # 再次检查并强制杀死
    if pgrep -f "qbittorrent" >/dev/null; then
        echo -e "${RED}仍有顽固进程，使用kill -9强制终止...${NC}"
        pgrep -f "qbittorrent" | xargs -r kill -9 2>/dev/null
    fi
    
    echo -e "${GREEN}所有qBittorrent进程已终止${NC}"
}

# 彻底删除所有服务文件
force_remove_all_services() {
    echo -e "${YELLOW}正在彻底删除所有qBittorrent服务文件...${NC}"
    
    # 1. 删除systemd目录中的所有qbittorrent相关文件
    local systemd_dirs=(
        "/etc/systemd/system"
        "/lib/systemd/system" 
        "/usr/lib/systemd/system"
        "/usr/local/lib/systemd/system"
        "/run/systemd/system"
        "/etc/systemd/user"
        "/usr/lib/systemd/user"
        "/usr/local/lib/systemd/user"
    )
    
    for dir in "${systemd_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # 查找所有qbittorrent相关文件
            find "$dir" -name "*qbittorrent*" -type f 2>/dev/null | while read -r file; do
                echo -e "${GREEN}删除服务文件: $file${NC}"
                rm -f "$file"
            done
            
            # 查找所有qbittorrent相关链接
            find "$dir" -name "*qbittorrent*" -type l 2>/dev/null | while read -r link; do
                echo -e "${GREEN}删除服务链接: $link${NC}"
                rm -f "$link"
            done
            
            # 删除目标文件夹中的qbittorrent相关内容
            find "$dir" -type d -name "*qbittorrent*" 2>/dev/null | while read -r qb_dir; do
                echo -e "${GREEN}删除服务目录: $qb_dir${NC}"
                rm -rf "$qb_dir"
            done
        fi
    done
    
    # 2. 删除用户目录中的服务文件
    find /home -name ".config" -type d 2>/dev/null | while read -r config_dir; do
        local user_systemd="$config_dir/systemd/user"
        if [[ -d "$user_systemd" ]]; then
            find "$user_systemd" -name "*qbittorrent*" 2>/dev/null | while read -r file; do
                echo -e "${GREEN}删除用户服务文件: $file${NC}"
                rm -rf "$file"
            done
        fi
    done
    
    # 3. 重置所有systemd状态
    echo -e "${YELLOW}重置systemd状态...${NC}"
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null
    
    # 4. 尝试停止可能遗漏的服务
    for service in qbittorrent qbittorrent-nox qbittorrent@admin qbittorrent-nox@admin; do
        systemctl stop "$service" 2>/dev/null
        systemctl disable "$service" 2>/dev/null
        systemctl mask "$service" 2>/dev/null
    done
    
    echo -e "${GREEN}所有systemd服务文件已清理${NC}"
}

# 最终清理
final_cleanup() {
    echo -e "${YELLOW}正在进行最终清理...${NC}"
    
    # 1. 清理所有可能的systemctl残留
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null
    
    # 2. 强制删除任何遗留的qbittorrent服务定义
    systemctl list-units --type=service --all | grep -i qbittorrent | awk '{print $1}' | while read -r service; do
        if [[ -n "$service" ]]; then
            echo -e "${YELLOW}强制清理服务: $service${NC}"
            systemctl stop "$service" 2>/dev/null
            systemctl disable "$service" 2>/dev/null
            systemctl mask "$service" 2>/dev/null
        fi
    done
    
    # 3. 删除所有可能的二进制文件路径
    local all_possible_paths=(
        "/usr/local/bin/qbittorrent*"
        "/usr/bin/qbittorrent*"
        "/opt/qbittorrent*"
        "/usr/local/qbittorrent*"
        "/home/*/qbittorrent*"
        "/root/qbittorrent*"
    )
    
    for path_pattern in "${all_possible_paths[@]}"; do
        for path in $path_pattern; do
            if [[ -e "$path" ]]; then
                echo -e "${GREEN}删除: $path${NC}"
                rm -rf "$path"
            fi
        done
    done
    
    # 4. 强制清理systemd缓存
    systemctl daemon-reexec 2>/dev/null
    
    echo -e "${GREEN}最终清理完成${NC}"
}

# 验证卸载结果
verify_qbittorrent_removal() {
    echo -e "${BLUE}验证卸载结果：${NC}"
    
    local issues=()
    local all_clean=true
    
    # 1. 检查进程
    if pgrep -f "qbittorrent" >/dev/null; then
        local process_count=$(pgrep -f "qbittorrent" | wc -l)
        issues+=("仍有 $process_count 个qBittorrent进程运行")
        echo -e "${RED}✗ 仍有qBittorrent进程运行${NC}"
        ps aux | grep qbittorrent | grep -v grep | awk '{print "    PID: " $2 " CMD: " $11}'
        all_clean=false
    else
        echo -e "${GREEN}✓ 无qBittorrent进程${NC}"
    fi
    
    # 2. 检查服务（最严格的检查）
    local remaining_services=()
    while IFS= read -r service; do
        if [[ -n "$service" ]]; then
            remaining_services+=("$service")
        fi
    done < <(systemctl list-units --type=service --all 2>/dev/null | grep -i qbittorrent | awk '{print $1}' | sed 's/[●*]//')
    
    if [[ ${#remaining_services[@]} -gt 0 ]]; then
        issues+=("仍有 ${#remaining_services[@]} 个qBittorrent服务")
        echo -e "${RED}✗ 仍有qBittorrent服务存在${NC}"
        for service in "${remaining_services[@]}"; do
            echo -e "${RED}    $service${NC}"
        done
        all_clean=false
    else
        echo -e "${GREEN}✓ 无qBittorrent服务${NC}"
    fi
    
    # 3. 检查二进制文件
    local found_binaries=()
    for binary in qbittorrent qbittorrent-nox; do
        if command -v "$binary" >/dev/null 2>&1; then
            found_binaries+=("$binary")
        fi
    done
    
    if [[ ${#found_binaries[@]} -gt 0 ]]; then
        issues+=("仍可找到qBittorrent程序")
        echo -e "${RED}✗ 仍可找到qBittorrent程序${NC}"
        for binary in "${found_binaries[@]}"; do
            echo -e "${RED}    $binary -> $(which "$binary")${NC}"
        done
        all_clean=false
    else
        echo -e "${GREEN}✓ qBittorrent程序已删除${NC}"
    fi
    
    # 4. 检查配置文件
    local config_check=(
        "/home/qbittorrent"
        "/root/.config/qBittorrent"
        "/etc/qbittorrent"
    )
    
    local found_configs=()
    for config in "${config_check[@]}"; do
        if [[ -e "$config" ]]; then
            found_configs+=("$config")
        fi
    done
    
    if [[ ${#found_configs[@]} -gt 0 ]]; then
        echo -e "${YELLOW}! 发现残留配置${NC}"
        for config in "${found_configs[@]}"; do
            echo -e "${YELLOW}    $config${NC}"
        done
    else
        echo -e "${GREEN}✓ 配置文件已清理${NC}"
    fi
    
    echo
    if [[ "$all_clean" == true ]]; then
        echo -e "${GREEN}🎉 qBittorrent已完全卸载！无任何残留！${NC}"
        echo -e "${GREEN}如果之前有残留问题，现在应该已经解决了。${NC}"
    else
        echo -e "${RED}⚠️  仍有残留，但已尽最大努力清理${NC}"
        echo -e "${YELLOW}如果仍有问题，建议重启系统${NC}"
        echo
        echo -e "${BLUE}手动清理命令：${NC}"
        echo -e "${GRAY}systemctl daemon-reload${NC}"
        echo -e "${GRAY}systemctl reset-failed${NC}"
        echo -e "${GRAY}reboot${NC}"
    fi
}

# 备份qBittorrent配置
backup_qb_config() {
    echo -e "${YELLOW}正在备份配置文件...${NC}"
    
    local backup_dir="/root/qbittorrent_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 常见配置路径
    local config_paths=(
        "/home/qbittorrent/.config/qBittorrent"
        "/root/.config/qBittorrent"
        "/etc/qbittorrent"
        "/opt/qbittorrent"
        "/usr/local/etc/qbittorrent"
    )
    
    local backed_up=false
    for path in "${config_paths[@]}"; do
        if [[ -d "$path" ]]; then
            echo -e "${GREEN}备份: $path${NC}"
            cp -r "$path" "$backup_dir/" 2>/dev/null
            backed_up=true
        fi
    done
    
    if [[ "$backed_up" == true ]]; then
        echo -e "${GREEN}配置文件已备份到: $backup_dir${NC}"
    else
        echo -e "${YELLOW}未找到配置文件，跳过备份${NC}"
        rmdir "$backup_dir" 2>/dev/null
    fi
}

# 停止qBittorrent服务和进程
stop_qbittorrent_services() {
    echo -e "${YELLOW}正在停止qBittorrent服务和进程...${NC}"
    
    # 停止systemd服务
    for service in qbittorrent qbittorrent-nox qbittorrent@qbittorrent; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "${YELLOW}停止服务: $service${NC}"
            systemctl stop "$service"
            systemctl disable "$service" 2>/dev/null
        fi
    done
    
    # 杀死qBittorrent进程
    if pgrep -f "qbittorrent" >/dev/null; then
        echo -e "${YELLOW}终止qBittorrent进程...${NC}"
        pkill -f "qbittorrent"
        sleep 2
        
        # 强制杀死顽固进程
        if pgrep -f "qbittorrent" >/dev/null; then
            echo -e "${YELLOW}强制终止qBittorrent进程...${NC}"
            pkill -9 -f "qbittorrent"
        fi
    fi
    
    echo -e "${GREEN}qBittorrent服务和进程已停止${NC}"
}

# 删除systemd服务文件
remove_qbittorrent_services() {
    echo -e "${YELLOW}正在删除systemd服务文件...${NC}"
    
    local service_paths=(
        "/etc/systemd/system/qbittorrent.service"
        "/etc/systemd/system/qbittorrent-nox.service"
        "/etc/systemd/system/qbittorrent@.service"
        "/lib/systemd/system/qbittorrent.service"
        "/usr/lib/systemd/system/qbittorrent.service"
    )
    
    for service_file in "${service_paths[@]}"; do
        if [[ -f "$service_file" ]]; then
            echo -e "${GREEN}删除服务文件: $service_file${NC}"
            rm -f "$service_file"
        fi
    done
    
    # 重新加载systemd
    systemctl daemon-reload
    echo -e "${GREEN}systemd服务文件已清理${NC}"
}

# 删除程序文件
remove_qbittorrent_binaries() {
    echo -e "${YELLOW}正在删除程序文件...${NC}"
    
    # 常见安装路径
    local binary_paths=(
        "/usr/local/bin/qbittorrent"
        "/usr/local/bin/qbittorrent-nox"
        "/usr/bin/qbittorrent"
        "/usr/bin/qbittorrent-nox"
        "/opt/qbittorrent"
        "/usr/local/qbittorrent"
    )
    
    for path in "${binary_paths[@]}"; do
        if [[ -e "$path" ]]; then
            echo -e "${GREEN}删除: $path${NC}"
            rm -rf "$path"
        fi
    done
    
    # 删除可能的符号链接
    find /usr/local/bin /usr/bin -name "*qbittorrent*" -type l 2>/dev/null | while read -r link; do
        echo -e "${GREEN}删除链接: $link${NC}"
        rm -f "$link"
    done
    
    echo -e "${GREEN}程序文件已删除${NC}"
}

# 删除配置文件
remove_qbittorrent_configs() {
    echo -e "${YELLOW}正在删除配置文件...${NC}"
    
    local config_paths=(
        "/home/qbittorrent"
        "/root/.config/qBittorrent"
        "/etc/qbittorrent"
        "/opt/qbittorrent"
        "/usr/local/etc/qbittorrent"
        "/var/lib/qbittorrent"
        "/tmp/qbittorrent*"
    )
    
    for path in "${config_paths[@]}"; do
        if [[ -e "$path" ]]; then
            echo -e "${GREEN}删除配置: $path${NC}"
            rm -rf "$path"
        fi
    done
    
    echo -e "${GREEN}配置文件已删除${NC}"
}

# 清理用户和组
cleanup_qbittorrent_user() {
    echo -e "${YELLOW}正在清理用户和组...${NC}"
    
    # 删除qbittorrent用户
    if id "qbittorrent" &>/dev/null; then
        echo -e "${GREEN}删除用户: qbittorrent${NC}"
        userdel -r qbittorrent 2>/dev/null
    fi
    
    # 删除qbittorrent组
    if getent group qbittorrent &>/dev/null; then
        echo -e "${GREEN}删除组: qbittorrent${NC}"
        groupdel qbittorrent 2>/dev/null
    fi
    
    echo -e "${GREEN}用户和组已清理${NC}"
}

# 清理其他残留
cleanup_qbittorrent_misc() {
    echo -e "${YELLOW}正在清理其他残留文件...${NC}"
    
    # 清理日志文件
    find /var/log -name "*qbittorrent*" -type f 2>/dev/null | while read -r log_file; do
        echo -e "${GREEN}删除日志: $log_file${NC}"
        rm -f "$log_file"
    done
    
    # 清理临时文件
    find /tmp -name "*qbittorrent*" 2>/dev/null | while read -r temp_file; do
        echo -e "${GREEN}删除临时文件: $temp_file${NC}"
        rm -rf "$temp_file"
    done
    
    # 清理cron任务
    if crontab -l 2>/dev/null | grep -q "qbittorrent"; then
        echo -e "${YELLOW}检测到qBittorrent相关的cron任务，请手动检查${NC}"
        echo -e "${WHITE}执行: crontab -e${NC}"
    fi
    
    echo -e "${GREEN}其他残留文件已清理${NC}"
}

# 验证卸载结果
verify_qbittorrent_removal() {
    echo -e "${BLUE}验证卸载结果：${NC}"
    
    local issues=()
    
    # 检查进程
    if pgrep -f "qbittorrent" >/dev/null; then
        issues+=("仍有qBittorrent进程运行")
    else
        echo -e "${GREEN}✓ 无qBittorrent进程${NC}"
    fi
    
    # 检查服务
    if systemctl list-units --type=service --all | grep -q "qbittorrent"; then
        issues+=("仍有qBittorrent服务存在")
    else
        echo -e "${GREEN}✓ 无qBittorrent服务${NC}"
    fi
    
    # 检查常见二进制文件
    if command -v qbittorrent >/dev/null || command -v qbittorrent-nox >/dev/null; then
        issues+=("仍可找到qBittorrent程序")
    else
        echo -e "${GREEN}✓ qBittorrent程序已删除${NC}"
    fi
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo -e "${YELLOW}需要手动处理的问题：${NC}"
        for issue in "${issues[@]}"; do
            echo -e "${RED}  • $issue${NC}"
        done
    else
        echo -e "${GREEN}✓ qBittorrent已完全卸载${NC}"
    fi
}

# 显示手动卸载指导
show_manual_uninstall_guide() {
    echo -e "${BLUE}手动卸载指导：${NC}"
    echo
    echo -e "${WHITE}1. 停止qBittorrent服务：${NC}"
    echo -e "${GRAY}   systemctl stop qbittorrent${NC}"
    echo -e "${GRAY}   systemctl disable qbittorrent${NC}"
    echo
    echo -e "${WHITE}2. 删除服务文件：${NC}"
    echo -e "${GRAY}   rm -f /etc/systemd/system/qbittorrent*.service${NC}"
    echo -e "${GRAY}   systemctl daemon-reload${NC}"
    echo
    echo -e "${WHITE}3. 删除程序文件：${NC}"
    echo -e "${GRAY}   rm -rf /usr/local/bin/qbittorrent*${NC}"
    echo -e "${GRAY}   rm -rf /opt/qbittorrent${NC}"
    echo
    echo -e "${WHITE}4. 删除配置文件：${NC}"
    echo -e "${GRAY}   rm -rf /home/qbittorrent${NC}"
    echo -e "${GRAY}   rm -rf /root/.config/qBittorrent${NC}"
    echo
    echo -e "${WHITE}5. 删除用户：${NC}"
    echo -e "${GRAY}   userdel -r qbittorrent${NC}"
    echo
    echo -e "${WHITE}6. 检查进程：${NC}"
    echo -e "${GRAY}   ps aux | grep qbittorrent${NC}"
    echo -e "${GRAY}   pkill -f qbittorrent${NC}"
}

# 使用Docker安装Vertex
install_vertex_docker() {
    echo -e "${YELLOW}正在创建Vertex目录...${NC}"
    mkdir -p /opt/docker/vertex
    
    echo -e "${YELLOW}正在下载Vertex Docker Compose配置...${NC}"
    local compose_file="/tmp/vertex-compose.yml"
    local github_url="$GITHUB_RAW/configs/docker-compose/vertex.yml"
    
    if curl -fsSL "$github_url" -o "$compose_file"; then
        echo -e "${GREEN}Vertex配置文件下载成功${NC}"
    else
        echo -e "${RED}Vertex配置文件下载失败，使用内置配置${NC}"
        # 备用配置
        cat > "$compose_file" << 'EOF'
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
    fi

    echo -e "${YELLOW}正在启动Vertex容器...${NC}"
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$compose_file" up -d
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker compose -f "$compose_file" up -d
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
    rm -f "$compose_file"
    
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
                install_full_docker_suite
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
