#!/bin/bash

# PTtools 一键安装脚本
# 作者：everett7623
# GitHub 项目：https://github.com/everett7623/PTtools

# 默认配置
DOCKER_APP_DIR="/opt/docker"
DOWNLOAD_DIR="/opt/downloads"
GITHUB_RAW_URL="https://raw.githubusercontent.com/everett7623/PTtools/main"

# --- 函数定义 ---

# 打印信息
print_info() {
    echo -e "\e[1;32m[INFO]\e[0m $1"
}

# 打印错误
print_error() {
    echo -e "\e[1;31m[ERROR]\e[0m $1"
}

# 打印警告
print_warning() {
    echo -e "\e[1;33m[WARNING]\e[0m $1"
}

# 检查 Docker 是否安装
check_docker_installed() {
    if command -v docker &> /dev/null; then
        print_info "Docker 已安装。"
        return 0
    else
        print_warning "Docker 未安装。"
        return 1
    fi
}

# 安装 Docker
install_docker() {
    print_info "开始安装 Docker..."
    echo "请选择 Docker 安装方式:"
    echo "1. 直接下载安装 (推荐)"
    echo "2. 使用阿里云国内镜像安装"
    read -p "请输入你的选择 (1/2): " docker_choice

    case "$docker_choice" in
        1)
            curl -fsSL https://get.docker.com | bash -s docker
            ;;
        2)
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            ;;
        *)
            print_error "无效的选择，取消 Docker 安装。"
            return 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        print_info "Docker 安装成功！"
        # 验证 Docker 服务状态
        systemctl enable docker
        systemctl start docker
        print_info "Docker 服务已启动并设置开机自启。"
        # 配置 Docker 工作目录权限
        mkdir -p "${DOCKER_APP_DIR}"
        chmod -R 777 "${DOCKER_APP_DIR}"
        print_info "Docker 应用目录 ${DOCKER_APP_DIR} 已创建并设置权限。"
        return 0
    else
        print_error "Docker 安装失败，请检查网络连接或手动安装。"
        return 1
    fi
}

# 检查 Docker Compose 是否安装
check_docker_compose_installed() {
    if command -v docker-compose &> /dev/null; then
        print_info "Docker Compose 已安装。"
        return 0
    elif docker compose version &> /dev/null; then # Docker Compose V2
        print_info "Docker Compose V2 已安装。"
        return 0
    else
        print_warning "Docker Compose 未安装。"
        return 1
    fi
}

# 安装 Docker Compose
install_docker_compose() {
    print_info "尝试安装 Docker Compose..."
    local os_type=$(uname -s)
    local arch_type=$(uname -m)

    if [ "$os_type" == "Linux" ]; then
        if [ "$arch_type" == "x86_64" ]; then
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            print_info "Docker Compose 安装成功！"
            return 0
        else
            print_warning "非 x86_64 架构，请手动安装 Docker Compose。"
            return 1
        fi
    else
        print_warning "非 Linux 系统，请手动安装 Docker Compose。"
        return 1
    fi
}

# 安装 qBittorrent 4.3.8 (VPS)
install_qb438() {
    print_info "开始安装 qBittorrent 4.3.8..."
    local script_url="${GITHUB_RAW_URL}/scripts/install/qb438.sh"
    wget -O /tmp/qb438.sh "${script_url}" && chmod +x /tmp/qb438.sh && /tmp/qb438.sh
    if [ $? -eq 0 ]; then
        print_info "qBittorrent 4.3.8 安装成功！"
    else
        print_error "qBittorrent 4.3.8 安装失败。"
    fi
    rm -f /tmp/qb438.sh
}

# 安装 qBittorrent 4.3.9 (VPS)
install_qb439() {
    print_info "开始安装 qBittorrent 4.3.9..."
    local script_url="${GITHUB_RAW_URL}/scripts/install/qb439.sh"
    wget -O /tmp/qb439.sh "${script_url}" && chmod +x /tmp/qb439.sh && /tmp/qb439.sh
    if [ $? -eq 0 ]; then
        print_info "qBittorrent 4.3.9 安装成功！"
    else
        print_error "qBittorrent 4.3.9 安装失败。"
    fi
    rm -f /tmp/qb439.sh
}

# 安装 Vertex (Docker)
install_vertex() {
    print_info "开始安装 Vertex (Docker)..."
    mkdir -p "${DOCKER_APP_DIR}/vertex"
    local docker_compose_file="${DOCKER_APP_DIR}/vertex/docker-compose.yaml"
    local config_url="${GITHUB_RAW_URL}/configs/docker-compos/vertex.yaml"

    wget -O "${docker_compose_file}" "${config_url}"

    if [ $? -eq 0 ]; then
        print_info "Vertex Docker Compose 配置已下载到 ${docker_compose_file}"
        cd "${DOCKER_APP_DIR}/vertex"
        docker-compose up -d
        if [ $? -eq 0 ]; then
            print_info "Vertex 安装并启动成功！"
        else
            print_error "Vertex Docker 容器启动失败。"
        fi
        cd - > /dev/null
    else
        print_error "下载 Vertex Docker Compose 配置失败。"
    fi
}

# 通用 Docker Compose 应用安装函数
install_docker_app() {
    local app_name=$1
    print_info "开始安装 ${app_name} (Docker)..."
    mkdir -p "${DOCKER_APP_DIR}/${app_name}"
    local docker_compose_file="${DOCKER_APP_DIR}/${app_name}/docker-compose.yaml"
    local config_url="${GITHUB_RAW_URL}/configs/docker-compos/${app_name}.yaml"

    wget -O "${docker_compose_file}" "${config_url}"

    if [ $? -eq 0 ]; then
        print_info "${app_name} Docker Compose 配置已下载到 ${docker_compose_file}"
        cd "${DOCKER_APP_DIR}/${app_name}"
        docker-compose up -d
        if [ $? -eq 0 ]; then
            print_info "${app_name} 安装并启动成功！"
        else
            print_error "${app_name} Docker 容器启动失败。"
        fi
        cd - > /dev/null
    else
        print_error "下载 ${app_name} Docker Compose 配置失败。"
    fi
}

# 核心项目安装菜单
core_install_menu() {
    clear
    echo "---"
    echo "## 一、核心项目安装选项 (1-4 适用于 PT 刷流优化)"
    echo "---"
    echo "1. qb 4.3.8 (VPS 安装)"
    echo "2. qb 4.3.9 (VPS 安装)"
    echo "3. qb 4.3.8 + Vertex (qb VPS 安装，Vertex Docker 安装)"
    echo "4. qb 4.3.9 + Vertex (qb VPS 安装，Vertex Docker 安装)"
    echo "5. 选择安装应用 (进入二、功能分类与工具列表)"
    echo "0. 退出"
    echo "---"
    read -p "请输入你的选择 (0-5): " core_choice

    case "$core_choice" in
        1)
            install_qb438
            ;;
        2)
            install_qb439
            ;;
        3)
            install_qb438
            install_vertex
            ;;
        4)
            install_qb439
            install_vertex
            ;;
        5)
            application_selection_menu
            ;;
        0)
            print_info "退出脚本。"
            exit 0
            ;;
        *)
            print_error "无效的选择，请重新输入。"
            ;;
    esac
    read -p "按任意键返回主菜单..."
    main_menu
}

# 应用选择安装菜单 (目前只添加了文档中提到的应用，后续可扩展)
application_selection_menu() {
    clear
    echo "---"
    echo "## 二、功能分类与工具列表"
    echo "---"
    echo "请选择要安装的应用 (输入序号，可多选，例如: 1 3 5)"
    echo "输入 'b' 返回上一级菜单，输入 '0' 退出脚本"
    echo ""

    local apps=(
        "qbittorrent" "transmission" "iyuuplus" "moviepilot" "vertex"
        "cross-seed" "reseedpuppy" "sonarr" "radarr" "lidarr" "prowlarr"
        "autobrr" "bazarr" "nastools" "ani-rss" "jackett" "cloudsaver"
        "emby" "jellyfin" "plex" "tautulli" "navidrome" "airsonic"
        "audiobookshelf" "music-tag" "musictab" "calibre-web" "komga" "mango"
        "filebrowser" "alist" "clouddrive2" "nextcloud" "syncthing" "rclone"
        "chinesesubfinder" "frp" "sakura" "v2raya" "lucky" "nginx"
        "wireguard" "duckdns" "homepage" "organizr" "webmin" "watchtower"
        "dockercopilot" "netdata" "librespeed" "quota" "vaultwarden" "memos"
        "qiandao" "cookiecloud" "harvest" "ombi" "allinone" "metatube"
        "byte-muse" "ikaros"
    )

    local i=1
    for app in "${apps[@]}"; do
        echo "$((i++)). ${app}"
    done
    echo "---"

    read -p "你的选择: " app_choices

    if [[ "$app_choices" == "b" ]]; then
        core_install_menu
        return
    elif [[ "$app_choices" == "0" ]]; then
        print_info "退出脚本。"
        exit 0
    fi

    local selected_indices=($app_choices)
    for index in "${selected_indices[@]}"; do
        if (( index >= 1 && index <= ${#apps[@]} )); then
            local app_to_install="${apps[$((index-1))]}"
            if [[ "$app_to_install" == "qbittorrent" || "$app_to_install" == "transmission" ]]; then
                # qbittorrent 和 transmission 在这里统一走 docker compose 安装，不再区分版本
                install_docker_app "$app_to_install"
            elif [[ "$app_to_install" == "vertex" ]]; then
                install_vertex # Vertex 有自己的安装函数，但也可以通过通用函数安装
            else
                install_docker_app "$app_to_install"
            fi
        else
            print_error "无效的序号: $index"
        fi
    done
    read -p "按任意键返回主菜单..."
    main_menu
}

# 卸载功能 (待完善)
uninstall_menu() {
    clear
    echo "---"
    echo "## 三、卸载功能"
    echo "---"
    echo "1. 卸载部分应用 (待实现)"
    echo "2. 卸载所有 PTtools 相关应用和 Docker (待实现)"
    echo "0. 返回主菜单"
    echo "---"
    read -p "请输入你的选择 (0-2): " uninstall_choice

    case "$uninstall_choice" in
        1)
            print_warning "部分应用卸载功能待实现。"
            ;;
        2)
            print_warning "所有应用和 Docker 卸载功能待实现。"
            ;;
        0)
            main_menu
            ;;
        *)
            print_error "无效的选择，请重新输入。"
            ;;
    esac
    read -p "按任意键返回主菜单..."
    main_menu
}

# 主菜单
main_menu() {
    clear
    echo "---"
    echo "## 欢迎使用 PTtools 一键脚本"
    echo "---"
    echo "当前 Docker 应用安装目录: ${DOCKER_APP_DIR}"
    echo "当前默认下载目录: ${DOWNLOAD_DIR}"
    echo ""
    echo "请选择操作:"
    echo "1. 安装 PT 相关工具"
    echo "2. 卸载 PT 相关工具"
    echo "0. 退出脚本"
    echo "---"

    # 检查 Docker 和 Docker Compose 安装状态，并提示安装
    if ! check_docker_installed; then
        read -p "是否现在安装 Docker? (y/n): " install_docker_now
        if [[ "$install_docker_now" =~ ^[Yy]$ ]]; then
            install_docker
            if [ $? -ne 0 ]; then
                read -p "Docker 安装失败，是否继续? (y/n): " continue_without_docker
                if [[ "$continue_without_docker" =~ ^[Nn]$ ]]; then
                    print_info "退出脚本。"
                    exit 1
                fi
            fi
        fi
    fi

    if ! check_docker_compose_installed; then
        read -p "是否现在安装 Docker Compose? (y/n): " install_compose_now
        if [[ "$install_compose_now" =~ ^[Yy]$ ]]; then
            install_docker_compose
            if [ $? -ne 0 ]; then
                read -p "Docker Compose 安装失败，是否继续? (y/n): " continue_without_compose
                if [[ "$continue_without_compose" =~ ^[Nn]$ ]]; then
                    print_info "退出脚本。"
                    exit 1
                fi
            fi
        fi
    fi

    read -p "请输入你的选择 (0-2): " main_choice

    case "$main_choice" in
        1)
            core_install_menu
            ;;
        2)
            uninstall_menu
            ;;
        0)
            print_info "退出脚本。"
            exit 0
            ;;
        *)
            print_error "无效的选择，请重新输入。"
            read -p "按任意键返回主菜单..."
            main_menu
            ;;
    esac
}

# --- 脚本主入口 ---
main_menu
