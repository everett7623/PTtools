#!/bin/bash

# ===================================================================================================
# PT Docker应用管理脚本
# 脚本名称: ptdocker.sh
# 脚本描述: PT相关Docker应用的安装和管理工具，支持分类展示、多选安装、日志记录。
# 脚本路径: https://raw.githubusercontent.com/everett7623/PTtools/main/configs/ptdocker.sh
# 作者: Jensfrank (GitHub: everett7623)
# 项目: PTtools
# 更新时间: 2025-09-18
# ===================================================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 从主脚本接收参数 (DOCKER_DIR, DOWNLOADS_DIR, LOG_DIR, GITHUB_RAW)
DOCKER_DIR="$1"
DOWNLOADS_DIR="$2"
LOG_DIR="$3"
GITHUB_RAW="$4"

# 脚本日志文件
PTDOCKER_LOG_FILE="$LOG_DIR/ptdocker.log"

# 记录日志 (只写入文件，不输出到终端)
log_message() {
    mkdir -p "$LOG_DIR" &>/dev/null # 确保日志目录在记录前存在
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$timestamp] $1" >> "$PTDOCKER_LOG_FILE"
}

# --- 应用数据定义 ---
# 每个元素格式: "id;name;app_name_dir;yml_file;compose_subdir;label;port;type"
# name: 在菜单中显示的应用名称 (包含标签如 🔥/🔖/⭐)
# app_name_dir: 实际在 /opt/docker/ 下创建的目录名
# yml_file: Docker Compose 文件名 (例如 qbittorrent-4.6.7.yml)
# compose_subdir: Docker Compose 文件在 GitHub 仓库中的子目录 (例如 downloaders)
# label: 显示在应用名称后的标签 (🔥/🔖/⭐)
# port: 默认访问端口或 "N/A" (无Web界面)
# type: "docker" (Docker应用) 或 "native_redirect" (原生安装，引导回主脚本)

declare -a ALL_APPS_DATA=(
# 🔽 下载客户端 (6个)
"1;qBittorrent 4.3.8;qb_native_438;;downloaders;⭐;N/A;native_redirect"
"2;qBittorrent 4.3.9;qb_native_439;;downloaders;⭐;N/A;native_redirect"
"3;qBittorrent 4.6.7;qbittorrent-467;qbittorrent-4.6.7.yml;downloaders;;8080;docker"
"4;qBittorrent 最新版;qbittorrent-latest;qbittorrent-latest.yml;downloaders;🔥;8080;docker"
"5;Transmission 4.0.5;transmission;transmission.yml;downloaders;;9091;docker"
"6;Aria2;aria2;aria2.yml;downloaders;;6800;docker"

# 🤖 PT自动化 (14个)
"7;IYUUPlus;iyuuplus;iyuuplus.yml;automation;🔥;8780;docker"
"8;MoviePilot;moviepilot;moviepilot.yml;automation;🔥;3000;docker"
"9;Vertex;vertex;vertex.yml;automation;;3333;docker"
"10;Cross-Seed;cross-seed;cross-seed.yml;automation;;2468;docker"
"11;ReseedPuppy;reseedpuppy;reseedpuppy.yml;automation;;5000;docker"
"12;Sonarr;sonarr;sonarr.yml;automation;;8989;docker"
"13;Radarr;radarr;radarr.yml;automation;;7878;docker"
"14;Lidarr;lidarr;lidarr.yml;automation;;8686;docker"
"15;Prowlarr;prowlarr;prowlarr.yml;automation;;9696;docker"
"16;Autobrr;autobrr;autobrr.yml;automation;;7337;docker"
"17;Bazarr;bazarr;bazarr.yml;automation;;6767;docker"
"18;PT Nexus;pt-nexus;pt-nexus.yml;automation;;8081;docker"
"19;Flexget;flexget;flexget.yml;automation;;N/A;docker"
"20;Jackett;jackett;jackett.yml;automation;;9117;docker"

# 📺 媒体服务器 (9个)
"21;Emby;emby;emby.yml;media-servers;🔥;8096;docker"
"22;Jellyfin;jellyfin;jellyfin.yml;media-servers;;8096;docker"
"23;Plex;plex;plex.yml;media-servers;;32400;docker"
"24;Navidrome;navidrome;navidrome.yml;media-servers;;4533;docker"
"25;Audiobookshelf;audiobookshelf;audiobookshelf.yml;media-servers;;6875;docker"
"26;Calibre-Web;calibre-web;calibre-web.yml;media-servers;;8083;docker"
"27;Komga;komga;komga.yml;media-servers;;8082;docker"
"28;Music-Tag-Web;music-tag-web;music-tag-web.yml;media-servers;;8000;docker"
"29;Skit-Panel;skit-panel;skit-panel.yml;media-servers;;8084;docker"

# 🌐 网络与文件 (8个)
"30;Filebrowser;filebrowser;filebrowser.yml;network-files;🔥;8081;docker"
"31;Clouddrive2;clouddrive2;clouddrive2.yml;network-files;;19798;docker"
"32;Frps (服务端);frps;frps.yml;network-files;;7000;docker"
"33;Frpc (客户端);frpc;frpc.yml;network-files;;N/A;docker"
"34;Lucky;lucky;lucky.yml;network-files;;16601;docker"
"35;Homepage;homepage;homepage.yml;network-files;;3001;docker"
"36;Sun-Panel;sun-panel;sun-panel.yml;network-files;;9090;docker"
"37;CookieCloud;cookiecloud;cookiecloud.yml;network-files;;8000;docker"

# ⚙️ 系统工具 (3个)
"38;Watchtower;watchtower;watchtower.yml;system-tools;;N/A;docker"
"39;Netdata;netdata;netdata.yml;system-tools;;19999;docker"
"40;Qiandao;qiandao;qiandao.yml;system-tools;;8088;docker"

# 🔥 PT专区 (4个)
"41;Metatube;metatube;metatube.yml;pt-special;🔖;8001;docker"
"42;Byte-Muse;byte-muse;byte-muse.yml;pt-special;🔖;8002;docker"
"43;Ikaros (刮削小姐姐);ikaros;ikaros.yml;pt-special;🔖;3002;docker"
"44;MDCNG (刮削小姐姐);mdcng;mdcng.yml;pt-special;🔖;3003;docker"
)

# --- 分类元数据定义 ---
# 格式: "category_key;分类显示名 (数量);应用ID列表 (空格分隔)"
declare -a CATEGORIES_META=(
"download_clients;🔽 下载客户端 (6个);1 2 3 4 5 6"
"pt_automation;🤖 PT自动化 (14个);7 8 9 10 11 12 13 14 15 16 17 18 19 20"
"media_servers;📺 媒体服务器 (9个);21 22 23 24 25 26 27 28 29"
"network_files;🌐 网络与文件 (8个);30 31 32 33 34 35 36 37"
"system_tools;⚙️ 系统工具 (3个);38 39 40"
"pt_special;🔥 PT专区 (4个);41 42 43 44"
)

# --- 解析应用数据到关联数组 ---
declare -A APP_MAP_NAME         # ID -> Display Name (e.g., "qBittorrent 4.6.7 🔥")
declare -A APP_MAP_APP_DIR      # ID -> Docker directory name (e.g., "qbittorrent-467")
declare -A APP_MAP_YML          # ID -> YAML filename (e.g., "qbittorrent-4.6.7.yml")
declare -A APP_MAP_SUBDIR       # ID -> Compose subdirectory (e.g., "downloaders")
declare -A APP_MAP_LABEL        # ID -> Label (e.g., "🔥")
declare -A APP_MAP_PORT         # ID -> Port (e.g., "8080")
declare -A APP_MAP_TYPE         # ID -> Type ("docker" or "native_redirect")
declare -A CATEGORY_APPS_IDS    # category_key -> "id1 id2 id3 ..." (space-separated list of IDs)

# 用于计算动态列宽
current_max_display_name_len=0

for app_data_str in "${ALL_APPS_DATA[@]}"; do
    IFS=';' read -r id name app_name_dir yml_file compose_subdir label port type <<< "$app_data_str"
    APP_MAP_NAME[$id]="$name"
    APP_MAP_APP_DIR[$id]="$app_name_dir"
    APP_MAP_YML[$id]="$yml_file"
    APP_MAP_SUBDIR[$id]="$compose_subdir"
    APP_MAP_LABEL[$id]="$label"
    APP_MAP_PORT[$id]="$port"
    APP_MAP_TYPE[$id]="$type"

    # 计算最长名称，用于动态列宽。这里name和label都可能带颜色码和emoji，需要移除它们计算实际可见长度
    # 使用sed -r "s/\x1B\[[0-9;]*[mGK]//g" 移除ANSI颜色码
    clean_name_with_label=$(echo "${name} ${label}" | sed -r "s/\x1B\[[0-9;]*[mGK]//g" | xargs)
    name_len=${#clean_name_with_label}
    if (( name_len > current_max_display_name_len )); then
        current_max_display_name_len=$name_len
    fi
done

for cat_meta_str in "${CATEGORIES_META[@]}"; do
    IFS=';' read -r cat_key cat_display_name_with_count cat_ids_list <<< "$cat_meta_str"
    CATEGORY_APPS_IDS[$cat_key]="$cat_ids_list"
done

# 显示标题
show_title() {
    clear
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${WHITE}                       PTtools Docker应用安装脚本${NC}"
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${YELLOW}作者: Jensfrank  |  项目: PTtools  |  更新时间: 2025-09-18${NC}"
    echo -e "${YELLOW}Docker应用安装目录: ${DOCKER_DIR}  |  下载目录: ${DOWNLOADS_DIR}${NC}"
    echo -e "${CYAN}==============================================================================${NC}"
    echo
}

# 显示应用菜单 - 多列紧凑布局
show_menu() {
    show_title
    
    local num_columns=3 # 定义列数
    # 动态计算每列的宽度
    # current_max_display_name_len: 实际最长应用名+标签的可见长度
    # ID长度最大可能为2位 (例如44), 加上". "和空格，所以 +5 是一个比较安全的保守值
    local column_base_width=$((current_max_display_name_len + 5)) 
    local total_terminal_width=$(tput cols)
    if (( total_terminal_width < 80 )); then total_terminal_width=80; fi # 确保最小宽度

    # 尝试动态调整列宽以适应终端，并至少保证基本对齐
    local effective_column_width=$(( (total_terminal_width - (num_columns - 1) * 3) / num_columns )) # 减去列间距 (每列3个空格)
    if (( effective_column_width < column_base_width + 2 )); then # 确保每列至少比内容宽一点
        effective_column_width=$((column_base_width + 2))
    fi
    local column_spacing=3 # 列之间的固定空格数

    declare -a category_keys=("download_clients" "pt_automation" "media_servers" "network_files" "system_tools" "pt_special")
    declare -A category_display_names_map # cat_key -> display_name_with_count

    # 准备分类显示名和数量
    for cat_meta_str in "${CATEGORIES_META[@]}"; do
        IFS=';' read -r cat_key cat_display_name_with_count _ <<< "$cat_meta_str"
        category_display_names_map[$cat_key]="$cat_display_name_with_count"
    done

    # 打印分类标题行
    local header_line=""
    local current_header_col=0
    for key in "${category_keys[@]}"; do
        local header_text="${category_display_names_map[$key]}"
        local clean_header_text=$(echo "${header_text}" | sed -r "s/\x1B\[[0-9;]*[mGK]//g" | xargs)
        local header_padding=$((effective_column_width - ${#clean_header_text}))

        header_line+="$(printf "${YELLOW}%s${NC}%*s" "$header_text" ${header_padding} "")"
        current_header_col=$((current_header_col + 1))
        if (( current_header_col < num_columns )); then
            header_line+="$(printf "%*s" ${column_spacing} "")"
        else
            echo -e "$header_line"
            header_line=""
            current_header_col=0
        fi
    done
    if [[ -n "$header_line" ]]; then # 打印任何剩余的标题
        echo -e "$header_line"
    fi
    echo # 标题后空一行

    # 准备按分类存储的应用列表，用于按行打印
    declare -A category_app_lists_row_indexed # category_key -> array of IDs
    local max_apps_in_any_category=0

    for key in "${category_keys[@]}"; do
        local ids_str="${CATEGORY_APPS_IDS[$key]}"
        read -ra ids_arr <<< "$ids_str"
        category_app_lists_row_indexed[$key]="${ids_arr[@]}" # 存储为Bash数组
        
        local current_cat_app_count=${#ids_arr[@]}
        if (( current_cat_app_count > max_apps_in_any_category )); then
            max_apps_in_any_category=$current_cat_app_count
        fi
    done
    
    # 打印应用列表，按行对齐
    for (( row=0; row<max_apps_in_any_category; row++ )); do
        local line_output=""
        local current_app_col=0
        for key in "${category_keys[@]}"; do
            local ids_str="${category_app_lists_row_indexed[$key]}"
            read -ra ids_arr <<< "$ids_str" # 将字符串再次读入数组

            if (( row < ${#ids_arr[@]} )); then
                local app_id="${ids_arr[$row]}"
                local app_name_raw="${APP_MAP_NAME[$app_id]}"
                local app_label_raw="${APP_MAP_LABEL[$app_id]}" # 获取原始标签，以包含颜色/emoji
                
                local display_name="${app_name_raw} ${app_label_raw}"
                # 再次清理颜色码和emoji，以便计算可见长度，与column_base_width对比
                local clean_display_name=$(echo "${display_name}" | sed -r "s/\x1B\[[0-9;]*[mGK]//g" | xargs)
                
                local id_len=$(printf "%s" "${app_id}" | wc -c) # ID数字的长度
                local padding_needed=$((effective_column_width - ${#clean_display_name} - id_len - 2)) # 减去ID长度和". "的长度
                if (( padding_needed < 0 )); then padding_needed=0; fi # 避免负数填充

                # 使用原始的app_name和app_label进行打印，确保颜色和emoji显示
                line_output+="$(printf "${WHITE}%s. %s %s${NC}%*s" "$app_id" "$app_name_raw" "$app_label_raw" ${padding_needed} "")"
            else
                # 空位填充，保持对齐
                line_output+="$(printf "%*s" ${effective_column_width} "")"
            fi
            current_app_col=$((current_app_col + 1))
            if (( current_app_col < num_columns )); then
                line_output+="$(printf "%*s" ${column_spacing} "")"
            fi
        done
        echo -e "$line_output"
    done
    echo

    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${WHITE}特殊选项:${NC}"
    echo -e "${YELLOW}88. 批量安装热门套餐    99. 返回主菜单    0. 退出脚本${NC}"
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${WHITE}🔥 热门推荐应用    🔖 新应用    ⭐ 原生安装 (请在主菜单选择)${NC}"
    echo
}

# qBittorrent 4.3.8 特殊提示
show_qbt_438_notice() {
    log_message "${YELLOW}用户尝试在ptdocker.sh中安装qBittorrent 4.3.8，已引导至主脚本${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${WHITE}          qBittorrent 4.3.8 安装提示${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo
    echo -e "${YELLOW}qBittorrent 4.3.8 需要使用原作者脚本进行原生安装${NC}"
    echo -e "${RED}请退出当前Docker安装脚本，回到主脚本pttools.sh进行安装${NC}"
    echo
    echo -e "${WHITE}主脚本运行命令：${NC}"
    echo -e "${BLUE}bash <(wget -qO- ${GITHUB_RAW}/pttools.sh)${NC}"
    echo
    echo -e "${CYAN}==================================================${NC}"
    read -p "$(echo -e ${YELLOW}按回车键返回菜单...${NC})" -r
}

# qBittorrent 4.3.9 特殊提示
show_qbt_439_notice() {
    log_message "${YELLOW}用户尝试在ptdocker.sh中安装qBittorrent 4.3.9，已引导至主脚本${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${WHITE}          qBittorrent 4.3.9 安装提示${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo
    echo -e "${YELLOW}qBittorrent 4.3.9 需要使用原作者脚本进行原生安装${NC}"
    echo -e "${RED}请退出当前Docker安装脚本，回到主脚本pttools.sh进行安装${NC}"
    echo
    echo -e "${WHITE}主脚本运行命令：${NC}"
    echo -e "${BLUE}bash <(wget -qO- ${GITHUB_RAW}/pttools.sh)${NC}"
    echo
    echo -e "${CYAN}==================================================${NC}"
    read -p "$(echo -e ${YELLOW}按回车键返回菜单...${NC})" -r
}

# 安装Docker应用 (新的，更通用)
install_docker_app() {
    local app_id="$1"
    local app_name="${APP_MAP_NAME[$app_id]}" # Display name
    local app_name_dir="${APP_MAP_APP_DIR[$app_id]}" # Directory name for /opt/docker/
    local yml_file="${APP_MAP_YML[$app_id]}" # YAML file name
    local compose_subdir="${APP_MAP_SUBDIR[$app_id]}" # Subdirectory on GitHub
    local default_port="${APP_MAP_PORT[$app_id]}" # Default port or N/A

    log_message "${BLUE}开始安装 Docker 应用: ${app_name} (ID: ${app_id}, Dir: ${app_name_dir}, YML: ${yml_file}, Subdir: ${compose_subdir})${NC}"
    echo -e "${BLUE}正在安装 ${app_name}...${NC}"
    
    # 检查并确保Docker环境
    if ! command -v docker &> /dev/null || (! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null); then
        log_message "${RED}Docker 或 Docker Compose 未安装，无法安装 ${app_name}。请返回主脚本安装Docker。${NC}"
        echo -e "${RED}Docker 或 Docker Compose 未安装！此脚本需要Docker才能运行。请返回主脚本安装Docker。${NC}"
        return 1
    fi

    # 1. 创建应用配置目录
    local app_config_dir="${DOCKER_DIR}/${app_name_dir}/config"
    echo -e "${YELLOW}创建应用配置目录: ${app_config_dir}${NC}"
    log_message "${YELLOW}创建应用配置目录: ${app_config_dir}${NC}"
    mkdir -p "$app_config_dir" &>> "$PTDOCKER_LOG_FILE"
    if [ $? -ne 0 ]; then
        log_message "${RED}创建应用配置目录失败: ${app_config_dir}${NC}"
        echo -e "${RED}创建应用配置目录失败！${NC}"
        return 1
    fi
    chmod -R 777 "$app_config_dir" &>> "$PTDOCKER_LOG_FILE"

    # 2. 确保下载目录存在并赋权
    echo -e "${YELLOW}确保下载目录存在并赋权: ${DOWNLOADS_DIR}${NC}"
    log_message "${YELLOW}确保下载目录存在并赋权: ${DOWNLOADS_DIR}${NC}"
    mkdir -p "$DOWNLOADS_DIR" &>> "$PTDOCKER_LOG_FILE"
    if [ $? -ne 0 ]; then
        log_message "${RED}创建下载目录失败: ${DOWNLOADS_DIR}${NC}"
        echo -e "${RED}创建下载目录失败！${NC}"
        return 1
    fi
    chmod -R 777 "$DOWNLOADS_DIR" &>> "$PTDOCKER_LOG_FILE"

    # 3. 下载Docker Compose配置文件
    local temp_compose_file="${DOCKER_DIR}/${app_name_dir}/${yml_file}" # 下载到应用自己的Docker目录
    local compose_url="${GITHUB_RAW}/configs/docker-compose/${compose_subdir}/${yml_file}"
    echo -e "${YELLOW}正在下载 Docker Compose 配置: ${compose_url}${NC}"
    log_message "${YELLOW}正在下载 Docker Compose 配置: ${compose_url} 到 ${temp_compose_file}${NC}"

    if curl -fsSL "$compose_url" -o "$temp_compose_file" &>> "$PTDOCKER_LOG_FILE"; then
        log_message "${GREEN}${app_name} Docker Compose配置下载成功${NC}"
        echo -e "${GREEN}${app_name} Docker Compose配置下载成功${NC}"
    else
        log_message "${RED}${app_name} Docker Compose配置下载失败！URL: ${compose_url}${NC}"
        echo -e "${RED}下载 ${app_name} Docker Compose配置文件失败！请检查网络或URL。${NC}"
        return 1
    fi

    # 4. 替换 Docker Compose 文件中的变量
    echo -e "${YELLOW}正在替换 Docker Compose 文件中的路径变量...${NC}"
    log_message "${YELLOW}正在替换 Docker Compose 文件中的路径变量...${NC}"
    # 替换 /opt/docker/应用名/config 占位符
    sed -i "s|/opt/docker/应用名/config|${app_config_dir}|g" "$temp_compose_file" &>> "$PTDOCKER_LOG_FILE"
    # 替换 /opt/downloads 占位符
    sed -i "s|/opt/downloads|${DOWNLOADS_DIR}|g" "$temp_compose_file" &>> "$PTDOCKER_LOG_FILE"
    # 替换 services 下的应用名
    # 注意：这个替换逻辑依赖于YAML文件中的特定模式。如果YAML文件的服务名直接是 app_name_dir，则无需额外替换。
    # 假设YAML模板中的服务名是 '应用名' 或具体名称，这里为了通用性，尝试替换 '应用名'
    # 更安全的做法是，YAML文件本身就使用环境变量 $APP_NAME_DIR 或直接是正确的服务名。
    # 这里我们只替换一次 '应用名:'，以防它作为服务名或容器名占位符出现。
    # sed -i "s|应用名:|${app_name_dir}:|g" "$temp_compose_file" &>> "$PTDOCKER_LOG_FILE" 

    # 5. 启动Docker容器
    echo -e "${YELLOW}正在启动 ${app_name} 容器...${NC}"
    log_message "${YELLOW}正在启动 ${app_name} 容器...${NC}"
    local docker_compose_bin=""
    if command -v docker-compose &> /dev/null; then
        docker_compose_bin="docker-compose"
    elif docker compose version &> /dev/null; then
        docker_compose_bin="docker compose"
    else
        log_message "${RED}Docker Compose/docker compose 命令行工具未找到！${NC}"
        echo -e "${RED}错误：Docker Compose/docker compose 命令行工具未找到！${NC}"
        return 1
    fi

    # 切换到应用目录执行 docker compose 命令
    local current_dir=$(pwd)
    cd "${DOCKER_DIR}/${app_name_dir}" &>> "$PTDOCKER_LOG_FILE" || { 
        log_message "${RED}切换目录失败: ${DOCKER_DIR}/${app_name_dir}${NC}"; 
        echo -e "${RED}错误：无法进入应用目录 ${DOCKER_DIR}/${app_name_dir}！${NC}"; 
        cd "$current_dir" &>/dev/null; 
        return 1; 
    }

    if ${docker_compose_bin} -f "${yml_file}" up -d &>> "$PTDOCKER_LOG_FILE"; then
        log_message "${GREEN}✅ ${app_name} 安装成功！${NC}"
        echo -e "${GREEN}✅ ${app_name} 安装成功！${NC}"
        echo -e "${YELLOW}----------------------------------------------------${NC}"
        echo -e "${GREEN}安装路径: ${DOCKER_DIR}/${app_name_dir}${NC}"
        if [[ "$default_port" != "N/A" ]]; then
            echo -e "${GREEN}访问地址: http://你的服务器IP:${default_port}${NC}"
            log_message "${app_name} 访问地址: http://你的服务器IP:${default_port}"
        else
            echo -e "${GREEN}${app_name} 通常没有Web界面，请通过CLI或特定方式访问。${NC}"
            log_message "${app_name} 无Web界面，端口N/A"
        fi
        echo -e "${YELLOW}----------------------------------------------------${NC}"

        # 验证容器状态
        sleep 5 # 等待容器启动
        if docker ps --filter "name=^${app_name_dir}$" --format "{{.Status}}" | grep -q "Up"; then
            echo -e "${GREEN}容器 ${app_name_dir} 正在运行。${NC}"
            log_message "${GREEN}容器 ${app_name_dir} 正在运行。${NC}"
        else
            echo -e "${RED}容器 ${app_name_dir} 未能成功启动，请查看日志获取更多信息。${NC}"
            log_message "${RED}容器 ${app_name_dir} 未能成功启动。${NC}"
        fi
    else
        log_message "${RED}❌ ${app_name} 启动失败！请查看日志：${PTDOCKER_LOG_FILE}${NC}"
        echo -e "${RED}❌ ${app_name} 启动失败！请查看日志：${PTDOCKER_LOG_FILE}${NC}"
        return 1
    fi
    cd "$current_dir" &>/dev/null
    return 0
}

# 批量安装热门套餐
install_popular_stack() {
    log_message "${YELLOW}进入批量安装热门套餐菜单${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${WHITE}             批量安装热门套餐${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo
    echo -e "${YELLOW}请选择热门套餐:${NC}"
    echo -e "${WHITE}1. 下载管理套餐${NC} (qBittorrent 4.6.7 + Transmission + Aria2 + Vertex)"
    echo -e "${WHITE}2. 媒体服务套餐${NC} (Emby + Jellyfin + Navidrome)"
    echo -e "${WHITE}3. 自动化管理套餐${NC} (MoviePilot + IYUUPlus + Sonarr + Radarr)"
    echo -e "${WHITE}4. 完整PT套餐${NC} (包含下载、媒体、自动化、监控)"
    echo -e "${WHITE}5. 热门推荐套餐${NC} (精选最受欢迎的应用)"
    echo -e "${RED}0. 返回${NC}"
    echo
    read -p "$(echo -e ${CYAN}请选择套餐 [0-5]: ${NC})" stack_choice
    
    local apps_to_install_ids=()
    case $stack_choice in
        1)
            log_message "选择下载管理套餐"
            apps_to_install_ids=("3" "5" "6" "9") # qB 4.6.7, Transmission, Aria2, Vertex
            ;;
        2)
            log_message "选择媒体服务套餐"
            apps_to_install_ids=("21" "22" "24") # Emby, Jellyfin, Navidrome
            ;;
        3)
            log_message "选择自动化管理套餐"
            apps_to_install_ids=("8" "7" "12" "13") # MoviePilot, IYUUPlus, Sonarr, Radarr
            ;;
        4)
            log_message "选择完整PT套餐"
            apps_to_install_ids=(
                "3" "5" "6" # 下载: qB 4.6.7, Transmission, Aria2
                "21" "22" # 媒体: Emby, Jellyfin
                "8" "7" "12" "13" "9" "16" # 自动化: MoviePilot, IYUUPlus, Sonarr, Radarr, Vertex, Autobrr
                "35" "38" "39" # 工具: Homepage, Watchtower, Netdata
            )
            ;;
        5)
            log_message "选择热门推荐套餐"
            apps_to_install_ids=(
                "4" "8" "7" "21" # qB latest, MoviePilot, IYUUPlus, Emby
                "35" "38" "30" "41" # Homepage, Watchtower, Filebrowser, Metatube
            )
            ;;
        0)
            log_message "取消批量安装"
            return
            ;;
        *)
            log_message "${RED}无效套餐选择！${NC}"
            echo -e "${RED}无效选择！${NC}"
            read -p "$(echo -e ${YELLOW}按回车键继续...${NC})" -r
            return
            ;;
    esac

    echo -e "${YELLOW}开始安装所选套餐中的应用...${NC}"
    local success_count=0
    local fail_count=0
    for app_id in "${apps_to_install_ids[@]}"; do
        echo
        if install_docker_app "$app_id"; then
            success_count=$((success_count+1))
        else
            fail_count=$((fail_count+1))
        fi
        echo
    done

    echo -e "${CYAN}==================================================${NC}"
    echo -e "${WHITE}             批量安装结果${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${GREEN}成功安装应用数: ${success_count}${NC}"
    echo -e "${RED}失败安装应用数: ${fail_count}${NC}"
    echo -e "${CYAN}==================================================${NC}"
    read -p "$(echo -e ${YELLOW}按回车键继续...${NC})" -r
}

# 处理用户选择
handle_choice() {
    read -p "$(echo -e ${CYAN}请输入应用序号 (支持多选，用空格分隔，如: 1 2 3): ${NC})" choices
    log_message "用户选择应用: $choices"
    
    if [[ -z "$choices" ]]; then
        echo -e "${RED}未选择任何应用！${NC}"
        log_message "${RED}用户未选择任何应用！${NC}"
        return
    fi
    
    local selected_app_ids=()
    read -ra selected_app_ids <<< "$choices"

    for app_id in "${selected_app_ids[@]}"; do
        if [[ "$app_id" == "88" ]]; then
            install_popular_stack
            continue
        elif [[ "$app_id" == "99" ]]; then
            log_message "用户选择返回主菜单。"
            return 99 # Special return code for main script to handle
        elif [[ "$app_id" == "0" ]]; then
            log_message "用户选择退出脚本。"
            exit 0
        fi

        # Find app details from MAPs
        local app_type="${APP_MAP_TYPE[$app_id]}"
        
        if [[ -z "$app_type" ]]; then
            echo -e "${RED}❌ 无效选择: ${app_id}${NC}"
            log_message "${RED}无效选择: ${app_id}${NC}"
            continue
        fi

        case "$app_type" in
            "native_redirect")
                if [[ "${APP_MAP_NAME[$app_id]}" == "qBittorrent 4.3.8" ]]; then
                    show_qbt_438_notice
                elif [[ "${APP_MAP_NAME[$app_id]}" == "qBittorrent 4.3.9" ]]; then
                    show_qbt_439_notice
                fi
                ;;
            "docker")
                install_docker_app "$app_id"
                ;;
            *)
                echo -e "${RED}❌ 未知应用类型: ${app_type} (ID: ${app_id})${NC}"
                log_message "${RED}未知应用类型: ${app_type} (ID: ${app_id})${NC}"
                ;;
        esac
        echo # Add a newline after each app installation/message
    done
}

# 主函数
main() {
    log_message "${YELLOW}ptdocker.sh 脚本启动，接收参数: DOCKER_DIR=$DOCKER_DIR, DOWNLOADS_DIR=$DOWNLOADS_DIR, LOG_DIR=$LOG_DIR, GITHUB_RAW=$GITHUB_RAW${NC}"

    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        log_message "${RED}Docker 未安装！此脚本需要Docker才能运行。{{NC}}"
        echo -e "${RED}Docker 未安装！此脚本需要Docker才能运行。请返回主脚本安装Docker。${NC}"
        return 1
    fi
    
    # 检查docker-compose是否安装
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_message "${RED}Docker Compose 未安装！此脚本需要Docker Compose才能运行。{{NC}}"
        echo -e "${RED}Docker Compose 未安装！此脚本需要Docker Compose才能运行。请返回主脚本安装Docker Compose。${NC}"
        return 1
    fi
    
    while true; do
        show_menu
        handle_choice_result=$(handle_choice) # Capture return code or output
        
        if [[ "$handle_choice_result" == "99" ]]; then # If handle_choice signals to return to main script
            return 0
        fi

        echo # 确保“按回车键继续”前有空行
        read -p "$(echo -e ${YELLOW}按回车键继续...${NC})" -r
    done
}

# 脚本入口
main "$@"
