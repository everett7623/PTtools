#!/bin/bash

# ===================================================================================================
# PTtools - PT工具一键安装脚本
# 脚本名称: pttools.sh
# 脚本描述: PT工具一键安装脚本，支持qBittorrent、Transmission、Emby等应用的快捷安装
# 脚本路径: https://raw.githubusercontent.com/everett7623/PTtools/main/pttools.sh
# 使用方法: bash <(wget -qO- https://raw.githubusercontent.com/everett7623/pttools/main/pttools.sh)
# 作者: Jensfrank (GitHub: everett7623)
# 更新时间: 2025-09-18
# ===================================================================================================

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
LOG_DIR="/opt/logs/pttools"
PTTOOLS_LOG_FILE="$LOG_DIR/pttools.log" # 主脚本日志文件

# 显示横幅
show_banner() {
    echo -e "${CYAN}"
    echo "=================================================="
    echo "           PTtools - PT工具一键安装脚本"
    echo "               作者: Jensfrank"
    echo "=================================================="
    echo -e "${NC}"
}

# 记录日志 (只写入文件，不输出到终端)
log_message() {
    mkdir -p "$LOG_DIR" &>/dev/null # 确保日志目录在记录前存在
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$timestamp] $1" >> "$PTTOOLS_LOG_FILE"
}

# 检查是否为root用户
check_root() {
    echo -e "${YELLOW}正在检查root权限...${NC}" # 终端显示
    log_message "${YELLOW}正在检查root权限...${NC}" # 日志记录
    if [[ $EUID -ne 0 ]]; then
        log_message "${RED}错误：此脚本需要root权限运行${NC}"
        echo -e "${RED}错误：此脚本需要root权限运行${NC}" # 终端显示错误
        echo "请使用 sudo 或切换到root用户后重新运行"
        exit 1
    fi
    log_message "${GREEN}root权限检查通过${NC}"
    echo -e "${GREEN}root权限检查通过${NC}" # 终端显示成功
}

# 检查系统类型
check_system() {
    echo -e "${YELLOW}正在检测系统类型...${NC}"
    log_message "${YELLOW}正在检测系统类型...${NC}"
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
        log_message "${RED}不支持的系统类型${NC}"
        echo -e "${RED}不支持的系统类型${NC}"
        echo -e "${YELLOW}当前支持的系统：${NC}"
        echo -e "${WHITE}- Debian/Ubuntu 系列${NC}"
        echo -e "${WHITE}- CentOS/RHEL 系列${NC}"
        echo
        echo -e "${YELLOW}当前系统信息：${NC}"
        uname -a
        exit 1
    fi
    log_message "${GREEN}系统类型: $DISTRO, 版本: $OS_VERSION, 包管理器: $PM${NC}"
    echo -e "${GREEN}系统类型: $DISTRO (版本: $OS_VERSION)${NC}" # 终端显示更精简
}

# 更新系统
update_system() {
    echo -e "${YELLOW}正在更新系统...${NC}"
    log_message "${YELLOW}正在更新系统...${NC}"
    if apt update -y &>> "$PTTOOLS_LOG_FILE"; then # 统一处理apt/yum
        log_message "${GREEN}系统更新成功${NC}"
        echo -e "${GREEN}系统更新成功${NC}"
    else
        log_message "${RED}系统更新失败，但继续安装${NC}"
        echo -e "${RED}系统更新失败，但继续安装${NC}"
    fi
}

# 安装基础工具
install_base_tools() {
    echo -e "${YELLOW}正在安装基础工具 (curl, wget, git, unzip)...${NC}"
    log_message "${YELLOW}正在安装基础工具 (curl, wget, git, unzip)...${NC}"
    if [[ $DISTRO == "debian" ]]; then
        if apt install -y curl wget git unzip &>> "$PTTOOLS_LOG_FILE"; then
            log_message "${GREEN}基础工具安装成功${NC}"
            echo -e "${GREEN}基础工具安装成功${NC}"
        else
            log_message "${RED}基础工具安装失败${NC}"
            echo -e "${RED}基础工具安装失败${NC}"
            return 1
        fi
    elif [[ $DISTRO == "centos" ]]; then
        if yum install -y curl wget git unzip &>> "$PTTOOLS_LOG_FILE"; then
            log_message "${GREEN}基础工具安装成功${NC}"
            echo -e "${GREEN}基础工具安装成功${NC}"
        else
            log_message "${RED}基础工具安装失败${NC}"
            echo -e "${RED}基础工具安装失败${NC}"
            return 1
        fi
    fi

    for tool in curl wget; do
        if ! command -v "$tool" &> /dev/null; then
            log_message "${RED}关键工具 $tool 安装失败${NC}"
            echo -e "${RED}关键工具 $tool 安装失败${NC}"
            return 1
        fi
    done

    log_message "${GREEN}所有基础工具验证通过${NC}"
    echo -e "${GREEN}所有基础工具验证通过${NC}"
    return 0
}

# 检查并静默报告Docker状态
check_docker_status() {
    echo -e "${YELLOW}正在检查Docker状态...${NC}"
    log_message "${YELLOW}正在检查Docker状态...${NC}"
    local docker_status_msg="Docker状态: 未安装"
    if command -v docker &> /dev/null; then
        docker_version=$(docker --version | head -n 1)
        docker_status_msg="Docker状态: 已安装 ($docker_version)"
    fi
    echo -e "${GREEN}${docker_status_msg}${NC}" # 终端显示
    log_message "${GREEN}${docker_status_msg}${NC}" # 日志记录

    local compose_status_msg="Docker Compose状态: 未安装"
    if command -v docker-compose &> /dev/null; then
        compose_version=$(docker-compose --version | head -n 1)
        compose_status_msg="Docker Compose状态: 已安装 ($compose_version)"
    elif docker compose version &> /dev/null; then
        compose_version=$(docker compose version | head -n 1)
        compose_status_msg="Docker Compose状态: 已安装 ($compose_version)"
    fi
    echo -e "${GREEN}${compose_status_msg}${NC}" # 终端显示
    log_message "${GREEN}${compose_status_msg}${NC}" # 日志记录
}

# 安装Docker (内部函数，仅执行安装，不负责终端输出结果，只返回状态)
install_docker_func() {
    log_message "${YELLOW}Docker安装流程开始...${NC}"
    echo -e "${YELLOW}正在安装Docker...${NC}" # 终端提示正在安装
    
    # 基础工具检查
    if ! command -v curl &> /dev/null; then
        log_message "${RED}curl未安装，尝试在Docker安装前安装基础工具...${NC}"
        if [[ $DISTRO == "debian" ]]; then
            apt update -y &>> "$PTTOOLS_LOG_FILE"
            apt install -y curl wget git unzip &>> "$PTTOOLS_LOG_FILE"
        elif [[ $DISTRO == "centos" ]]; then
            yum update -y &>> "$PTTOOLS_LOG_FILE"
            yum install -y curl wget git unzip &>> "$PTTOOLS_LOG_FILE"
        fi
        if ! command -v curl &> /dev/null; then
            log_message "${RED}基础工具安装失败，无法继续安装Docker${NC}"
            return 1 # 失败
        fi
    fi

    # --- 网络连通性预检 ---
    echo -e "${YELLOW}正在测试网络连通性 (get.docker.com)...${NC}"
    log_message "${YELLOW}正在测试网络连通性 (get.docker.com)...${NC}"
    if ! curl -Is https://get.docker.com &>/dev/null; then
        log_message "${RED}网络连通性测试失败：无法访问 get.docker.com。请检查网络。${NC}"
        echo -e "${RED}网络连通性测试失败：无法访问 get.docker.com。请检查您的网络连接或DNS设置。${NC}"
        return 1
    fi
    log_message "${GREEN}网络连通性测试成功。${NC}"
    echo -e "${GREEN}网络连通性测试成功。${NC}"

    echo -e "${YELLOW}请选择Docker安装源：${NC}"
    echo "1. 官方源（默认）"
    echo "2. 阿里云镜像源"
    read -p "请选择 [1-2]: " docker_source_choice
    local docker_install_cmd="curl -fsSL https://get.docker.com | bash -s docker"

    if [[ "$docker_source_choice" == "2" ]]; then
        log_message "${YELLOW}使用阿里云镜像源安装Docker...${NC}"
        echo -e "${YELLOW}使用阿里云镜像源安装Docker...${NC}" # 终端提示
        docker_install_cmd+=" --mirror Aliyun"
    else
        log_message "${YELLOW}使用官方源安装Docker...${NC}"
        echo -e "${YELLOW}使用官方源安装Docker...${NC}" # 终端提示
    fi

    # 执行 Docker 安装脚本并捕获错误
    local docker_install_output=""
    echo -e "${YELLOW}正在运行Docker官方安装脚本，此过程可能导致SSH短暂中断，请耐心等待...${NC}"
    log_message "${YELLOW}正在运行Docker官方安装脚本，此过程可能导致SSH短暂中断，请耐心等待...${NC}"
    if ! docker_install_output=$(eval "$docker_install_cmd" 2>&1); then
        log_message "${RED}Docker安装脚本执行失败。原始输出：\n$docker_install_output${NC}"
        # 尝试从错误输出中提取关键信息
        local error_summary=$(echo "$docker_install_output" | tail -n 5 | grep -v "install-docker.sh" | sed '/^$/d')
        if [[ -n "$error_summary" ]]; then
            echo -e "${RED}Docker安装脚本执行失败。可能原因：\n${error_summary}${NC}"
        else
            echo -e "${RED}Docker安装脚本执行失败。请查看日志获取详细信息：$PTTOOLS_LOG_FILE${NC}"
        fi
        return 1 # 失败
    else
        log_message "${GREEN}Docker安装脚本执行成功。输出：\n$docker_install_output${NC}"
    fi

    log_message "${YELLOW}启动Docker服务...${NC}"
    echo -e "${YELLOW}启动Docker服务...${NC}" # 终端提示
    # 增加启动后的等待时间，给系统更多稳定时间，尤其是在网络可能被修改后
    if systemctl start docker &>> "$PTTOOLS_LOG_FILE"; then
        log_message "${GREEN}Docker服务启动成功${NC}"
        sleep 5 # 增加额外等待时间
    else
        log_message "${RED}Docker服务启动失败${NC}"
        service docker start &>> "$PTTOOLS_LOG_FILE" # 尝试手动启动
        sleep 5 # 增加额外等待时间
    fi

    if systemctl enable docker &>> "$PTTOOLS_LOG_FILE"; then
        log_message "${GREEN}Docker开机自启设置成功${NC}"
    else
        log_message "${YELLOW}Docker开机自启设置失败，但不影响使用${NC}"
    fi

    sleep 3 # 再次等待，确保Docker完全稳定
    if command -v docker &> /dev/null && docker --version &> /dev/null; then
        log_message "${GREEN}Docker核心安装成功: $(docker --version | head -n 1)${NC}"
    else
        log_message "${RED}Docker核心安装验证失败${NC}"
        return 1 # 失败
    fi

    echo -e "${YELLOW}是否安装Docker Compose？[Y/n]: ${NC}"
    read -r install_compose
    install_compose=${install_compose:-Y}
    if [[ $install_compose =~ ^[Yy]$ ]]; then
        log_message "${YELLOW}正在安装Docker Compose...${NC}"
        echo -e "${YELLOW}正在安装Docker Compose...${NC}" # 终端提示

        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
        if [ -z "$COMPOSE_VERSION" ]; then
            COMPOSE_VERSION="v2.24.0"
            log_message "${YELLOW}无法获取最新Docker Compose版本，使用备用版本 $COMPOSE_VERSION${NC}"
            echo -e "${YELLOW}无法获取最新版本，使用备用版本 $COMPOSE_VERSION${NC}"
        fi

        local compose_install_output=""
        if ! compose_install_output=$(curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>&1); then
            log_message "${RED}Docker Compose下载失败。输出：\n$compose_install_output${NC}"
            echo -e "${RED}Docker Compose下载失败，但不影响Docker使用（可能需要手动安装）。${NC}" # 终端提示
        else
            chmod +x /usr/local/bin/docker-compose
            log_message "${GREEN}Docker Compose安装完成: $(/usr/local/bin/docker-compose --version | head -n 1)${NC}"
        fi
    else
        log_message "${YELLOW}用户选择跳过Docker Compose安装。${NC}"
    fi

    return 0 # 成功
}

# 确保Docker已安装 (交互式，在菜单3,4,5,6中调用)
ensure_docker_installed() {
    if command -v docker &> /dev/null; then
        return 0 # Docker已安装，直接返回成功
    fi

    echo -e "${YELLOW}此功能需要Docker支持，但检测到Docker未安装。${NC}"
    echo -e "${YELLOW}是否现在安装Docker？[Y/n]: ${NC}"
    read -r install_docker_choice
    install_docker_choice=${install_docker_choice:-Y}

    if [[ $install_docker_choice =~ ^[Yy]$ ]]; then
        if install_docker_func; then # 调用安装函数
            log_message "${GREEN}Docker环境安装成功！${NC}"
            echo -e "${GREEN}Docker环境安装成功！${NC}" # 统一输出成功信息
            return 0
        else
            log_message "${RED}Docker环境安装失败。${NC}"
            echo -e "${RED}Docker环境安装失败。${NC}" # 统一输出失败信息
            echo -e "${YELLOW}建议：${NC}"
            echo -e "${WHITE}1. 检查网络连接，特别是能否访问 get.docker.com 或 GitHub${NC}" # 更明确的建议
            echo -e "${WHITE}2. 确认系统源配置正确${NC}"
            echo -e "${WHITE}3. 手动安装Docker后重试${NC}"
            echo -e "${WHITE}   详细日志请查看：${PTTOOLS_LOG_FILE}${NC}" # 指示用户查看日志
            echo
            echo -e "${YELLOW}按任意键返回主菜单...${NC}" # 统一在这里提示返回
            read -n 1
            return 1
        fi
    else
        log_message "${RED}用户取消Docker安装，无法继续。${NC}"
        echo -e "${RED}用户取消Docker安装，无法继续。${NC}"
        echo
        echo -e "${YELLOW}按任意键返回主菜单...${NC}" # 用户取消也提示返回
        read -n 1
        return 1
    fi
}

# 创建必要目录 (只创建项目根目录和日志目录)
create_directories() {
    echo -e "${YELLOW}正在创建项目核心目录...${NC}"
    log_message "${YELLOW}正在创建项目核心目录: ${DOCKER_DIR}, ${DOWNLOADS_DIR}, ${LOG_DIR}${NC}"
    mkdir -p "$DOCKER_DIR" &>> "$PTTOOLS_LOG_FILE"
    mkdir -p "$DOWNLOADS_DIR" &>> "$PTTOOLS_LOG_FILE"
    mkdir -p "$LOG_DIR" &>> "$PTTOOLS_LOG_FILE"
    log_message "${GREEN}核心目录创建完成${NC}"
    echo -e "${GREEN}核心目录创建完成。${NC}"
}

# 安装qBittorrent 4.3.8
install_qb438() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}正在安装 qBittorrent 4.3.8${NC}"
    echo -e "${CYAN}================================================${NC}"
    log_message "${CYAN}正在安装 qBittorrent 4.3.8${NC}"
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
    log_message "安装qBittorrent 4.3.8参数: 用户名=$username, 密码=$password, Web端口=$web_port, BT端口=$bt_port"

    read -p "确认安装？[Y/n]: " confirm
    confirm=${confirm:-Y}

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_message "${YELLOW}安装已取消${NC}"
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi

    echo -e "${YELLOW}正在下载并执行安装脚本...${NC}"
    log_message "${YELLOW}正在下载并执行安装脚本...${NC}"
    local install_cmd="bash <(wget -qO- https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh) \"$username\" \"$password\" \"$web_port\" \"$bt_port\""
    log_message "执行命令: $install_cmd"
    echo -e "${BLUE}执行命令: $install_cmd${NC}"
    echo

    if eval "$install_cmd" &>> "$LOG_DIR/pttools.log"; then
        echo
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}qBittorrent 4.3.8 安装完成！${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}访问地址: http://你的服务器IP:${web_port}${NC}"
        echo -e "${GREEN}用户名: ${username}${NC}"
        echo -e "${GREEN}密码: ${password}${NC}"
        echo -e "${GREEN}BT端口: ${bt_port}${NC}"
        echo -e "${GREEN}================================================${NC}"
        log_message "${GREEN}qBittorrent 4.3.8 安装成功，访问地址: http://你的服务器IP:${web_port}${NC}"
    else
        echo
        echo -e "${RED}================================================${NC}"
        echo -e "${RED}qBittorrent 4.3.8 安装失败！${NC}"
        echo -e "${RED}请检查网络连接和系统兼容性，详情请查看日志：$LOG_DIR/pttools.log${NC}"
        echo -e "${RED}================================================${NC}"
        log_message "${RED}qBittorrent 4.3.8 安装失败！${NC}"
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
    log_message "${CYAN}正在安装 qBittorrent 4.3.9${NC}"
    echo
    echo -e "${YELLOW}此功能将调用原作者脚本进行安装${NC}"
    echo -e "${YELLOW}原作者：jerry048${NC}"
    echo -e "${YELLOW}脚本来源：https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh${NC}"
    echo
    echo -e "${BLUE}安装参数配置：${NC}"
    echo

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
    log_message "安装qBittorrent 4.3.9参数: 用户名=$username, 密码=$password, 缓存=$cache_size, libtorrent=$libtorrent_ver, autobrr=$install_autobrr, autoremove=$install_autoremove, BBRx=$enable_bbrx"

    read -p "确认安装？[Y/n]: " confirm
    confirm=${confirm:-Y}

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_message "${YELLOW}安装已取消${NC}"
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi

    local install_cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u \"$username\" -p \"$password\" -c \"$cache_size\" -q 4.3.9 -l \"$libtorrent_ver\""
    [[ -n "$autobrr_flag" ]] && install_cmd="$install_cmd $autobrr_flag"
    [[ -n "$autoremove_flag" ]] && install_cmd="$install_cmd $autoremove_flag"
    [[ -n "$bbrx_flag" ]] && install_cmd="$install_cmd $bbrx_flag"

    echo -e "${YELLOW}正在执行安装命令...${NC}"
    log_message "${YELLOW}正在执行命令: $install_cmd${NC}"
    echo -e "${BLUE}执行命令: $install_cmd${NC}"
    echo

    if eval "$install_cmd" &>> "$LOG_DIR/pttools.log"; then
        echo
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}qBittorrent 4.3.9 安装完成！${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}用户名: ${username}${NC}"
        echo -e "${GREEN}密码: ${password}${NC}"
        echo -e "${GREEN}缓存大小: ${cache_size} MiB${NC}"
        echo -e "${GREEN}================================================${NC}"
        log_message "${GREEN}qBittorrent 4.3.9 安装成功${NC}"
    else
        echo
        echo -e "${RED}================================================${NC}"
        echo -e "${RED}qBittorrent 4.3.9 安装失败！${NC}"
        echo -e "${RED}请检查网络连接和系统兼容性，详情请查看日志：$LOG_DIR/pttools.log${NC}"
        echo -e "${RED}================================================${NC}"
        log_message "${RED}qBittorrent 4.3.9 安装失败！${NC}"
    fi

    echo
    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
    read -n 1
}

# 使用Docker安装Vertex
install_vertex_docker() {
    echo -e "${YELLOW}正在创建Vertex应用目录: $DOCKER_DIR/vertex/config ...${NC}"
    log_message "${YELLOW}正在创建Vertex应用目录: ${DOCKER_DIR}/vertex/config 和 ${DOCKER_DIR}/vertex/data${NC}"
    mkdir -p "$DOCKER_DIR/vertex/config" &>> "$LOG_DIR/pttools.log"
    mkdir -p "$DOCKER_DIR/vertex/data" &>> "$LOG_DIR/pttools.log" # 根据需求增加data目录

    echo -e "${YELLOW}正在下载Vertex Docker Compose配置...${NC}"
    log_message "${YELLOW}正在下载Vertex Docker Compose配置...${NC}"
    local compose_file="${DOCKER_DIR}/vertex/vertex.yml" # Download directly to app dir
    local github_url="$GITHUB_RAW/configs/docker-compose/automation/vertex.yml" # Corrected compose_subdir

    if curl -fsSL "$github_url" -o "$compose_file" &>> "$LOG_DIR/pttools.log"; then
        log_message "${GREEN}Vertex配置文件下载成功${NC}"
        echo -e "${GREEN}Vertex配置文件下载成功${NC}"
    else
        log_message "${RED}Vertex配置文件下载失败，使用内置配置${NC}"
        echo -e "${RED}Vertex配置文件下载失败，使用内置配置${NC}"
        # 备用配置 (符合规范的目录映射)
        cat > "$compose_file" << EOF
# ===================================================================
# Vertex Docker Compose 配置文件
# ===================================================================
# 文件名称: vertex.yml
# 应用描述: Vertex 媒体管理工具
# 官方网站: https://vertex.icu/
# Docker Hub: https://hub.docker.com/r/lswl/vertex
# ===================================================================
# 脚本信息:
#   - 脚本名称: PTtools
#   - 脚本作者: Jensfrank
#   - 项目地址: https://github.com/everett7623/PTtools
#   - 配置路径: https://raw.githubusercontent.com/everett7623/PTtools/main/configs/docker-compose/automation/vertex.yml
# ===================================================================
# 使用方法:
#   1. 确保已安装 Docker 和 Docker Compose
#   2. 执行命令: docker-compose -f vertex.yml up -d
#   3. 访问地址: http://your-server-ip:端口号
# ===================================================================
# 更新信息:
#   - 创建时间: 2025-01-XX
#   - 最后更新: 2025-09-18
#   - 更新内容: 初始版本创建
# ===================================================================

version: '3.8'

services:
  vertex:
    image: lswl/vertex:stable
    container_name: vertex
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - $DOCKER_DIR/vertex/config:/config # 遵循 /opt/docker/应用名/config 规范
      - $DOWNLOADS_DIR:/downloads # 遵循 /opt/downloads 规范
      - /etc/localtime:/etc/localtime:ro
    ports:
      - 3333:3000
    restart: unless-stopped
EOF
    fi

    echo -e "${YELLOW}正在启动Vertex容器...${NC}"
    log_message "${YELLOW}正在启动Vertex容器...${NC}"
    local docker_compose_bin=""
    if command -v docker-compose &> /dev/null; then
        docker_compose_bin="docker-compose"
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker_compose_bin="docker compose"
    else
        log_message "${RED}Docker Compose或docker compose未找到，尝试使用docker run命令启动...${NC}"
        echo -e "${RED}Docker Compose或docker compose未找到，尝试使用docker run命令启动...${NC}"
        # Fallback to docker run requires manual volume mapping and port assignment as per the compose file logic
        # This part is complex to match exactly generic compose, keep it simple or warn user to install compose
        docker_compose_cmd="docker run -d \
            --name vertex \
            --restart unless-stopped \
            -p 3333:3000 \
            -v \"$DOCKER_DIR/vertex/config\":/config \
            -v \"$DOWNLOADS_DIR\":/downloads \
            -v /etc/localtime:/etc/localtime:ro \
            -e TZ=Asia/Shanghai \
            lswl/vertex:stable"
    fi

    local current_dir=$(pwd)
    cd "${DOCKER_DIR}/vertex" &>> "$LOG_DIR/pttools.log" || { 
        log_message "${RED}切换目录失败: ${DOCKER_DIR}/vertex${NC}"; 
        echo -e "${RED}错误：无法进入应用目录 ${DOCKER_DIR}/vertex！${NC}"; 
        cd "$current_dir" &>/dev/null; 
        return 1; 
    }

    if eval "$docker_compose_cmd" -f "${DOCKER_DIR}/vertex/vertex.yml" up -d &>> "$LOG_DIR/pttools.log"; then
        log_message "${GREEN}Vertex Docker安装完成${NC}"
        echo -e "${GREEN}Vertex Docker安装完成${NC}"
        echo -e "${GREEN}访问地址: http://你的服务器IP:3333${NC}"
        echo -e "${GREEN}默认用户名: admin${NC}"
        # 尝试获取Docker版Vertex的随机密码
        echo -e "${YELLOW}正在尝试获取Vertex的初始密码 (可能需要几秒)...${NC}"
        sleep 5
        local vertex_password_file="$DOCKER_DIR/vertex/config/data/password" # 假设密码存储在此
        if [ -f "$vertex_password_file" ]; then
            local vertex_password=$(cat "$vertex_password_file" 2>/dev/null)
            if [ -n "$vertex_password" ]; then
                echo -e "${GREEN}Vertex密码: ${vertex_password}${NC}"
                log_message "${GREEN}Vertex密码: ${vertex_password}${NC}"
            else
                echo -e "${YELLOW}Vertex密码: 密码文件为空，请执行 cat $vertex_password_file 查看${NC}"
                log_message "${YELLOW}Vertex密码文件为空${NC}"
            fi
        else
            echo -e "${YELLOW}Vertex密码: 密码文件未生成，请登录后自行设置，或查看容器日志${NC}"
            log_message "${YELLOW}Vertex密码文件未生成${NC}"
        fi
        # rm -f "$compose_file" &>/dev/null # Remove temp compose file, no need as it's downloaded to app dir
        cd "$current_dir" &>/dev/null
        return 0
    else
        log_message "${RED}Vertex Docker安装失败，详情请查看日志：$LOG_DIR/pttools.log${NC}"
        echo -e "${RED}Vertex Docker安装失败，详情请查看日志：$LOG_DIR/pttools.log${NC}"
        rm -f "$compose_file" &>/dev/null # Remove temp compose file on failure
        cd "$current_dir" &>/dev/null
        return 1
    fi
}

# 安装Vertex + qBittorrent 4.3.8
install_qb438_vt() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}正在安装 Vertex + qBittorrent 4.3.8${NC}"
    echo -e "${CYAN}================================================${NC}"
    log_message "${CYAN}正在安装 Vertex + qBittorrent 4.3.8${NC}"
    echo
    echo -e "${YELLOW}此功能将先安装Vertex，然后安装qBittorrent 4.3.8${NC}"
    echo -e "${YELLOW}qBittorrent 4.3.8 作者：iniwex5${NC}"
    echo

    echo -e "${BLUE}Vertex安装方式选择：${NC}"
    echo "1. Docker方式（推荐）"
    echo "2. 原脚本方式"
    read -p "请选择 [1-2, 默认: 1]: " vertex_choice
    vertex_choice=${vertex_choice:-1}

    local vertex_install_type=""
    if [[ "$vertex_choice" == "1" ]]; then
        if ! ensure_docker_installed; then
            # ensure_docker_installed 已经处理了返回主菜单的提示和read -n 1
            return
        fi
        echo -e "${GREEN}选择：Docker方式安装Vertex${NC}"
        vertex_install_type="docker"
    else
        echo -e "${GREEN}选择：原脚本方式安装Vertex${NC}"
        vertex_install_type="script"
    fi

    echo
    echo -e "${BLUE}qBittorrent 4.3.8 安装参数配置：${NC}"
    echo

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
    echo -e "${WHITE}Vertex: $([ "$vertex_install_type" == "docker" ] && echo "Docker方式安装 (端口3333)" || echo "原脚本方式安装 (端口3333)")${NC}"
    echo -e "${WHITE}qBittorrent 4.3.8:${NC}"
    echo -e "${WHITE}  - 用户名: ${username}${NC}"
    echo -e "${WHITE}  - 密码: ${password}${NC}"
    echo -e "${WHITE}  - Web端口: ${web_port}${NC}"
    echo -e "${WHITE}  - BT端口: ${bt_port}${NC}"
    echo
    log_message "安装Vertex + qBittorrent 4.3.8配置: Vertex方式=$vertex_install_type, qB用户名=$username, 密码=$password, Web端口=$web_port, BT端口=$bt_port"

    read -p "确认安装？[Y/n]: " confirm
    confirm=${confirm:-Y}

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_message "${YELLOW}安装已取消${NC}"
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi

    echo -e "${YELLOW}步骤1: 正在安装Vertex...${NC}"
    log_message "${YELLOW}步骤1: 正在安装Vertex...${NC}"

    local vertex_install_success=false
    if [ "$vertex_install_type" == "docker" ]; then
        if install_vertex_docker; then
            log_message "${GREEN}Vertex Docker安装成功${NC}"
            echo -e "${GREEN}Vertex Docker安装成功${NC}"
            vertex_install_success=true
        else
            log_message "${RED}Vertex Docker安装失败，终止安装${NC}"
            echo -e "${RED}Vertex Docker安装失败，终止安装${NC}"
        fi
    else
        echo -e "${YELLOW}使用原脚本方式安装Vertex...${NC}"
        log_message "${YELLOW}使用原脚本方式安装Vertex...${NC}"
        local jerry_script="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh)"
        log_message "执行命令: $jerry_script -u admin -p adminadmin -v"
        echo -e "${BLUE}执行命令: $jerry_script -u admin -p adminadmin -v${NC}"

        if eval "$jerry_script -u admin -p adminadmin -v" &>> "$LOG_DIR/pttools.log"; then
            log_message "${GREEN}Vertex原脚本安装成功${NC}"
            echo -e "${GREEN}Vertex原脚本安装成功${NC}"
            echo -e "${GREEN}Vertex访问地址: http://你的服务器IP:3333${NC}"
            echo -e "${GREEN}Vertex用户名: admin${NC}"
            echo -e "${GREEN}Vertex密码: adminadmin${NC}"
            vertex_install_success=true
        else
            log_message "${RED}Vertex原脚本安装失败，终止安装${NC}"
            echo -e "${RED}Vertex原脚本安装失败，终止安装${NC}"
        fi
    fi

    if [[ "$vertex_install_success" == false ]]; then
        echo -e "${YELLOW}按任意键返回主菜单...${NC}"
        read -n 1
        return
    fi

    echo
    echo -e "${YELLOW}步骤2: 正在安装qBittorrent 4.3.8...${NC}"
    log_message "${YELLOW}步骤2: 正在安装qBittorrent 4.3.8...${NC}"
    local qb438_install_cmd="bash <(wget -qO- https://raw.githubusercontent.com/iniwex5/tools/refs/heads/main/NC_QB438.sh) \"$username\" \"$password\" \"$web_port\" \"$bt_port\""
    log_message "执行命令: $qb438_install_cmd"
    echo -e "${BLUE}执行命令: $qb438_install_cmd${NC}"
    echo

    if eval "$qb438_install_cmd" &>> "$LOG_DIR/pttools.log"; then
        echo
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}Vertex + qBittorrent 4.3.8 安装完成！${NC}"
        echo -e "${GREEN}================================================${NC}"
        if [ "$vertex_install_type" == "docker" ]; then
            echo -e "${GREEN}Vertex访问地址: http://你的服务器IP:3333${NC}"
            echo -e "${GREEN}Vertex用户名: admin${NC}"
            log_message "Vertex (Docker)访问地址: http://你的服务器IP:3333, 用户名: admin"
            local vertex_password_file="$DOCKER_DIR/vertex/config/data/password"
            if [ -f "$vertex_password_file" ]; then
                local vertex_password=$(cat "$vertex_password_file" 2>/dev/null)
                if [ -n "$vertex_password" ]; then
                    echo -e "${GREEN}Vertex密码: ${vertex_password}${NC}"
                    log_message "Vertex密码: ${vertex_password}"
                else
                    echo -e "${YELLOW}Vertex密码: 密码文件为空，请执行 cat $vertex_password_file 查看${NC}"
                    log_message "${YELLOW}Vertex密码文件为空${NC}"
                fi
            else
                echo -e "${YELLOW}Vertex密码: 密码文件未生成，请登录后自行设置，或查看容器日志${NC}"
                log_message "${YELLOW}Vertex密码文件未生成${NC}"
            fi
        else
            echo -e "${GREEN}Vertex访问地址: http://你的服务器IP:3333${NC}"
            echo -e "${GREEN}Vertex用户名: admin${NC}"
            echo -e "${GREEN}Vertex密码: adminadmin${NC}"
            log_message "Vertex (Script)访问地址: http://你的服务器IP:3333, 用户名: admin, 密码: adminadmin"
        fi
        echo -e "${GREEN}qBittorrent访问地址: http://你的服务器IP:${web_port}${NC}"
        echo -e "${GREEN}qBittorrent用户名: ${username}${NC}"
        echo -e "${GREEN}qBittorrent密码: ${password}${NC}"
        echo -e "${GREEN}qBittorrent BT端口: ${bt_port}${NC}"
        echo -e "${GREEN}================================================${NC}"
        log_message "${GREEN}Vertex + qBittorrent 4.3.8 安装成功${NC}"
    else
        echo
        echo -e "${RED}================================================${NC}"
        echo -e "${RED}qBittorrent 4.3.8 安装失败！${NC}"
        echo -e "${RED}Vertex已安装成功，但qBittorrent安装失败。请检查日志：$LOG_DIR/pttools.log${NC}"
        echo -e "${RED}================================================${NC}"
        log_message "${RED}qBittorrent 4.3.8 安装失败${NC}"
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
    log_message "${CYAN}正在安装 Vertex + qBittorrent 4.3.9${NC}"
    echo
    echo -e "${YELLOW}此功能将安装Vertex和qBittorrent 4.3.9${NC}"
    echo -e "${YELLOW}qBittorrent 4.3.9 作者：jerry048${NC}"
    echo

    echo -e "${BLUE}Vertex安装方式选择：${NC}"
    echo "1. Docker方式（推荐）"
    echo "2. 原脚本方式"
    read -p "请选择 [1-2, default: 1]: " vertex_choice
    vertex_choice=${vertex_choice:-1}

    local vertex_install_type=""
    if [[ "$vertex_choice" == "1" ]]; then
        if ! ensure_docker_installed; then
            # ensure_docker_installed 已经处理了返回主菜单的提示和read -n 1
            return
        fi
        echo -e "${GREEN}选择：Docker方式安装Vertex${NC}"
        vertex_install_type="docker"
    else
        echo -e "${GREEN}选择：原脚本方式安装Vertex${NC}"
        vertex_install_type="script"
    fi

    echo
    echo -e "${BLUE}qBittorrent 4.3.9 安装参数配置：${NC}"
    echo

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
    echo -e "${WHITE}Vertex: $([ "$vertex_install_type" == "docker" ] && echo "Docker方式安装 (端口3333)" || echo "原脚本方式安装 (端口3333)")${NC}"
    echo -e "${WHITE}qBittorrent 4.3.9:${NC}"
    echo -e "${WHITE}  - 用户名: ${username}${NC}"
    echo -e "${WHITE}  - 密码: ${password}${NC}"
    echo -e "${WHITE}  - 缓存大小: ${cache_size} MiB${NC}"
    echo -e "${WHITE}  - libtorrent版本: ${libtorrent_ver}${NC}"
    echo -e "${WHITE}  - autobrr: $([[ $install_autobrr =~ ^[Yy]$ ]] && echo "是" || echo "否")${NC}"
    echo -e "${WHITE}  - autoremove-torrents: $([[ $install_autoremove =~ ^[Yy]$ ]] && echo "是" || echo "否")${NC}"
    echo -e "${WHITE}  - BBRx: $([[ $enable_bbrx =~ ^[Yy]$ ]] && echo "是" || echo "否")${NC}"
    echo
    log_message "安装Vertex + qBittorrent 4.3.9配置: Vertex方式=$vertex_install_type, qB用户名=$username, 密码=$password, 缓存=$cache_size, libtorrent=$libtorrent_ver, autobrr=$install_autobrr, autoremove=$install_autoremove, BBRx=$enable_bbrx"

    read -p "确认安装？[Y/n]: " confirm
    confirm=${confirm:-Y}

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_message "${YELLOW}安装已取消${NC}"
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi

    local vertex_install_success=false
    if [ "$vertex_install_type" == "docker" ]; then
        echo -e "${YELLOW}步骤1: 正在使用Docker安装Vertex...${NC}"
        log_message "${YELLOW}步骤1: 正在使用Docker安装Vertex...${NC}"
        if install_vertex_docker; then
            log_message "${GREEN}Vertex Docker安装成功${NC}"
            echo -e "${GREEN}Vertex Docker安装成功${NC}"
            vertex_install_success=true
        else
            log_message "${RED}Vertex Docker安装失败，终止安装${NC}"
            echo -e "${RED}Vertex Docker安装失败，终止安装${NC}"
        fi
    else
        echo -e "${YELLOW}使用原脚本方式安装Vertex...${NC}"
        log_message "${YELLOW}使用原脚本方式安装Vertex...${NC}"
        local jerry_script="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh)"
        log_message "执行命令: $jerry_script -u admin -p adminadmin -v"
        echo -e "${BLUE}执行命令: $jerry_script -u admin -p adminadmin -v${NC}"

        if eval "$jerry_script -u admin -p adminadmin -v" &>> "$LOG_DIR/pttools.log"; then
            log_message "${GREEN}Vertex原脚本安装成功${NC}"
            echo -e "${GREEN}Vertex原脚本安装成功${NC}"
            echo -e "${GREEN}Vertex访问地址: http://你的服务器IP:3333${NC}"
            echo -e "${GREEN}Vertex用户名: admin${NC}"
            echo -e "${GREEN}Vertex密码: adminadmin${NC}"
            vertex_install_success=true
        else
            log_message "${RED}Vertex原脚本安装失败，终止安装${NC}"
            echo -e "${RED}Vertex原脚本安装失败，终止安装${NC}"
        fi
    fi

    if [[ "$vertex_install_success" == false ]]; then
        echo -e "${YELLOW}按任意键返回主菜单...${NC}"
        read -n 1
        return
    fi

    echo
    echo -e "${YELLOW}步骤2: 正在安装qBittorrent 4.3.9...${NC}"
    log_message "${YELLOW}步骤2: 在安装qBittorrent 4.3.9...${NC}"

    local qb439_install_cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u \"$username\" -p \"$password\" -c \"$cache_size\" -q 4.3.9 -l \"$libtorrent_ver\""
    [[ -n "$autobrr_flag" ]] && qb439_install_cmd="$qb439_install_cmd $autobrr_flag"
    [[ -n "$autoremove_flag" ]] && qb439_install_cmd="$qb439_install_cmd $autoremove_flag"
    [[ -n "$bbrx_flag" ]] && qb439_install_cmd="$qb439_install_cmd $bbrx_flag"

    log_message "执行命令: $qb439_install_cmd"
    echo -e "${BLUE}命令: $qb439_install_cmd${NC}"
    echo

    if eval "$qb439_install_cmd" &>> "$LOG_DIR/pttools.log"; then
        echo
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}Vertex + qBittorrent 4.3.9 安装完成！${NC}"
        echo -e "${GREEN}================================================${NC}"
        if [ "$vertex_install_type" == "docker" ]; then
            echo -e "${GREEN}Vertex访问地址: http://你的服务器IP:3333${NC}"
            echo -e "${GREEN}Vertex用户名: admin${NC}"
            log_message "Vertex (Docker)访问地址: http://你的服务器IP:3333, 用户名: admin"
            local vertex_password_file="$DOCKER_DIR/vertex/config/data/password"
            if [ -f "$vertex_password_file" ]; then
                local vertex_password=$(cat "$vertex_password_file" 2>/dev/null)
                if [ -n "$vertex_password" ]; then
                    echo -e "${GREEN}Vertex密码: ${vertex_password}${NC}"
                    log_message "Vertex密码: ${vertex_password}"
                else
                    echo -e "${YELLOW}Vertex密码: 密码文件为空，请执行 cat $vertex_password_file 查看${NC}"
                    log_message "${YELLOW}Vertex密码文件为空${NC}"
                fi
            else
                echo -e "${YELLOW}Vertex密码: 密码文件未生成，请登录后自行设置，或查看容器日志${NC}"
                log_message "${YELLOW}Vertex密码文件未生成${NC}"
            fi
        else
            echo -e "${GREEN}Vertex访问地址: http://你的服务器IP:3333${NC}"
            echo -e "${GREEN}Vertex用户名: admin${NC}"
            echo -e "${GREEN}Vertex密码: adminadmin${NC}"
            log_message "Vertex (Script)访问地址: http://你的服务器IP:3333, 用户名: admin, 密码: adminadmin"
        fi
        echo -e "${GREEN}qBittorrent用户名: ${username}${NC}"
        echo -e "${GREEN}qBittorrent密码: ${password}${NC}"
        echo -e "${GREEN}qBittorrent缓存大小: ${cache_size} MiB${NC}"
        echo -e "${GREEN}================================================${NC}"
        log_message "${GREEN}Vertex + qBittorrent 4.3.9 安装成功${NC}"
    else
        echo
        echo -e "${RED}================================================${NC}"
        echo -e "${RED}qBittorrent 4.3.9 安装失败！${NC}"
        echo -e "${RED}Vertex已安装成功，但qBittorrent安装失败。请检查日志：$LOG_DIR/pttools.log${NC}"
        echo -e "${RED}================================================${NC}"
        log_message "${RED}qBittorrent 4.3.9 安装失败${NC}"
    fi

    echo
    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
    read -n 1
}

# 安装全套Docker应用
install_full_docker_suite() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}安装全套Docker应用${NC}"
    echo -e "${CYAN}qBittorrent 4.6.7 + Transmission 4.0.5 + Emby + IYUUPlus + MoviePilot${NC}"
    echo -e "${CYAN}================================================${NC}"
    log_message "${CYAN}尝试安装全套Docker应用${NC}"
    echo

    if ! ensure_docker_installed; then
        # ensure_docker_installed 已经处理了返回主菜单的提示和read -n 1
        return
    fi

    echo -e "${BLUE}应用配置说明：${NC}"
    echo -e "${WHITE}本功能将安装以下应用：${NC}"
    echo -e "${WHITE}• qBittorrent 4.6.7 (端口: 8080)${NC}"
    echo -e "${WHITE}• Transmission 4.0.5 (端口: 9091, 用户名: admin, 密码: adminadmin)${NC}"
    echo -e "${WHITE}• Emby (端口: 8096)${NC}"
    echo -e "${WHITE}• IYUUPlus (端口: 8780)${NC}"
    echo -e "${WHITE}• MoviePilot (端口: 3000)${NC}"
    echo
    echo -e "${YELLOW}注意：所有应用将使用Docker安装，数据目录为 ${DOCKER_DIR}，下载目录为 ${DOWNLOADS_DIR}${NC}"
    echo

    read -p "确认安装全套Docker应用？[Y/n]: " confirm
    confirm=${confirm:-Y}

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_message "${YELLOW}安装已取消${NC}"
        echo -e "${YELLOW}安装已取消${NC}"
        return
    fi

    log_message "${YELLOW}全套Docker应用安装功能开发中...${NC}"
    echo -e "${YELLOW}全套Docker应用安装功能开发中...${NC}"
    echo -e "${YELLOW}当前建议使用第6项“PT Docker应用”单独安装各个应用。${NC}"
    echo -e "${YELLOW}按任意键返回主菜单...${NC}"
    read -n 1
}

# PT Docker应用管理 (调用外部脚本)
pt_docker_apps() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}PT Docker应用 - 分类选择安装${NC}"
    echo -e "${CYAN}================================================${NC}"
    log_message "${CYAN}进入PT Docker应用管理菜单${NC}"
    echo

    if ! ensure_docker_installed; then
        # ensure_docker_installed 已经处理了返回主菜单的提示和read -n 1
        return
    fi

    local ptdocker_script_path="./configs/ptdocker.sh" # 定义本地脚本路径
    local ptdocker_url="$GITHUB_RAW/configs/ptdocker.sh"

    # --- 改进的网络连通性预检 ptdocker.sh 下载 (直接尝试下载，而不是HEAD请求) ---
    echo -e "${YELLOW}正在尝试下载PT Docker应用管理脚本: ${ptdocker_url}...${NC}"
    log_message "${YELLOW}正在尝试下载PT Docker应用管理脚本: ${ptdocker_url}${NC}"
    
    mkdir -p "$(dirname "$0")/configs" &>> "$PTTOOLS_LOG_FILE" # 确保 configs 目录存在

    local download_output=""
    # 使用 curl -fsSL --retry 3 --retry-delay 5 尝试下载，如果失败则输出错误信息
    if ! download_output=$(curl -fsSL --retry 3 --retry-delay 5 "$ptdocker_url" -o "$ptdocker_script_path" 2>&1); then
        log_message "${RED}PT Docker应用管理脚本下载失败。URL: ${ptdocker_url}。输出：\n$download_output${NC}"
        echo -e "${RED}PT Docker应用管理脚本下载失败！这可能是由于网络不稳定、GitHub访问受限或临时问题。${NC}"
        echo -e "${WHITE}请尝试：${NC}"
        echo -e "${WHITE}1. 检查您的VPS网络连接或DNS设置。${NC}"
        echo -e "${WHITE}2. 稍后重试，GitHub可能存在临时波动。${NC}"
        echo -e "${WHITE}3. 如果您的VPS位于中国大陆，可能需要配置代理来访问GitHub Raw。${NC}"
        echo -e "${WHITE}   详细日志请查看：${PTTOOLS_LOG_FILE}${NC}"
        echo
        echo -e "${YELLOW}按任意键返回主菜单...${NC}"
        read -n 1
        rm -f "$ptdocker_script_path" &>/dev/null # 清理未完成的下载文件
        return # 直接返回主菜单
    else
        log_message "${GREEN}PT Docker应用管理脚本下载成功。输出：\n$download_output${NC}"
        echo -e "${GREEN}PT Docker应用管理脚本下载成功。${NC}"
    fi

    chmod +x "$ptdocker_script_path"
    echo -e "${YELLOW}正在启动PT Docker应用管理...${NC}"
    log_message "${YELLOW}正在启动PT Docker应用管理...${NC}"
    echo

    # 执行ptdocker.sh，并传递DOCKER_DIR, DOWNLOADS_DIR, LOG_DIR, GITHUB_RAW
    bash "$ptdocker_script_path" "$DOCKER_DIR" "$DOWNLOADS_DIR" "$LOG_DIR" "$GITHUB_RAW"

    # ptdocker.sh 脚本会处理其内部的循环和返回，此处无需额外操作
}

# 移除 fallback_pt_docker_menu 函数，因为不再需要备用方案
# 移除 install_single_fallback_docker_app 函数，因为不再需要备用方案


# 卸载应用
uninstall_apps() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}卸载应用${NC}"
    echo -e "${CYAN}================================================${NC}"
    log_message "${CYAN}进入卸载应用菜单${NC}"
    echo

    echo -e "${YELLOW}正在检测已安装的应用...${NC}"
    log_message "${YELLOW}正在检测已安装的应用...${NC}"
    echo

    local docker_apps_found=()
    if command -v docker &> /dev/null; then
        echo -e "${BLUE}检测到的Docker容器：${NC}"
        local all_containers=$(docker ps -a --format "{{.Names}}")
        local relevant_containers=("vertex" "qbittorrent" "transmission" "iyuuplus" "moviepilot" "emby" "jellyfin" "plex" "filebrowser" "watchtower" "netdata" "cookiecloud" "homepage" "sonarr" "radarr" "lidarr" "prowlarr" "autobrr" "bazarr" "cross-seed" "reseedpuppy" "flexget" "jackett" "clouddrive2" "frps" "frpc" "lucky" "sun-panel" "qiandao" "metatube" "byte-muse" "ikaros" "mdcng" "calibre-web" "komga" "music-tag-web" "audiobookshelf" "navidrome" "pt-nexus" "aria2") # Added aria2

        local found_any_docker=false
        for app_name in "${relevant_containers[@]}"; do
            if echo "$all_containers" | grep -q "^${app_name}$"; then
                local status=$(docker ps --filter "name=^${app_name}$" --format "{{.Status}}" 2>/dev/null || echo "Exited")
                if [[ "$status" =~ "Up" ]]; then
                    echo -e "${GREEN}  ✓ ${app_name} (运行中)${NC}"
                else
                    echo -e "${YELLOW}  ✓ ${app_name} (已停止)${NC}"
                fi
                docker_apps_found+=("$app_name")
                found_any_docker=true
            fi
        done

        if [ "$found_any_docker" = false ]; then
            echo -e "${GRAY}  未检测到相关Docker应用${NC}"
        fi
    else
        echo -e "${GRAY}Docker未安装，跳过Docker应用检测${NC}"
    fi

    echo
    echo -e "${BLUE}原生安装的应用：${NC}"
    local native_apps_found=false
    if systemctl is-active --quiet qbittorrent || pgrep -f "qbittorrent" >/dev/null; then
        echo -e "${GREEN}  ✓ qBittorrent (原生安装)${NC}"
        native_apps_found=true
    fi
    # 简单的Vertex原生安装检测
    if systemctl is-active --quiet vertex || pgrep -f "vertex" >/dev/null; then
        vertex_detected=true
        echo -e "${GREEN}  ✓ Vertex (原生安装)${NC}"
    else
        echo -e "${GRAY}  未检测到原生安装的Vertex${NC}"
    fi

    echo
    echo -e "${GREEN}请选择卸载类型：${NC}"
    echo "1. 卸载Docker应用"
    echo "2. 卸载原生安装应用 (qBittorrent/Vertex等)"
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
            log_message "${RED}无效选择: $uninstall_choice${NC}"
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
    log_message "${CYAN}进入卸载Docker应用菜单${NC}"
    echo

    if ! command -v docker &> /dev/null; then
        log_message "${RED}Docker未安装，无法卸载Docker应用${NC}"
        echo -e "${RED}Docker未安装，无法卸载Docker应用${NC}"
        echo -e "${YELLOW}按任意键返回...${NC}"
        read -n 1
        return
    fi

    local containers_to_display=()
    local all_docker_containers=$(docker ps -a --format "{{.Names}}")
    local relevant_containers=("vertex" "qbittorrent" "transmission" "iyuuplus" "moviepilot" "emby" "jellyfin" "plex" "filebrowser" "watchtower" "netdata" "cookiecloud" "homepage" "sonarr" "radarr" "lidarr" "prowlarr" "autobrr" "bazarr" "cross-seed" "reseedpuppy" "flexget" "jackett" "clouddrive2" "frps" "frpc" "lucky" "sun-panel" "qiandao" "metatube" "byte-muse" "ikaros" "mdcng" "calibre-web" "komga" "music-tag-web" "audiobookshelf" "navidrome" "pt-nexus" "aria2") # Added aria2

    for app_name in "${relevant_containers[@]}"; do
        if echo "$all_containers" | grep -q "^${app_name}$"; then
            containers_to_display+=("$app_name")
        fi
    done

    if [ ${#containers_to_display[@]} -eq 0 ]; then
        log_message "${YELLOW}未发现PTtools相关Docker应用${NC}"
        echo -e "${YELLOW}未发现PTtools相关Docker应用${NC}"
        echo -e "${YELLOW}按任意键返回...${NC}"
        read -n 1
        return
    fi

    echo -e "${GREEN}发现以下Docker应用：${NC}"
    local current_index=1
    for container in "${containers_to_display[@]}"; do
        local status=$(docker ps --filter "name=^${container}$" --format "{{.Status}}" 2>/dev/null || echo "Exited")
        if [[ "$status" =~ "Up" ]]; then
            echo -e "${GREEN}  $((current_index)). ${container} (运行中)${NC}"
        else
            echo -e "${YELLOW}  $((current_index)). ${container} (已停止)${NC}"
        fi
        current_index=$((current_index+1))
    done
    echo -e "${WHITE}  ${current_index}. 全部卸载${NC}"
    echo -e "${WHITE}  $((current_index+1)). 返回上级菜单${NC}"
    echo
    echo -e "${YELLOW}提示: 可以输入多个序号，用空格分隔，例如 '1 3' 卸载多个应用。${NC}"

    read -p "请选择要卸载的应用: " docker_choices

    # 分割选择为数组
    read -ra selected_apps_indices <<< "$docker_choices"

    for choice in "${selected_apps_indices[@]}"; do
        if [[ "$choice" -eq "$current_index" ]]; then
            # 全部卸载
            log_message "${RED}警告：用户选择卸载所有Docker应用！${NC}"
            echo -e "${RED}警告：这将卸载所有PTtools检测到的Docker应用！${NC}"
            read -p "确认卸载所有应用？[y/N]: " confirm_all
            if [[ $confirm_all =~ ^[Yy]$ ]]; then
                for container_name in "${containers_to_display[@]}"; do
                    uninstall_single_docker_app "$container_name"
                done
                break # 全部卸载后退出循环
            else
                log_message "${YELLOW}已取消全部卸载${NC}"
                echo -e "${YELLOW}已取消全部卸载${NC}"
            fi
        elif [[ "$choice" -eq "$((current_index+1))" ]]; then
            # 返回上级菜单
            log_message "${BLUE}用户选择返回上级菜单${NC}"
            return
        elif [[ "$choice" -ge 1 && "$choice" -le ${#containers_to_display[@]} ]]; then
            # 卸载单个应用
            local selected_container="${containers_to_display[$((choice-1))]}"
            uninstall_single_docker_app "$selected_container"
        else
            log_message "${RED}无效选择: $choice${NC}"
            echo -e "${RED}无效选择: $choice${NC}"
        fi
    done

    echo -e "${YELLOW}按任意键返回...${NC}"
    read -n 1
}

# 卸载单个Docker应用
uninstall_single_docker_app() {
    local container_name="$1"
    echo -e "${YELLOW}正在卸载 Docker 应用: ${container_name}...${NC}"
    log_message "${YELLOW}正在卸载 Docker 应用: ${container_name}...${NC}"

    if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$" &>> "$LOG_DIR/pttools.log"; then
        echo -e "${YELLOW}停止容器 ${container_name}...${NC}"
        docker stop "$container_name" &>> "$LOG_DIR/pttools.log"
    fi

    if docker ps -a --format "table {{.Names}}" | grep -q "^${container_name}$" &>> "$LOG_DIR/pttools.log"; then
        echo -e "${YELLOW}删除容器 ${container_name}...${NC}"
        docker rm "$container_name" &>> "$LOG_DIR/pttools.log"
    fi

    echo -e "${YELLOW}是否同时删除数据目录 ${DOCKER_DIR}/${container_name} 和 ${DOWNLOADS_DIR} 中的相关数据？[y/N]: ${NC}"
    read -r delete_data_choice
    delete_data_choice=${delete_data_choice:-N}

    if [[ $delete_data_choice =~ ^[Yy]$ ]]; then
        if [ -d "${DOCKER_DIR}/${container_name}" ]; then
            log_message "${YELLOW}删除数据目录 ${DOCKER_DIR}/${container_name}...${NC}"
            echo -e "${YELLOW}删除数据目录 ${DOCKER_DIR}/${container_name}...${NC}"
            rm -rf "${DOCKER_DIR}/${container_name}" &>> "$LOG_DIR/pttools.log"
            echo -e "${GREEN}数据目录已删除${NC}"
        fi
        # 对于 /opt/downloads，很难判断哪些是特定应用的数据，所以这里仅作提示，不自动删除
        echo -e "${BLUE}注意：${DOWNLOADS_DIR} 目录通常包含多个应用的下载数据，不会自动删除。请手动检查并清理。${NC}"
        log_message "注意：$DOWNLOADS_DIR 目录不会自动删除，需手动检查并清理。"
    else
        log_message "${BLUE}数据目录已保留：${DOCKER_DIR}/${container_name}${NC}"
        echo -e "${BLUE}数据目录已保留：${DOCKER_DIR}/${container_name}${NC}"
    fi

    log_message "${GREEN}${container_name} 卸载完成${NC}"
    echo -e "${GREEN}${container_name} 卸载完成${NC}"
}

# 卸载原生脚本应用
uninstall_script_apps() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}卸载原生安装应用${NC}"
    echo -e "${CYAN}================================================${NC}"
    log_message "${CYAN}进入卸载原生脚本应用菜单${NC}"
    echo

    echo -e "${YELLOW}正在检测原生安装的qBittorrent/Vertex...${NC}"
    log_message "${YELLOW}正在检测原生安装的qBittorrent/Vertex...${NC}"

    local qb_detected=false
    local vertex_detected=false

    # 检测qBittorrent
    if systemctl list-units --type=service --all | grep -qi "qbittorrent" || pgrep -f "qbittorrent" >/dev/null; then
        qb_detected=true
        echo -e "${GREEN}  ✓ 检测到原生安装的qBittorrent${NC}"
    else
        echo -e "${GRAY}  未检测到原生安装的qBittorrent${NC}"
    fi

    # 检测Vertex (jerry048脚本安装的版本)
    if systemctl list-units --type=service --all | grep -qi "vertex" || pgrep -f "vertex" >/dev/null; then
        vertex_detected=true
        echo -e "${GREEN}  ✓ 检测到原生安装的Vertex${NC}"
    else
        echo -e "${GRAY}  未检测到原生安装的Vertex${NC}"
    fi

    echo
    echo -e "${GREEN}请选择要卸载的原生应用：${NC}"
    local menu_idx=1
    if [[ "$qb_detected" == true ]]; then
        echo -e "${WHITE}  ${menu_idx}. 卸载 qBittorrent (原生)${NC}"
        menu_idx=$((menu_idx+1))
    fi
    if [[ "$vertex_detected" == true ]]; then
        echo -e "${WHITE}  ${menu_idx}. 卸载 Vertex (原生)${NC}"
        menu_idx=$((menu_idx+1))
    fi
    echo -e "${WHITE}  ${menu_idx}. 手动卸载指导 (适用于其他Jerry048脚本安装组件)${NC}"
    echo -e "${WHITE}  $((menu_idx+1)). 返回上级菜单${NC}"

    read -p "请选择: " native_choice

    local current_option=1
    if [[ "$qb_detected" == true && "$native_choice" -eq "$current_option" ]]; then
        uninstall_qbittorrent_auto
    elif [[ "$qb_detected" == true ]]; then
        current_option=$((current_option+1))
        if [[ "$vertex_detected" == true && "$native_choice" -eq "$current_option" ]]; then
            uninstall_vertex_auto_script
        elif [[ "$vertex_detected" == true ]]; then
            current_option=$((current_option+1))
            if [[ "$native_choice" -eq "$current_option" ]]; then
                show_manual_uninstall_guide
            elif [[ "$native_choice" -eq "$((current_option+1))" ]]; then
                return
            else
                log_message "${RED}无效选择: $native_choice${NC}"
                echo -e "${RED}无效选择${NC}"
            fi
        elif [[ "$native_choice" -eq "$current_option" ]]; then
            show_manual_uninstall_guide
        elif [[ "$native_choice" -eq "$((current_option+1))" ]]; then
            return
        else
            log_message "${RED}无效选择: $native_choice${NC}"
            echo -e "${RED}无效选择${NC}"
        fi
    elif [[ "$vertex_detected" == true && "$native_choice" -eq "$current_option" ]]; then
        uninstall_vertex_auto_script
    elif [[ "$vertex_detected" == true ]]; then
        current_option=$((current_option+1))
        if [[ "$native_choice" -eq "$current_option" ]]; then
            show_manual_uninstall_guide
        elif [[ "$native_choice" -eq "$((current_option+1))" ]]; then
            return
        else
            log_message "${RED}无效选择: $native_choice${NC}"
            echo -e "${RED}无效选择${NC}"
        fi
    elif [[ "$native_choice" -eq "$current_option" ]]; then
        show_manual_uninstall_guide
    elif [[ "$native_choice" -eq "$((current_option+1))" ]]; then
        return
    else
        log_message "${RED}无效选择: $native_choice${NC}"
        echo -e "${RED}无效选择${NC}"
    fi

    echo -e "${YELLOW}按任意键返回...${NC}"
    read -n 1
}

# 自动卸载qBittorrent (原生安装)
uninstall_qbittorrent_auto() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}自动卸载qBittorrent (原生安装)${NC}"
    echo -e "${CYAN}================================================${NC}"
    log_message "${CYAN}开始自动卸载qBittorrent (原生安装)${NC}"
    echo

    echo -e "${RED}警告：此操作将尝试完全删除qBittorrent及其配置！${NC}"
    echo -e "${YELLOW}包括：${NC}"
    echo -e "${WHITE}• 停止所有qBittorrent服务和进程${NC}"
    echo -e "${WHITE}• 删除systemd服务文件${NC}"
    echo -e "${WHITE}• 删除程序文件${NC}"
    echo -e "${WHITE}• 删除配置文件和数据${NC}"
    echo -e "${WHITE}• 清理用户和组${NC}"
    echo

    read -p "确认卸载qBittorrent？[y/N]: " confirm_uninstall
    if [[ ! $confirm_uninstall =~ ^[Yy]$ ]]; then
        log_message "${YELLOW}卸载已取消${NC}"
        echo -e "${YELLOW}卸载已取消${NC}"
        return
    fi

    echo -e "${YELLOW}开始彻底卸载qBittorrent...${NC}"
    log_message "${YELLOW}开始彻底卸载qBittorrent...${NC}"

    force_stop_all_qbittorrent
    force_remove_all_services "qbittorrent"
    remove_qbittorrent_binaries
    remove_qbittorrent_configs
    cleanup_qbittorrent_user
    cleanup_qbittorrent_misc
    final_cleanup

    log_message "${GREEN}qBittorrent卸载完成！${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}qBittorrent卸载完成！${NC}"
    echo -e "${GREEN}================================================${NC}"

    verify_qbittorrent_removal
}

# 自动卸载Vertex (原生安装) - 基于jerry048脚本的卸载逻辑
uninstall_vertex_auto_script() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}自动卸载Vertex (原生安装)${NC}"
    echo -e "${CYAN}================================================${NC}"
    log_message "${CYAN}开始自动卸载Vertex (原生安装)${NC}"
    echo

    echo -e "${RED}警告：此操作将尝试删除原生安装的Vertex及其相关文件！${NC}"
    echo -e "${YELLOW}包括：${NC}"
    echo -e "${WHITE}• 停止Vertex服务和进程${NC}"
    echo -e "${WHITE}• 删除systemd服务文件${NC}"
    echo -e "${WHITE}• 删除程序文件和数据${NC}"
    echo

    read -p "确认卸载Vertex？[y/N]: " confirm_uninstall
    if [[ ! $confirm_uninstall =~ ^[Yy]$ ]]; then
        log_message "${YELLOW}卸载已取消${NC}"
        echo -e "${YELLOW}卸载已取消${NC}"
        return
    fi

    echo -e "${YELLOW}尝试通过Jerry048的Install.sh脚本卸载Vertex...${NC}"
    log_message "${YELLOW}尝试通过Jerry048的Install.sh脚本卸载Vertex...${NC}"
    local uninstall_cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u admin -p adminadmin -U -v"
    log_message "执行命令: $uninstall_cmd"
    echo -e "${BLUE}命令: $uninstall_cmd${NC}"

    if eval "$uninstall_cmd" &>> "$LOG_DIR/pttools.log"; then
        log_message "${GREEN}Vertex卸载命令执行成功。${NC}"
        echo -e "${GREEN}Vertex卸载命令执行成功。${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}Vertex卸载完成！${NC}"
        echo -e "${GREEN}================================================${NC}"
    else
        log_message "${RED}Vertex卸载命令执行失败。可能需要手动清理。${NC}"
        echo -e "${RED}Vertex卸载命令执行失败。可能需要手动清理。${NC}"
        show_manual_uninstall_guide_vertex
    fi
}

# 暴力停止所有qBittorrent相关内容
force_stop_all_qbittorrent() {
    echo -e "${YELLOW}正在暴力停止所有qBittorrent相关内容...${NC}"
    log_message "${YELLOW}正在暴力停止所有qBittorrent相关内容...${NC}"

    echo -e "${YELLOW}停止所有qBittorrent服务...${NC}"
    systemctl list-units --type=service --all | grep -i qbittorrent | awk '{print $1}' | while read -r service; do
        log_message "${GRAY}  停止服务: $service${NC}"
        systemctl stop "$service" 2>/dev/null &>> "$LOG_DIR/pttools.log"
        systemctl disable "$service" 2>/dev/null &>> "$LOG_DIR/pttools.log"
        systemctl mask "$service" 2>/dev/null &>> "$LOG_DIR/pttools.log"
    done

    echo -e "${YELLOW}强制终止所有qBittorrent进程...${NC}"
    pkill -9 -f "qbittorrent" 2>/dev/null &>> "$LOG_DIR/pttools.log"
    pkill -9 "qbittorrent" 2>/dev/null &>> "$LOG_DIR/pttools.log"
    pkill -9 "qbittorrent-nox" 2>/dev/null &>> "$LOG_DIR/pttools.log"
    killall -9 qbittorrent 2>/dev/null &>> "$LOG_DIR/pttools.log"
    killall -9 qbittorrent-nox 2>/dev/null &>> "$LOG_DIR/pttools.log"

    sleep 2

    if pgrep -f "qbittorrent" >/dev/null; then
        log_message "${RED}仍有顽固进程，使用kill -9强制终止...${NC}"
        echo -e "${RED}仍有顽固进程，使用kill -9强制终止...${NC}"
        pgrep -f "qbittorrent" | xargs -r kill -9 2>/dev/null &>> "$LOG_DIR/pttools.log"
    fi
    log_message "${GREEN}所有qBittorrent进程已终止${NC}"
    echo -e "${GREEN}所有qBittorrent进程已终止${NC}"
}

# 彻底删除所有服务文件 (通用函数，接受服务名称模式)
force_remove_all_services() {
    local service_pattern="$1"
    echo -e "${YELLOW}正在彻底删除所有${service_pattern}服务文件...${NC}"
    log_message "${YELLOW}正在彻底删除所有${service_pattern}服务文件...${NC}"

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
            find "$dir" -name "*${service_pattern}*" -type f -delete 2>/dev/null &>> "$LOG_DIR/pttools.log"
            find "$dir" -name "*${service_pattern}*" -type l -delete 2>/dev/null &>> "$LOG_DIR/pttools.log"
            find "$dir" -type d -name "*${service_pattern}*" -exec rm -rf {} + 2>/dev/null &>> "$LOG_DIR/pttools.log"
        fi
    done

    find /home -name ".config" -type d 2>/dev/null | while read -r config_dir; do
        local user_systemd="$config_dir/systemd/user"
        if [[ -d "$user_systemd" ]]; then
            find "$user_systemd" -name "*${service_pattern}*" -delete 2>/dev/null &>> "$LOG_DIR/pttools.log"
        fi
    done

    echo -e "${YELLOW}重置systemd状态...${NC}"
    log_message "${YELLOW}重置systemd状态...${NC}"
    systemctl daemon-reload &>> "$LOG_DIR/pttools.log"
    systemctl reset-failed 2>/dev/null &>> "$LOG_DIR/pttools.log"

    log_message "${GREEN}所有${service_pattern} systemd服务文件已清理${NC}"
    echo -e "${GREEN}所有${service_pattern} systemd服务文件已清理${NC}"
}

# 删除qBittorrent程序文件
remove_qbittorrent_binaries() {
    echo -e "${YELLOW}正在删除qBittorrent程序文件...${NC}"
    log_message "${YELLOW}正在删除qBittorrent程序文件...${NC}"

    local binary_paths=(
        "/usr/local/bin/qbittorrent" "/usr/bin/qbittorrent-nox"
        "/usr/bin/qbittorrent" "/usr/bin/qbittorrent-nox"
        "/opt/qbittorrent" "/usr/local/qbittorrent"
    )

    for path in "${binary_paths[@]}"; do
        if [[ -e "$path" ]]; then
            log_message "${GREEN}删除: $path${NC}"
            echo -e "${GREEN}删除: $path${NC}"
            rm -rf "$path" &>> "$LOG_DIR/pttools.log"
        fi
    done

    find /usr/local/bin /usr/bin -name "*qbittorrent*" -type l -delete 2>/dev/null &>> "$LOG_DIR/pttools.log"
    log_message "${GREEN}qBittorrent程序文件已删除${NC}"
    echo -e "${GREEN}qBittorrent程序文件已删除${NC}"
}

# 删除qBittorrent配置文件
remove_qbittorrent_configs() {
    echo -e "${YELLOW}正在删除qBittorrent配置文件...${NC}"
    log_message "${YELLOW}正在删除qBittorrent配置文件...${NC}"

    local config_paths=(
        "/home/qbittorrent"
        "/root/.config/qBittorrent"
        "/etc/qbittorrent"
        "/opt/qbittorrent" # 可能包含配置文件
        "/usr/local/etc/qbittorrent"
        "/var/lib/qbittorrent"
        "/tmp/qbittorrent*"
    )

    for path in "${config_paths[@]}"; do
        if [[ -e "$path" ]]; then
            log_message "${GREEN}删除配置: $path${NC}"
            echo -e "${GREEN}删除配置: $path${NC}"
            rm -rf "$path" &>> "$LOG_DIR/pttools.log"
        fi
    done
    log_message "${GREEN}qBittorrent配置文件已删除${NC}"
    echo -e "${GREEN}qBittorrent配置文件已删除${NC}"
}

# 清理qBittorrent用户和组
cleanup_qbittorrent_user() {
    echo -e "${YELLOW}正在清理qBittorrent用户和组...${NC}"
    log_message "${YELLOW}正在清理qBittorrent用户和组...${NC}"

    if id "qbittorrent" &>/dev/null; then
        log_message "${GREEN}删除用户: qbittorrent${NC}"
        echo -e "${GREEN}删除用户: qbittorrent${NC}"
        userdel -r qbittorrent 2>/dev/null &>> "$LOG_DIR/pttools.log"
    fi

    if getent group qbittorrent &>/dev/null; then
        log_message "${GREEN}删除组: qbittorrent${NC}"
        echo -e "${GREEN}删除组: qbittorrent${NC}"
        groupdel qbittorrent 2>/dev/null &>> "$LOG_DIR/pttools.log"
    fi
    log_message "${GREEN}qBittorrent用户和组已清理${NC}"
    echo -e "${GREEN}qBittorrent用户和组已清理${NC}"
}

# 清理qBittorrent其他残留
cleanup_qbittorrent_misc() {
    echo -e "${YELLOW}正在清理qBittorrent其他残留文件...${NC}"
    log_message "${YELLOW}正在清理qBittorrent其他残留文件...${NC}"

    find /var/log -name "*qbittorrent*" -type f -delete 2>/dev/null &>> "$LOG_DIR/pttools.log"
    find /tmp -name "*qbittorrent*" -exec rm -rf {} + 2>/dev/null &>> "$LOG_DIR/pttools.log"

    if crontab -l 2>/dev/null | grep -q "qbittorrent"; then
        log_message "${YELLOW}检测到qBittorrent相关的cron任务，请手动检查: crontab -e${NC}"
        echo -e "${YELLOW}检测到qBittorrent相关的cron任务，请手动检查${NC}"
        echo -e "${WHITE}执行: crontab -e${NC}"
    fi
    log_message "${GREEN}qBittorrent其他残留文件已清理${NC}"
    echo -e "${GREEN}qBittorrent其他残留文件已清理${NC}"
}

# 最终清理
final_cleanup() {
    echo -e "${YELLOW}正在进行最终清理...${NC}"
    log_message "${YELLOW}正在进行最终清理...${NC}"

    systemctl daemon-reload &>> "$LOG_DIR/pttools.log"
    systemctl reset-failed 2>/dev/null &>> "$LOG_DIR/pttools.log"

    systemctl list-units --type=service --all | grep -i qbittorrent | awk '{print $1}' | while read -r service; do
        if [[ -n "$service" ]]; then
            log_message "${YELLOW}强制清理服务: $service${NC}"
            echo -e "${YELLOW}强制清理服务: $service${NC}"
            systemctl stop "$service" 2>/dev/null &>> "$LOG_DIR/pttools.log"
            systemctl disable "$service" 2>/dev/null &>> "$LOG_DIR/pttools.log"
            systemctl mask "$service" 2>/dev/null &>> "$LOG_DIR/pttools.log"
        fi
    done

    local all_possible_paths=(
        "/usr/local/bin/qbittorrent*" "/usr/bin/qbittorrent*"
        "/opt/qbittorrent*" "/usr/local/qbittorrent*"
        "/home/*/qbittorrent*" "/root/qbittorrent*"
    )
    for path_pattern in "${all_possible_paths[@]}"; do
        for path in $path_pattern; do
            if [[ -e "$path" ]]; then
                log_message "${GREEN}删除: $path${NC}"
                echo -e "${GREEN}删除: $path${NC}"
                rm -rf "$path" &>> "$LOG_DIR/pttools.log"
            fi
        done
    done
    systemctl daemon-reexec 2>/dev/null &>> "$LOG_DIR/pttools.log"
    log_message "${GREEN}最终清理完成${NC}"
    echo -e "${GREEN}最终清理完成${NC}"
}

# 验证qBittorrent卸载结果
verify_qbittorrent_removal() {
    echo -e "${BLUE}验证卸载结果：${NC}"
    log_message "${BLUE}验证卸载结果：${NC}"

    local all_clean=true

    if pgrep -f "qbittorrent" >/dev/null; then
        echo -e "${RED}✗ 仍有qBittorrent进程运行${NC}"
        ps aux | grep qbittorrent | grep -v grep | awk '{print "    PID: " $2 " CMD: " $11}'
        all_clean=false
    else
        echo -e "${GREEN}✓ 无qBittorrent进程${NC}"
    fi

    local remaining_services=()
    # Corrected syntax for while loop and if condition
    while IFS= read -r service; do
        if [[ -n "$service" ]]; then
            remaining_services+=("$service")
        fi
    done < <(systemctl list-units --type=service --all 2>/dev/null | grep -i qbittorrent | awk '{print $1}' | sed 's/[●*]//')

    if [[ ${#remaining_services[@]} -gt 0 ]]; then
        echo -e "${RED}✗ 仍有qBittorrent服务存在${NC}"
        for service in "${remaining_services[@]}"; do
            echo -e "${RED}    $service${NC}"
        done
        all_clean=false
    else
        echo -e "${GREEN}✓ 无qBittorrent服务${NC}"
    fi

    local found_binaries=()
    for binary in qbittorrent qbittorrent-nox; do
        if command -v "$binary" >/dev/null 2>&1; then
            found_binaries+=("$binary")
        fi
    done

    if [[ ${#found_binaries[@]} -gt 0 ]]; then
        echo -e "${RED}✗ 仍可找到qBittorrent程序${NC}"
        for binary in "${found_binaries[@]}"; do
            echo -e "${RED}    $binary -> $(which "$binary")${NC}"
        done
        all_clean=false
    else
        echo -e "${GREEN}✓ qBittorrent程序已删除${NC}"
    fi

    local config_check=(
        "/home/qbittorrent" "/root/.config/qBittorrent" "/etc/qbittorrent"
        "/opt/qbittorrent" # 检查可能残留的目录
    )
    local found_configs=()
    for config in "${config_check[@]}"; do
        if [[ -e "$config" ]]; then
            found_configs+=("$config")
        fi
    done

    if [[ ${#found_configs[@]} -gt 0 ]]; then
        echo -e "${YELLOW}! 发现残留配置/数据目录${NC}"
        for config in "${found_configs[@]}"; do
            echo -e "${YELLOW}    $config${NC}"
        done
    else
        echo -e "${GREEN}✓ 配置文件/数据目录已清理${NC}"
    fi

    echo
    if [[ "$all_clean" == true ]]; then
        log_message "${GREEN}🎉 qBittorrent已完全卸载！无任何残留！${NC}"
        echo -e "${GREEN}🎉 qBittorrent已完全卸载！无任何残留！${NC}"
        echo -e "${GREEN}如果之前有残留问题，现在应该已经解决了。${NC}"
    else
        log_message "${RED}⚠️  qBittorrent仍有残留，但已尽最大努力清理。${NC}"
        echo -e "${RED}⚠️  仍有残留，但已尽最大努力清理${NC}"
        echo -e "${YELLOW}如果仍有问题，建议重启系统${NC}"
        echo
        echo -e "${BLUE}手动清理命令：${NC}"
        echo -e "${GRAY}systemctl daemon-reload${NC}"
        echo -e "${GRAY}systemctl reset-failed${NC}"
        echo -e "${GRAY}reboot${NC}"
    fi
}

# 显示手动卸载指导 (通用，包含qBittorrent和Vertex)
show_manual_uninstall_guide() {
    echo -e "${BLUE}通用手动卸载指导：${NC}"
    log_message "${BLUE}显示通用手动卸载指导${NC}"
    echo
    echo -e "${WHITE}本指导适用于原生安装的 qBittorrent, Vertex 或其他通过类似脚本安装的组件。${NC}"
    echo -e "${RED}请谨慎操作，并根据您实际安装的组件进行调整。${NC}"
    echo
    echo -e "${WHITE}1. 停止相关服务：${NC}"
    echo -e "${GRAY}   systemctl stop qbittorrent # 或 systemctl stop qbittorrent-nox, systemctl stop vertex, etc.${NC}"
    echo -e "${GRAY}   systemctl disable qbittorrent # 停止开机自启${NC}"
    echo
    echo -e "${WHITE}2. 强制终止残留进程 (如果存在)：${NC}"
    echo -e "${GRAY}   pkill -9 -f "qbittorrent" # 或 pkill -9 -f "vertex"${NC}"
    echo
    echo -e "${WHITE}3. 删除服务文件：${NC}"
    echo -e "${GRAY}   rm -f /etc/systemd/system/qbittorrent*.service${NC}"
    echo -e "${GRAY}   rm -f /etc/systemd/system/vertex*.service${NC}"
    echo -e "${GRAY}   systemctl daemon-reload${NC}"
    echo
    echo -e "${WHITE}4. 删除程序文件及目录：${NC}"
    echo -e "${GRAY}   rm -rf /usr/local/bin/qbittorrent*${NC}"
    echo -e "${GRAY}   rm -rf /usr/local/bin/vertex*${NC}"
    echo -e "${GRAY}   rm -rf /opt/qbittorrent # 或其他安装目录${NC}"
    echo -e "${GRAY}   rm -rf /opt/vertex # 或其他安装目录${NC}"
    echo
    echo -e "${WHITE}5. 删除配置文件及数据目录：${NC}"
    echo -e "${GRAY}   rm -rf /home/qbittorrent # 用户家目录下的配置或数据${NC}"
    echo -e "${GRAY}   rm -rf /root/.config/qBittorrent${NC}"
    echo -e "${GRAY}   rm -rf /home/vertex # 或 /root/.config/vertex${NC}"
    echo -e "${GRAY}   rm -rf /var/lib/qbittorrent${NC}"
    echo
    echo -e "${WHITE}6. 删除相关用户和组 (如果存在)：${NC}"
    echo -e "${GRAY}   userdel -r qbittorrent${NC}"
    echo -e "${GRAY}   groupdel qbittorrent${NC}"
    echo -e "${GRAY}   userdel -r vertex${NC}"
    echo -e "${GRAY}   groupdel vertex${NC}"
    echo
    echo -e "${WHITE}7. 清理日志文件和临时文件：${NC}"
    echo -e "${GRAY}   find /var/log -name "*qbittorrent*" -delete${NC}"
    echo -e "${GRAY}   find /var/log -name "*vertex*" -delete${NC}"
    echo -e "${GRAY}   rm -rf /tmp/qbittorrent* /tmp/vertex*${NC}"
    echo
    echo -e "${WHITE}8. 最后执行：${NC}"
    echo -e "${GRAY}   systemctl daemon-reload${NC}"
    echo -e "${GRAY}   systemctl reset-failed${NC}"
    echo -e "${GRAY}   reboot # 重启系统确保所有残留清理干净${NC}"
    echo
}

# 显示Vertex手动卸载指导 (Specific for native Vertex if auto-uninstall fails)
show_manual_uninstall_guide_vertex() {
    echo -e "${BLUE}Vertex手动卸载指导 (如果自动卸载失败)：${NC}"
    log_message "${BLUE}显示Vertex手动卸载指导${NC}"
    echo
    echo -e "${WHITE}1. 停止Vertex服务：${NC}"
    echo -e "${GRAY}   systemctl stop vertex${NC}"
    echo -e "${GRAY}   systemctl disable vertex${NC}"
    echo
    echo -e "${WHITE}2. 删除服务文件：${NC}"
    echo -e "${GRAY}   rm -f /etc/systemd/system/vertex*.service${NC}"
    echo -e "${GRAY}   systemctl daemon-reload${NC}"
    echo
    echo -e "${WHITE}3. 删除程序文件及数据：${NC}"
    echo -e "${GRAY}   rm -rf /opt/vertex # 假设安装在/opt/vertex${NC}"
    echo -e "${GRAY}   rm -rf /usr/local/bin/vertex # 如果有链接或二进制文件${NC}"
    echo
    echo -e "${WHITE}4. 清理用户和组 (如果存在)：${NC}"
    echo -e "${GRAY}   userdel -r vertex${NC}"
    echo -e "${GRAY}   groupdel vertex${NC}"
    echo
    echo -e "${WHITE}5. 最后执行：${NC}"
    echo -e "${GRAY}   systemctl daemon-reload${NC}"
    echo -e "${GRAY}   systemctl reset-failed${NC}"
    echo -e "${GRAY}   reboot${NC}"
    echo
}

# 显示主菜单
show_menu() {
    clear
    show_banner
    # 移除冗余的主菜单标题
    # echo -e "${PURPLE}==================${NC}"
    # echo -e "${PURPLE}  PTtools 主菜单  ${NC}" # 居中标题
    # echo -e "${PURPLE}==================${NC}"
    echo
    echo -e "${WHITE}  1. qBittorrent 4.3.8⭐${NC}"
    echo -e "${WHITE}  2. qBittorrent 4.3.9⭐${NC}"
    echo -e "${WHITE}  3. Vertex + qBittorrent 4.3.8 (推荐Docker方式安装)🔥${NC}"
    echo -e "${WHITE}  4. Vertex + qBittorrent 4.3.9 (推荐Docker方式安装)🔥${NC}"
    echo -e "${WHITE}  5. 全套Docker应用 (qBittorrent, Transmission, Emby等)🔥 (开发中)${NC}"
    echo -e "${WHITE}  6. PT Docker应用 (分类安装)🔥${NC}"
    echo -e "${WHITE}  7. 系统优化 (VPS性能调优, 开发中)${NC}"
    echo -e "${WHITE}  8. 卸载应用${NC}"
    echo -e "${WHITE}  9. 卸载脚本${NC}"
    echo -e "${WHITE}  0. 退出脚本${NC}"
    echo
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${BLUE} Docker应用安装目录: ${DOCKER_DIR}${NC}"
    echo -e "${BLUE} 所有应用默认下载目录: ${DOWNLOADS_DIR}${NC}"
    echo -e "${BLUE} 脚本日志目录: ${LOG_DIR}${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo
}

# 主程序
main() {
    while true; do
        show_menu
        read -p "请输入选项 [0-9]: " choice

        log_message "用户选择主菜单选项: $choice"

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
                pt_docker_apps
                ;;
            7)
                log_message "${YELLOW}系统优化功能开发中...${NC}"
                echo -e "${YELLOW}系统优化功能开发中...${NC}"
                echo -e "${YELLOW}按任意键返回主菜单...${NC}"
                read -n 1
                ;;
            8)
                uninstall_apps
                ;;
            9)
                log_message "${YELLOW}正在卸载脚本...${NC}"
                echo -e "${YELLOW}正在卸载脚本...${NC}"
                rm -f "$0"
                if [ $? -eq 0 ]; then
                    log_message "${GREEN}脚本已删除${NC}"
                    echo -e "${GREEN}脚本已删除${NC}"
                else
                    log_message "${RED}脚本删除失败！请手动删除：$0${NC}"
                    echo -e "${RED}脚本删除失败！请手动删除：$0${NC}"
                fi
                exit 0
                ;;
            0)
                log_message "${GREEN}用户退出脚本。感谢使用PTtools！${NC}"
                echo -e "${GREEN}感谢使用PTtools！${NC}"
                exit 0
                ;;
            *)
                log_message "${RED}无效选项: $choice，请重新选择${NC}"
                echo -e "${RED}无效选项，请重新选择${NC}"
                echo -e "${YELLOW}按任意键继续...${NC}"
                read -n 1
                ;;
        esac
    done
}

# 初始化环境
clear
show_banner
echo -e "${YELLOW}正在初始化PTtools运行环境...${NC}" # 终端显示一次
log_message "${YELLOW}正在初始化PTtools运行环境...${NC}" # 日志记录一次
check_root
check_system
update_system

if ! install_base_tools; then
    log_message "${RED}基础工具安装失败！脚本终止。${NC}"
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

create_directories
check_docker_status # 此处调用静默检查函数，终端只显示摘要
echo -e "${GREEN}环境初始化完成！将自动进入主菜单。${NC}" # 终端显示一次
log_message "${GREEN}环境初始化完成！自动进入主菜单。${NC}" # 日志记录一次

# 运行主程序
main
