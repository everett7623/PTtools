#!/bin/bash

# PTtools Docker应用菜单
# 脚本名称: ptdocker.sh
# 脚本描述: PT Docker应用一键安装管理脚本
# 脚本路径: https://raw.githubusercontent.com/everett7623/PTtools/main/configs/ptdocker.sh
# 作者: Jensfrank
# Github: https://github.com/everett7623/PTtools
# 更新时间: 2025-06-27

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
DOCKER_DIR="/opt/docker"
DOWNLOAD_DIR="/opt/downloads"
GITHUB_URL="https://raw.githubusercontent.com/everett7623/PTtools/main"

# 应用映射数组
declare -A APP_MAP=(
    ["1"]="qbittorrent_4.3.8"
    ["2"]="qbittorrent_4.3.9"
    ["3"]="qbittorrent_4.6.7"
    ["4"]="qbittorrent_5.0.2"
    ["5"]="qbittorrent_latest"
    ["6"]="transmission"
    ["7"]="iyuuplus"
    ["8"]="moviepilot"
    ["9"]="vertex"
    ["10"]="cross-seed"
    ["11"]="reseed-puppy"
    ["12"]="sonarr"
    ["13"]="radarr"
    ["14"]="lidarr"
    ["15"]="prowlarr"
    ["16"]="autobrr"
    ["17"]="bazarr"
    ["18"]="nastools"
    ["19"]="ani-rss"
    ["20"]="jackett"
    ["21"]="cloudsaver"
    ["22"]="emby"
    ["23"]="jellyfin"
    ["24"]="plex"
    ["25"]="tautulli"
    ["26"]="navidrome"
    ["27"]="airsonic"
    ["28"]="audiobookshelf"
    ["29"]="music-tag"
    ["30"]="musictab"
    ["31"]="calibre-web"
    ["32"]="komga"
    ["33"]="mango"
    ["34"]="filebrowser"
    ["35"]="clouddrive2"
    ["36"]="nextcloud"
    ["37"]="syncthing"
    ["38"]="rclone"
    ["39"]="chinesesubfinder"
    ["40"]="bazarr-subtitle"
    ["41"]="frps"
    ["42"]="frpc"
    ["43"]="sakura-frp"
    ["44"]="v2raya"
    ["45"]="lucky"
    ["46"]="nginx"
    ["47"]="wireguard"
    ["48"]="duckdns"
    ["49"]="homepage"
    ["50"]="organizr"
    ["51"]="webmin"
    ["52"]="watchtower"
    ["53"]="dockercopilot"
    ["54"]="netdata"
    ["55"]="librespeed"
    ["56"]="quota-monitor"
    ["57"]="vaultwarden"
    ["58"]="memos"
    ["59"]="qiandao"
    ["60"]="cookiecloud"
    ["61"]="harvest"
    ["62"]="ombi"
    ["63"]="allinone"
    ["64"]="metatube"
    ["65"]="byte-muse"
    ["66"]="ikaros"
)

# 检查Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误：Docker未安装，无法使用Docker应用功能${NC}"
        echo -e "${YELLOW}请先安装Docker后再使用此功能${NC}"
        echo -e "${YELLOW}按任意键返回...${NC}"
        read -n 1
        return 1
    fi
    return 0
}

# 下载Docker Compose配置文件
download_compose_file() {
    local app_name="$1"
    local compose_file="/tmp/${app_name}-compose.yml"
    local github_url="$GITHUB_URL/configs/docker-compose/${app_name}.yml"
    
    echo -e "${YELLOW}正在下载 ${app_name} 配置文件...${NC}"
    
    if curl -fsSL "$github_url" -o "$compose_file"; then
        echo -e "${GREEN}${app_name} 配置文件下载成功${NC}"
        return 0
    else
        echo -e "${RED}${app_name} 配置文件下载失败${NC}"
        return 1
    fi
}

# 启动Docker应用
start_docker_app() {
    local app_name="$1"
    local compose_file="/tmp/${app_name}-compose.yml"
    
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

# 安装单个应用
install_app() {
    local app_number="$1"
    local app_key="${APP_MAP[$app_number]}"
    
    if [[ -z "$app_key" ]]; then
        echo -e "${RED}无效的应用序号: $app_number${NC}"
        return 1
    fi
    
    echo -e "${CYAN}正在安装应用: $app_key${NC}"
    
    # 检查是否为原作者脚本应用
    if [[ "$app_number" == "1" || "$app_number" == "2" ]]; then
        echo -e "${YELLOW}此应用需要在主脚本中安装，请返回主菜单选择对应选项${NC}"
        return 1
    fi
    
    # 检查是否已安装
    if docker ps -a --format "table {{.Names}}" | grep -q "^${app_key}$"; then
        echo -e "${YELLOW}检测到 $app_key 已安装${NC}"
        read -p "是否重新安装？[y/N]: " reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}安装已取消${NC}"
            return 0
        fi
        
        # 停止并删除现有容器
        echo -e "${YELLOW}正在移除现有容器...${NC}"
        docker stop "$app_key" 2>/dev/null
        docker rm "$app_key" 2>/dev/null
    fi
    
    # 创建应用目录
    echo -e "${YELLOW}正在创建应用目录...${NC}"
    mkdir -p "/opt/docker/$app_key"
    
    # 下载配置文件
    if download_compose_file "$app_key"; then
        echo -e "${GREEN}配置文件下载成功${NC}"
    else
        echo -e "${RED}配置文件下载失败，无法安装 $app_key${NC}"
        return 1
    fi
    
    # 启动应用
    echo -e "${YELLOW}正在启动 $app_key...${NC}"
    if start_docker_app "$app_key"; then
        echo -e "${YELLOW}等待应用启动...${NC}"
        sleep 5
        
        # 检查应用状态
        if docker ps --format "table {{.Names}}" | grep -q "^${app_key}$"; then
            echo -e "${GREEN}$app_key 安装成功！${NC}"
            show_app_info "$app_key"
            return 0
        else
            echo -e "${RED}$app_key 启动失败${NC}"
            echo -e "${YELLOW}请检查日志: docker logs $app_key${NC}"
            return 1
        fi
    else
        echo -e "${RED}$app_key 安装失败${NC}"
        return 1
    fi
}

# 显示应用信息
show_app_info() {
    local app_name="$1"
    
    # 获取端口信息
    local ports=$(docker port "$app_name" 2>/dev/null | head -3)
    
    if [[ -n "$ports" ]]; then
        echo -e "${BLUE}访问信息：${NC}"
        while IFS= read -r port_line; do
            if [[ -n "$port_line" ]]; then
                local port=$(echo "$port_line" | awk -F'->' '{print $2}' | awk -F':' '{print $2}')
                if [[ -n "$port" ]]; then
                    echo -e "${WHITE}• 访问地址: http://你的服务器IP:$port${NC}"
                fi
            fi
        done <<< "$ports"
    fi
    
    echo -e "${BLUE}管理命令：${NC}"
    echo -e "${WHITE}• 查看日志: docker logs $app_name${NC}"
    echo -e "${WHITE}• 重启应用: docker restart $app_name${NC}"
    echo -e "${WHITE}• 停止应用: docker stop $app_name${NC}"
}

# 处理用户输入
handle_user_input() {
    local input="$1"
    
    # 处理多选情况
    if [[ "$input" =~ [[:space:]] ]]; then
        echo -e "${YELLOW}检测到多选安装${NC}"
        local apps=($input)
        local success_count=0
        local failed_count=0
        
        for app_num in "${apps[@]}"; do
            if [[ "$app_num" =~ ^[0-9]+$ ]] && [[ "$app_num" -ge 1 ]] && [[ "$app_num" -le 66 ]]; then
                echo -e "${CYAN}正在安装应用 $app_num...${NC}"
                if install_app "$app_num"; then
                    ((success_count++))
                else
                    ((failed_count++))
                fi
                echo
            else
                echo -e "${RED}跳过无效序号: $app_num${NC}"
                ((failed_count++))
            fi
        done
        
        echo -e "${GREEN}批量安装完成！${NC}"
        echo -e "${GREEN}成功: $success_count 个${NC}"
        echo -e "${RED}失败: $failed_count 个${NC}"
        
    elif [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -ge 1 ]] && [[ "$input" -le 66 ]]; then
        # 单选安装
        install_app "$input"
    else
        echo -e "${RED}无效输入，请输入有效的应用序号${NC}"
        return 1
    fi
}

show_pt_docker_menu() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}           PT Docker 应用管理          ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${CYAN}📖 使用说明：${NC}"
    echo -e "   • 输入序号安装单个应用: ${YELLOW}1${NC}"
    echo -e "   • 多选安装用空格分隔: ${YELLOW}1 2 3${NC}"
    echo -e "   • 输入 ${YELLOW}0${NC} 返回主菜单"
    echo ""
    
    # 下载管理类别
    echo -e "${GREEN}🔽 下载管理${NC}"
    echo -e "   ${YELLOW}1.${NC}  qBittorrent 4.3.8 ${RED}🔥${NC}    ${YELLOW}2.${NC}  qBittorrent 4.3.9 ${RED}🔥${NC}    ${YELLOW}3.${NC}  qBittorrent 4.6.7"
    echo -e "   ${YELLOW}4.${NC}  qBittorrent 5.0.2 ${GREEN}🔖${NC}    ${YELLOW}5.${NC}  qBittorrent 最新版       ${YELLOW}6.${NC}  Transmission 4.0.5"
    echo ""
    
    # 自动化管理类别
    echo -e "${GREEN}🤖 自动化管理${NC}"
    echo -e "   ${YELLOW}7.${NC}  IYUU Plus ${RED}🔥${NC}           ${YELLOW}8.${NC}  MoviePilot ${RED}🔥${NC}           ${YELLOW}9.${NC}  Vertex ${RED}🔥${NC}"
    echo -e "   ${YELLOW}10.${NC} Cross-seed               ${YELLOW}11.${NC} Reseed Puppy             ${YELLOW}12.${NC} Sonarr"
    echo -e "   ${YELLOW}13.${NC} Radarr                   ${YELLOW}14.${NC} Lidarr                   ${YELLOW}15.${NC} Prowlarr"
    echo -e "   ${YELLOW}16.${NC} AutoBRR                  ${YELLOW}17.${NC} Bazarr                   ${YELLOW}18.${NC} NasTools"
    echo -e "   ${YELLOW}19.${NC} Ani-RSS ${GREEN}🔖${NC}"
    echo ""
    
    # 搜索工具类别
    echo -e "${GREEN}🔍 搜索工具${NC}"
    echo -e "   ${YELLOW}20.${NC} Jackett ${RED}🔥${NC}             ${YELLOW}21.${NC} CloudSaver ${GREEN}🔖${NC}"
    echo ""
    
    # 媒体服务器类别
    echo -e "${GREEN}📺 媒体服务器${NC}"
    echo -e "   ${YELLOW}22.${NC} Emby ${RED}🔥${NC}               ${YELLOW}23.${NC} Jellyfin ${RED}🔥${NC}            ${YELLOW}24.${NC} Plex"
    echo -e "   ${YELLOW}25.${NC} Tautulli"
    echo ""
    
    # 音频相关类别
    echo -e "${GREEN}🎵 音频相关${NC}"
    echo -e "   ${YELLOW}26.${NC} Navidrome              ${YELLOW}27.${NC} Airsonic                ${YELLOW}28.${NC} AudioBookshelf"
    echo -e "   ${YELLOW}29.${NC} Music-Tag               ${YELLOW}30.${NC} MusicTab ${GREEN}🔖${NC}"
    echo ""
    
    # 电子书管理类别
    echo -e "${GREEN}📚 电子书管理${NC}"
    echo -e "   ${YELLOW}31.${NC} Calibre-Web ${RED}🔥${NC}       ${YELLOW}32.${NC} Komga                   ${YELLOW}33.${NC} Mango"
    echo ""
    
    # 文件管理类别
    echo -e "${GREEN}📁 文件管理${NC}"
    echo -e "   ${YELLOW}34.${NC} FileBrowser ${RED}🔥${NC}       ${YELLOW}35.${NC} CloudDrive2 ${GREEN}🔖${NC}        ${YELLOW}36.${NC} NextCloud"
    echo -e "   ${YELLOW}37.${NC} Syncthing               ${YELLOW}38.${NC} Rclone"
    echo ""
    
    # 字幕工具类别
    echo -e "${GREEN}📝 字幕工具${NC}"
    echo -e "   ${YELLOW}39.${NC} ChineseSubFinder ${RED}🔥${NC}  ${YELLOW}40.${NC} Bazarr (字幕版)"
    echo ""
    
    # 网络工具类别
    echo -e "${GREEN}🌐 网络工具${NC}"
    echo -e "   ${YELLOW}41.${NC} FRP Server              ${YELLOW}42.${NC} FRP Client              ${YELLOW}43.${NC} Sakura FRP"
    echo -e "   ${YELLOW}44.${NC} V2rayA                  ${YELLOW}45.${NC} Lucky ${GREEN}🔖${NC}                ${YELLOW}46.${NC} Nginx"
    echo -e "   ${YELLOW}47.${NC} WireGuard               ${YELLOW}48.${NC} DuckDNS"
    echo ""
    
    # Web管理面板类别
    echo -e "${GREEN}🖥️ Web管理面板${NC}"
    echo -e "   ${YELLOW}49.${NC} Homepage ${RED}🔥${NC}           ${YELLOW}50.${NC} Organizr                ${YELLOW}51.${NC} Webmin"
    echo ""
    
    # 系统监控类别
    echo -e "${GREEN}⚙️ 系统监控${NC}"
    echo -e "   ${YELLOW}52.${NC} Watchtower ${RED}🔥${NC}        ${YELLOW}53.${NC} Docker Copilot ${GREEN}🔖${NC}     ${YELLOW}54.${NC} NetData"
    echo -e "   ${YELLOW}55.${NC} LibreSpeed              ${YELLOW}56.${NC} Quota Monitor"
    echo ""
    
    # 个人服务类别
    echo -e "${GREEN}👤 个人服务${NC}"
    echo -e "   ${YELLOW}57.${NC} Vaultwarden ${RED}🔥${NC}       ${YELLOW}58.${NC} Memos ${GREEN}🔖${NC}              ${YELLOW}59.${NC} Qiandao"
    echo -e "   ${YELLOW}60.${NC} CookieCloud             ${YELLOW}61.${NC} Harvest                 ${YELLOW}62.${NC} Ombi"
    echo -e "   ${YELLOW}63.${NC} AllInOne ${GREEN}🔖${NC}"
    echo ""
    
    # 9kg专区类别
    echo -e "${GREEN}🔥 9kg专区${NC}"
    echo -e "   ${YELLOW}64.${NC} MetaTube ${GREEN}🔖${NC}          ${YELLOW}65.${NC} Byte-Muse ${GREEN}🔖${NC}           ${YELLOW}66.${NC} Ikaros ${GREEN}🔖${NC}"
    echo ""
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${CYAN}💡 提示: 🔥=热门推荐 🔖=新增应用${NC}"
    echo -e "${CYAN}💡 注意: 序号1-2为原作者脚本，请在主菜单选择${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# 主循环
main() {
    # 检查Docker
    if ! check_docker; then
        exit 1
    fi
    
    while true; do
        show_pt_docker_menu
        echo -e -n "${GREEN}请输入要安装的应用序号 (多选用空格分隔，0返回): ${NC}"
        read user_input
        
        case "$user_input" in
            0)
                echo -e "${GREEN}返回主菜单${NC}"
                exit 0
                ;;
            "")
                echo -e "${YELLOW}请输入有效选项${NC}"
                sleep 1
                ;;
            *)
                handle_user_input "$user_input"
                echo
                echo -e "${YELLOW}按任意键继续...${NC}"
                read -n 1
                ;;
        esac
    done
}

# 运行主程序
main
