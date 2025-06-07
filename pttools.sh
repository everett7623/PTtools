#!/bin/bash

#================================================================================
#
#          FILE: pttools.sh
#
#         USAGE: bash <(wget -qO- https://raw.githubusercontent.com/everett7623/pttools/main/pttools.sh)
#
#   DESCRIPTION: 为了PTer快捷安装PT常用的工具，比如qb，tr，emby等等，适合小白。
#
#       OPTIONS: ---
#  REQUIREMENTS: root, curl, wget
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: everett7623
#  ORGANIZATION: https://github.com/everett7623/PTtools
#       CREATED: 2025-06-07
#      REVISION: 1.0
#
#================================================================================

# --- 输出颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- 脚本全局变量 ---
GITHUB_USER="everett7623"
GITHUB_REPO="PTtools"
GITHUB_BRANCH="main"
RAW_BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"
DOCKER_COMPOSE_CONFIG_PATH="configs/docker-compose"
INSTALL_SCRIPT_PATH="scripts/install"

# --- Docker 应用默认安装路径 ---
DOCKER_BASE_DIR="/opt/docker"

# --- 函数：环境检查 ---
pre_flight_checks() {
    # 1. 检查是否为 root 用户
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：此脚本必须以 root 身份运行。请使用 'sudo' 或切换到 root 用户。${NC}"
        exit 1
    fi

    # 2. 检查核心依赖 (curl, wget)
    echo -e "${BLUE}正在检查所需命令 (curl, wget)...${NC}"
    local missing_deps=()
    for cmd in curl wget; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${YELLOW}发现缺失的依赖命令: ${missing_deps[*]}。${NC}"
        read -p "是否尝试自动安装? (y/n): " choice
        if [[ "$choice" == "Y" || "$choice" == "y" ]]; then
            if command -v apt-get &> /dev/null; then
                apt-get update && apt-get install -y ${missing_deps[*]}
            elif command -v yum &> /dev/null; then
                yum install -y ${missing_deps[*]}
            else
                echo -e "${RED}无法确定包管理器。请手动安装 ${missing_deps[*]} 后重试。${NC}"
                exit 1
            fi
        else
            echo -e "${RED}脚本中止。请先手动安装缺失的依赖。${NC}"
            exit 1
        fi
    fi
    echo -e "${GREEN}环境依赖检查通过。${NC}"
}

# --- 函数：安装 Docker 和 Docker Compose ---
install_docker() {
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        echo -e "${GREEN}Docker 和 Docker Compose 已安装。${NC}"
        return 0
    fi

    echo -e "${BLUE}开始安装 Docker 环境...${NC}"
    echo "请选择 Docker 安装源:"
    echo "  1) Docker 官方源 (国外服务器推荐)"
    echo "  2) 阿里云镜像源 (国内服务器推荐)"
    read -p "请输入你的选择 [1-2, 默认 2]: " source_choice

    local install_cmd=""
    case "$source_choice" in
        1)
            install_cmd="curl -fsSL https://get.docker.com | bash -s docker"
            ;;
        2|'')
            install_cmd="curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun"
            ;;
        *)
            echo -e "${RED}无效的选择。${NC}"
            return 1
            ;;
    esac

    echo -e "${BLUE}正在执行安装命令...${NC}"
    if eval "$install_cmd"; then
        echo -e "${GREEN}Docker 安装成功。${NC}"
        # 启动并设置 Docker 开机自启
        systemctl enable docker
        systemctl start docker
    else
        echo -e "${RED}Docker 安装失败，请检查输出日志。${NC}"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        echo -e "${RED}Docker Compose 安装失败，请手动安装或确保 Docker 版本足够新。${NC}"
        exit 1
    fi
    echo -e "${GREEN}Docker 环境部署完毕。${NC}"
}

# --- 函数：准备 Docker 应用目录 ---
prepare_directories() {
    echo -e "${BLUE}正在准备 Docker 应用目录: ${DOCKER_BASE_DIR}${NC}"
    if [ ! -d "$DOCKER_BASE_DIR" ]; then
        mkdir -p "$DOCKER_BASE_DIR"
        echo -e "${GREEN}目录 ${DOCKER_BASE_DIR} 已创建。${NC}"
    else
        echo -e "${YELLOW}目录 ${DOCKER_BASE_DIR} 已存在。${NC}"
    fi

    echo -e "${YELLOW}警告：根据您的要求，将 ${DOCKER_BASE_DIR} 的权限设置为 777。这可能带来安全风险。${NC}"
    chmod -R 777 "$DOCKER_BASE_DIR"
}

# --- 函数：安装 qBittorrent (通过外部脚本) ---
install_qb() {
    local version="$1"
    # 将版本号中的点去掉，以匹配脚本文件名 (e.g., 4.3.8 -> qb438.sh)
    local script_name="qb${version//.}.sh"
    local script_url="${RAW_BASE_URL}/${INSTALL_SCRIPT_PATH}/${script_name}"
    local local_script_path="/tmp/${script_name}"

    echo -e "${BLUE}开始安装 qBittorrent v${version}...${NC}"
    echo -e "正在从 ${script_url} 下载安装脚本..."

    if ! wget -O "${local_script_path}" "${script_url}"; then
        echo -e "${RED}下载安装脚本 ${script_name} 失败！${NC}"
        echo -e "${RED}请检查文件是否存在于您的 Github 仓库中，或网络连接是否正常。${NC}"
        return 1
    fi

    echo -e "${GREEN}脚本下载成功，开始执行...${NC}"
    chmod +x "${local_script_path}"
    if "${local_script_path}"; then
        echo -e "${GREEN}qBittorrent v${version} 安装脚本执行完毕。${NC}"
    else
        echo -e "${RED}qBittorrent v${version} 安装脚本执行失败，请检查脚本输出。${NC}"
        return 1
    fi
}

# --- 函数：安装 Vertex (通过 Docker Compose) ---
install_vertex() {
    local app_name="vertex"
    local app_dir="${DOCKER_BASE_DIR}/${app_name}"
    local compose_file_name="vertex.yml"
    local compose_file_path="${app_dir}/${compose_file_name}"
    local config_url="${RAW_BASE_URL}/${DOCKER_COMPOSE_CONFIG_PATH}/${compose_file_name}"

    echo -e "${BLUE}开始安装 Vertex...${NC}"

    # 1. 创建应用目录
    echo -e "正在创建 Vertex 配置目录: ${app_dir}"
    mkdir -p "${app_dir}"

    # 2. 下载 docker-compose.yml 文件
    echo -e "正在从仓库下载 ${compose_file_name}..."
    if ! wget -O "${compose_file_path}" "${config_url}"; then
        echo -e "${RED}下载 ${compose_file_name} 失败！${NC}"
        echo -e "${RED}请检查文件是否存在于：${config_url}${NC}"
        return 1
    fi

    # 3. 启动容器
    echo -e "${BLUE}正在使用 Docker Compose 启动 Vertex...${NC}"
    cd "${app_dir}" || { echo -e "${RED}无法进入目录 ${app_dir}${NC}"; return 1; }
    
    if docker compose up -d; then
        echo -e "${GREEN}Vertex 安装并启动成功！${NC}"
        echo -e "${GREEN}访问地址: http://<你的VPS IP>:3334${NC}"
    else
        echo -e "${RED}Vertex 启动失败，请运行 'cd ${app_dir} && docker compose logs' 查看日志。${NC}"
        cd - > /dev/null
        return 1
    fi
    cd - > /dev/null
}


# --- 函数：主菜单 ---
show_main_menu() {
    clear
    echo -e "================================================================="
    echo -e " ${GREEN}PTtools - 快捷安装脚本 (By everett7623)${NC}"
    echo -e "================================================================="
    echo -e " ${YELLOW}Github: https://github.com/${GITHUB_USER}/${GITHUB_REPO}${NC}"
    echo -e " ${YELLOW}默认应用路径: ${DOCKER_BASE_DIR}${NC}"
    echo -e "-----------------------------------------------------------------"
    echo -e " ${BLUE}一、核心项目安装 (VPS刷流优化)${NC}"
    echo -e "   1. 安装 qBittorrent 4.3.8"
    echo -e "   2. 安装 qBittorrent 4.3.9"
    echo -e "   3. 安装 qBittorrent 4.3.8 + Vertex"
    echo -e "   4. 安装 qBittorrent 4.3.9 + Vertex"
    echo -e "   5. ${YELLOW}选择安装其他应用 (待开发...)${NC}"
    echo -e "-----------------------------------------------------------------"
    echo -e " ${BLUE}二、管理与维护${NC}"
    echo -e "   d. 检查/安装 Docker 环境"
    echo -e "   u. ${YELLOW}卸载已安装的应用 (待开发...)${NC}"
    echo -e "-----------------------------------------------------------------"
    echo -e "   q. 退出脚本"
    echo -e "================================================================="
    read -p "请输入你的选择: " main_choice
}

# --- 脚本主逻辑 ---
main() {
    pre_flight_checks

    while true; do
        show_main_menu
        # 安装前统一准备环境
        case "$main_choice" in
            1|2|3|4)
                prepare_directories
                install_docker
                # 如果Docker安装失败，则不继续
                if [ $? -ne 0 ]; then
                    read -p "按 Enter 键返回主菜单..."
                    continue
                fi
                ;;
        esac

        case "$main_choice" in
            1)
                install_qb "4.3.8"
                ;;
            2)
                install_qb "4.3.9"
                ;;
            3)
                install_qb "4.3.8" && install_vertex
                ;;
            4)
                install_qb "4.3.9" && install_vertex
                ;;
            5)
                echo -e "${YELLOW}此功能正在全力开发中，敬请期待！${NC}"
                ;;
            d|D)
                install_docker
                ;;
            u|U)
                echo -e "${YELLOW}卸载功能正在全力开发中，敬请期待！${NC}"
                ;;
            q|Q)
                echo -e "${GREEN}感谢使用 PTtools，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的输入，请重新选择。${NC}"
                ;;
        esac
        read -p "按 Enter 键返回主菜单..."
    done
}

# --- 脚本入口 ---
main
