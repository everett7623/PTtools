#!/bin/bash

# PTtools 通用工具函数
# 文件路径: scripts/utils/common.sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：此脚本需要root权限运行${NC}"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 获取服务器IP
get_server_ip() {
    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null) || \
    SERVER_IP=$(curl -s --connect-timeout 5 ipinfo.io/ip 2>/dev/null) || \
    SERVER_IP=$(curl -s --connect-timeout 5 icanhazip.com 2>/dev/null) || \
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null) || \
    SERVER_IP="your-server-ip"
    
    export SERVER_IP
}

# 检测系统类型
detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        OS_VERSION=$VERSION_ID
        export OS OS_VERSION
    else
        echo -e "${RED}无法检测系统类型${NC}"
        exit 1
    fi
}

# 检查系统兼容性
check_system_compatibility() {
    detect_system
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        return 0
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        echo -e "${YELLOW}检测到 CentOS/RHEL 系统，某些功能可能需要适配${NC}"
        return 0
    else
        echo -e "${YELLOW}未完全测试的系统: $OS${NC}"
        echo -e "${YELLOW}建议使用 Ubuntu 18.04+ 或 Debian 10+${NC}"
        read -p "是否继续安装？[y/N]: " continue_install
        if [[ "${continue_install,,}" != "y" ]]; then
            exit 0
        fi
    fi
}

# 检查端口是否被占用
check_port() {
    local port="$1"
    if ss -tulnp | grep ":$port " >/dev/null 2>&1; then
        return 0  # 端口被占用
    else
        return 1  # 端口空闲
    fi
}

# 获取可用端口
get_available_port() {
    local start_port="$1"
    local port="$start_port"
    
    while check_port "$port"; do
        ((port++))
        if [[ $port -gt 65535 ]]; then
            echo "无法找到可用端口"
            return 1
        fi
    done
    
    echo "$port"
}

# 等待服务启动
wait_for_service() {
    local service_name="$1"
    local port="$2"
    local max_wait="${3:-60}"
    local count=0
    
    echo -n "等待 $service_name 启动"
    
    while [[ $count -lt $max_wait ]]; do
        if check_port "$port"; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((count += 2))
    done
    
    echo -e " ${RED}✗${NC}"
    return 1
}

# 显示成功信息
show_success() {
    local service_name="$1"
    local port="$2"
    
    echo
    echo -e "${GREEN}🎉 $service_name 安装成功！${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}访问信息：${NC}"
    echo -e "${CYAN}  服务器IP：${SERVER_IP}${NC}"
    if [[ -n "$port" ]]; then
        echo -e "${CYAN}  访问地址：http://${SERVER_IP}:${port}${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# 创建目录
create_directory() {
    local dir_path="$1"
    local permissions="${2:-755}"
    
    if mkdir -p "$dir_path" 2>/dev/null; then
        chmod "$permissions" "$dir_path"
        return 0
    else
        echo -e "${RED}无法创建目录: $dir_path${NC}"
        return 1
    fi
}

# 备份文件
backup_file() {
    local file_path="$1"
    local backup_path="${file_path}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$file_path" ]]; then
        if cp "$file_path" "$backup_path"; then
            echo -e "${GREEN}文件已备份: $backup_path${NC}"
            return 0
        else
            echo -e "${RED}备份失败: $file_path${NC}"
            return 1
        fi
    fi
    
    return 0
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 安装系统包
install_package() {
    local package="$1"
    
    if command_exists apt-get; then
        apt-get update -y && apt-get install -y "$package"
    elif command_exists yum; then
        yum install -y "$package"
    elif command_exists dnf; then
        dnf install -y "$package"
    else
        echo -e "${RED}不支持的包管理器${NC}"
        return 1
    fi
}

# 询问用户确认
ask_confirmation() {
    local message="$1"
    local default="${2:-N}"
    
    if [[ "$default" == "Y" ]]; then
        read -p "$message [Y/n]: " response
        response=${response:-Y}
    else
        read -p "$message [y/N]: " response
        response=${response:-N}
    fi
    
    if [[ "${response,,}" == "y" ]] || [[ "${response,,}" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

# 显示进度条
show_progress() {
    local current="$1"
    local total="$2"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%$((width - completed))s" | tr ' ' '-'
    printf "] %d%%" "$percentage"
}

# 验证IP地址格式
validate_ip() {
    local ip="$1"
    local stat=1
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    
    return $stat
}

# 获取系统信息
get_system_info() {
    echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo '未知')"
    echo "内核版本: $(uname -r)"
    echo "CPU架构: $(uname -m)"
    echo "CPU核心: $(nproc)"
    echo "内存大小: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "磁盘使用: $(df -h / | awk 'NR==2 {print $3"/"$2" ("$5")"}')"
}

# 检查网络连接
check_network() {
    local test_hosts=("github.com" "google.com" "baidu.com")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            return 0
        fi
    done
    
    echo -e "${RED}网络连接检查失败${NC}"
    return 1
}
