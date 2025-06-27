#!/bin/bash

# PT Docker应用管理脚本
# 脚本名称: ptdocker.sh
# 脚本描述: PT相关Docker应用的安装和管理工具
# 脚本路径: https://raw.githubusercontent.com/everett7623/PTtools/main/configs/ptdocker.sh
# 作者: Jensfrank
# 项目: PTtools
# 更新时间: 2025-06-27

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Docker 应用安装目录
DOCKER_DIR="/opt/docker"
DOWNLOADS_DIR="/opt/downloads"
CONFIG_DIR="/root/PTtools/configs/docker-compose"

# 显示标题
show_title() {
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${WHITE}                PT Docker 应用管理${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${YELLOW}作者: Jensfrank  |  项目: PTtools${NC}"
    echo -e "${YELLOW}安装目录: ${DOCKER_DIR}  |  下载目录: ${DOWNLOADS_DIR}${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo
}

# 显示应用菜单
show_menu() {
    clear
    show_title
    
    # 使用echo -e和固定格式来确保对齐，避免颜色代码影响printf对齐
    echo -e "${YELLOW}▼ 下载管理                   ▼ 自动化管理                 ▼ 媒体服务器${NC}"
    echo "1. qBittorrent 4.3.8         7. IyuuPlus🔥                22. Emby🔥"
    echo "2. qBittorrent 4.3.9         8. MoviePilot🔥              23. Jellyfin🔥"
    echo "3. qBittorrent 4.6.7         9. Vertex🔥                  24. Plex"
    echo "4. qBittorrent 5.0.2🔖       10. Cross-seed               25. Tautulli"
    echo "5. qBittorrent Latest🔖      11. ReseedPuppy              26. DDNS-GO🔖"
    echo "6. Transmission 4.0.5        12. Sonarr                   "
    echo "                             13. Radarr                   "
    echo -e "${YELLOW}▼ 搜索工具${NC}                   ${YELLOW}14. Lidarr${NC}                   ${YELLOW}▼ 音频相关${NC}"
    echo "20. Jackett                  15. Prowlarr                 27. Navidrome"
    echo "21. CloudSaver🔖             16. AutoBrr                  28. Airsonic"
    echo "                             17. Bazarr                   29. AudioBookShelf🔖"
    echo -e "${YELLOW}▼ 电子书管理${NC}                 ${YELLOW}18. NasTools${NC}                 ${YELLOW}30. Music-Tag🔖${NC}"
    echo "32. Calibre-Web              19. Ani-RSS🔖                31. MusicTab🔖"
    echo "33. Komga                    "
    echo "34. Mango                    "
    echo "                             "
    echo -e "${YELLOW}▼ 网络工具${NC}                   ${YELLOW}▼ 字幕工具${NC}                   ${YELLOW}▼ 文件管理${NC}"
    echo "42. FRPS                     40. ChineseSubFinder         35. FileBrowser"
    echo "43. FRPC                     41. Bazarr                   36. CloudDrive2🔥"
    echo "44. Sakura🔖                                              37. NextCloud"
    echo "45. V2rayA                   "
    echo "46. Lucky🔥                  "
    echo "47. Nginx                    "
    echo "48. WireGuard                "
    echo "49. DuckDNS                  "
    echo "                             "
    echo -e "${YELLOW}▼ Web管理面板${NC}                ${YELLOW}▼ 个人服务${NC}                   ${YELLOW}▼ 系统监控${NC}"
    echo "50. HomePage🔥               58. Vaultwarden🔥            53. Watchtower🔥"
    echo "51. Organizr                 59. Memos🔖                  54. DockerCopilot🔖"
    echo "52. Webmin                   60. Qiandao                  55. NetData"
    echo "                             61. CookieCloud🔖            56. LibreSpeed"
    echo "                             62. Harvest🔖                57. Quota🔖"
    echo "                             63. Ombi                     "
    echo "                             64. AllInOne🔖               "
    echo "                             "
    echo -e "${YELLOW}▼ 9kg专区${NC}"
    echo "65. MetaTube🔥"
    echo "66. Byte-Muse🔖"
    echo "67. Ikaros🔖"
    echo
    
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${WHITE}特殊选项:${NC}"
    echo -e "${YELLOW}88. 批量安装热门套餐${NC}"
    echo -e "${YELLOW}99. 返回主菜单${NC}"
    echo -e "${RED}0. 退出脚本${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo
}

# 安装Docker应用
install_app() {
    local app_name=$1
    local compose_file=$2
    
    echo -e "${BLUE}正在安装 ${app_name}...${NC}"
    
    # 创建应用目录
    mkdir -p "${DOCKER_DIR}/${app_name}"
    
    # 下载Docker Compose配置文件
    if wget -O "${DOCKER_DIR}/${app_name}/docker-compose.yml" \
        "https://raw.githubusercontent.com/everett7623/PTtools/main/configs/docker-compose/${compose_file}"; then
        
        # 进入应用目录并启动
        cd "${DOCKER_DIR}/${app_name}"
        
        if docker-compose up -d; then
            echo -e "${GREEN}${app_name} 安装成功！${NC}"
            echo -e "${YELLOW}安装路径: ${DOCKER_DIR}/${app_name}${NC}"
        else
            echo -e "${RED}${app_name} 启动失败！${NC}"
        fi
    else
        echo -e "${RED}下载 ${app_name} 配置文件失败！${NC}"
    fi
}

# 批量安装热门套餐
install_popular_stack() {
    echo -e "${YELLOW}选择热门套餐:${NC}"
    echo "1. 下载管理套餐 (qBittorrent + Transmission + Vertex)"
    echo "2. 媒体服务套餐 (Emby + Jellyfin + Tautulli)"
    echo "3. 自动化管理套餐 (MoviePilot + IyuuPlus + Sonarr + Radarr)"
    echo "4. 完整PT套餐 (包含下载、媒体、自动化)"
    echo "0. 返回"
    echo
    read -p "请选择套餐 [0-4]: " stack_choice
    
    case $stack_choice in
        1)
            echo -e "${BLUE}安装下载管理套餐...${NC}"
            install_app "qbittorrent" "qbittorrent.yml"
            install_app "transmission" "transmission.yml"
            install_app "vertex" "vertex.yml"
            ;;
        2)
            echo -e "${BLUE}安装媒体服务套餐...${NC}"
            install_app "emby" "emby.yml"
            install_app "jellyfin" "jellyfin.yml"
            install_app "tautulli" "tautulli.yml"
            ;;
        3)
            echo -e "${BLUE}安装自动化管理套餐...${NC}"
            install_app "moviepilot" "moviepilot.yml"
            install_app "iyuuplus" "iyuuplus.yml"
            install_app "sonarr" "sonarr.yml"
            install_app "radarr" "radarr.yml"
            ;;
        4)
            echo -e "${BLUE}安装完整PT套餐...${NC}"
            # 下载管理
            install_app "qbittorrent" "qbittorrent.yml"
            install_app "transmission" "transmission.yml"
            # 媒体服务
            install_app "emby" "emby.yml"
            # 自动化管理
            install_app "moviepilot" "moviepilot.yml"
            install_app "iyuuplus" "iyuuplus.yml"
            install_app "sonarr" "sonarr.yml"
            install_app "radarr" "radarr.yml"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择！${NC}"
            ;;
    esac
}

# 处理用户选择
handle_choice() {
    read -p "请输入应用序号 (支持多选，用空格分隔，如: 1 2 3): " choices
    
    if [[ -z "$choices" ]]; then
        echo -e "${RED}未选择任何应用！${NC}"
        return
    fi
    
    for choice in $choices; do
        case $choice in
            # 下载管理
            1) install_app "qbittorrent-4.3.8" "qbittorrent-4.3.8.yml" ;;
            2) install_app "qbittorrent-4.3.9" "qbittorrent-4.3.9.yml" ;;
            3) install_app "qbittorrent-4.6.7" "qbittorrent-4.6.7.yml" ;;
            4) install_app "qbittorrent-5.0.2" "qbittorrent-5.0.2.yml" ;;
            5) install_app "qbittorrent-latest" "qbittorrent-latest.yml" ;;
            6) install_app "transmission" "transmission.yml" ;;
            
            # 自动化管理
            7) install_app "iyuuplus" "iyuuplus.yml" ;;
            8) install_app "moviepilot" "moviepilot.yml" ;;
            9) install_app "vertex" "vertex.yml" ;;
            10) install_app "cross-seed" "cross-seed.yml" ;;
            11) install_app "reseedpuppy" "reseedpuppy.yml" ;;
            12) install_app "sonarr" "sonarr.yml" ;;
            13) install_app "radarr" "radarr.yml" ;;
            14) install_app "lidarr" "lidarr.yml" ;;
            15) install_app "prowlarr" "prowlarr.yml" ;;
            16) install_app "autobrr" "autobrr.yml" ;;
            17) install_app "bazarr" "bazarr.yml" ;;
            18) install_app "nastools" "nastools.yml" ;;
            19) install_app "ani-rss" "ani-rss.yml" ;;
            
            # 搜索工具
            20) install_app "jackett" "jackett.yml" ;;
            21) install_app "cloudsaver" "cloudsaver.yml" ;;
            
            # 媒体服务器
            22) install_app "emby" "emby.yml" ;;
            23) install_app "jellyfin" "jellyfin.yml" ;;
            24) install_app "plex" "plex.yml" ;;
            25) install_app "tautulli" "tautulli.yml" ;;
            26) install_app "ddns-go" "ddns-go.yml" ;;
            
            # 音频相关
            27) install_app "navidrome" "navidrome.yml" ;;
            28) install_app "airsonic" "airsonic.yml" ;;
            29) install_app "audiobookshelf" "audiobookshelf.yml" ;;
            30) install_app "music-tag" "music-tag.yml" ;;
            31) install_app "musictab" "musictab.yml" ;;
            
            # 电子书管理
            32) install_app "calibre-web" "calibre-web.yml" ;;
            33) install_app "komga" "komga.yml" ;;
            34) install_app "mango" "mango.yml" ;;
            
            # 文件管理与同步
            35) install_app "filebrowser" "filebrowser.yml" ;;
            36) install_app "clouddrive2" "clouddrive2.yml" ;;
            37) install_app "nextcloud" "nextcloud.yml" ;;
            38) install_app "syncthing" "syncthing.yml" ;;
            39) install_app "rclone" "rclone.yml" ;;
            
            # 字幕工具
            40) install_app "chinesesubfinder" "chinesesubfinder.yml" ;;
            41) install_app "bazarr" "bazarr.yml" ;;
            
            # 网络工具
            42) install_app "frps" "frps.yml" ;;
            43) install_app "frpc" "frpc.yml" ;;
            44) install_app "sakura" "sakura.yml" ;;
            45) install_app "v2raya" "v2raya.yml" ;;
            46) install_app "lucky" "lucky.yml" ;;
            47) install_app "nginx" "nginx.yml" ;;
            48) install_app "wireguard" "wireguard.yml" ;;
            49) install_app "duckdns" "duckdns.yml" ;;
            
            # Web管理面板
            50) install_app "homepage" "homepage.yml" ;;
            51) install_app "organizr" "organizr.yml" ;;
            52) install_app "webmin" "webmin.yml" ;;
            
            # 系统管理与监控
            53) install_app "watchtower" "watchtower.yml" ;;
            54) install_app "dockercopilot" "dockercopilot.yml" ;;
            55) install_app "netdata" "netdata.yml" ;;
            56) install_app "librespeed" "librespeed.yml" ;;
            57) install_app "quota" "quota.yml" ;;
            
            # 个人服务
            58) install_app "vaultwarden" "vaultwarden.yml" ;;
            59) install_app "memos" "memos.yml" ;;
            60) install_app "qiandao" "qiandao.yml" ;;
            61) install_app "cookiecloud" "cookiecloud.yml" ;;
            62) install_app "harvest" "harvest.yml" ;;
            63) install_app "ombi" "ombi.yml" ;;
            64) install_app "allinone" "allinone.yml" ;;
            
            # 9kg专区
            65) install_app "metatube" "metatube.yml" ;;
            66) install_app "byte-muse" "byte-muse.yml" ;;
            67) install_app "ikaros" "ikaros.yml" ;;
            
            # 特殊选项
            88) install_popular_stack ;;
            99) return ;;
            0) exit 0 ;;
            
            *)
                echo -e "${RED}无效选择: $choice${NC}"
                ;;
        esac
    done
}

# 主函数
main() {
    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker 未安装！请先安装 Docker。${NC}"
        exit 1
    fi
    
    # 检查docker-compose是否安装
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Docker Compose 未安装！请先安装 Docker Compose。${NC}"
        exit 1
    fi
    
    # 创建必要目录
    mkdir -p "$DOCKER_DIR"
    mkdir -p "$DOWNLOADS_DIR"
    mkdir -p "$CONFIG_DIR"
    
    while true; do
        show_menu
        handle_choice
        echo
        read -p "按回车键继续..." -r
    done
}

# 脚本入口
main "$@"
