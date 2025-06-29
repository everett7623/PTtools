#!/bin/bash

# PT Docker应用管理脚本
# 脚本名称: ptdocker.sh
# 脚本描述: PT相关Docker应用的安装和管理工具
# 脚本路径: https://raw.githubusercontent.com/everett7623/PTtools/main/config/ptdocker.sh
# 作者: Jensfrank
# 项目: PTtools
# 更新时间: 2025-06-29

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
CONFIG_DIR="/root/PTtools/config/docker-compose"

# 显示标题
show_title() {
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${WHITE}                       PTtools Docker应用安装脚本${NC}"
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${YELLOW}作者: Jensfrank  |  项目: PTtools  |  更新时间: 2025-06-29${NC}"
    echo -e "${YELLOW}安装目录: ${DOCKER_DIR}  |  下载目录: ${DOWNLOADS_DIR}${NC}"
    echo -e "${CYAN}==============================================================================${NC}"
    echo
}

# 显示应用菜单 - 4列优化布局
show_menu() {
    clear
    show_title
    
    # 四列布局显示菜单 - 优化间距，从上到下，一列一列排列
    echo -e "${YELLOW}▼下载管理                  ▼音频相关                  ▼网络工具                  ▼个人服务${NC}"
    echo -e "1. qBittorrent4.3.8🔥      20. Navidrome              39. FRP服务端               58. Vaultwarden🔥"
    echo -e "2. qBittorrent4.3.9🔥      21. Airsonic               40. FRP客户端               59. Memos🔥"
    echo -e "3. qBittorrent 4.6.7       22. AudioBookShelf🔥       41. Sakura🔥                60. Qiandao🔥"
    echo -e "4. qBittorrentLatest🔥      23. Music-Tag🔥            42. V2rayA                  61. CookieCloud🔥"
    echo -e "5. Transmission             24. MusicTab🔥             43. Lucky🔥                 62. Harvest🔥"
    echo -e "                                                       44. NPM🔥                   63. Ombi"
    echo -e "${YELLOW}▼自动化管理${NC}                ${YELLOW}▼电子书管理${NC}                ${YELLOW}45. WireGuard${NC}               ${YELLOW}64. AllInOne🔥${NC}"
    echo -e "6. iyuuplus🔥               25. Calibre-Web            46. DuckDNS                 "
    echo -e "7. MoviePilot🔥             26. Komga                                              ${YELLOW}▼9kg专区${NC}"
    echo -e "8. Vertex🔥                 27. Mango                  ${YELLOW}▼Web管理面板${NC}            65. MetaTube🔥"
    echo -e "9. Cross-Seed                                          47. Homepage🔥              66. Byte-Muse🔥"
    echo -e "10. ReseedPuppy             ${YELLOW}▼文件管理与同步${NC}            48. Organizr                67. Ikaros🔥"
    echo -e "11. Sonarr                  28. FileBrowser            49. Webmin                  "
    echo -e "12. Radarr                  29. AList🔥                                            "
    echo -e "13. Lidarr                  30. CloudDrive2🔥          ${YELLOW}▼系统管理与监控${NC}         "
    echo -e "14. Prowlarr                31. NextCloud              50. Watchtower🔥            "
    echo -e "15. AutoBrr                 32. Syncthing              51. DockerCopilot🔥         "
    echo -e "16. Bazarr                  33. Rclone                 52. Netdata🔥               "
    echo -e "17. NasTools🔥                                         53. LibreSpeed              "
    echo -e "18. Ani-RSS🔥               ${YELLOW}▼字幕工具${NC}                  54. Quota🔥                 "
    echo -e "                            34. ChineseSubFinder🔥                                 "
    echo -e "${YELLOW}▼搜索工具${NC}                                             ${YELLOW}▼媒体服务器${NC}             "
    echo -e "19. Jackett                                            55. Emby🔥                  "
    echo -e "20. CloudSaver🔥                                       56. Jellyfin🔥              "
    echo -e "                                                       57. Plex                    "
    echo -e "                                                       58. Tautulli                "
    echo
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${WHITE}特殊选项:${NC}"
    echo -e "${YELLOW}88. 批量安装热门套餐    99. 返回主菜单    0. 退出脚本${NC}"
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${WHITE}🔥 热门推荐应用    支持多选安装 (如: 1 2 3)${NC}"
    echo
}

# qBittorrent 4.3.8 特殊提示
show_qbt_438_notice() {
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${WHITE}          qBittorrent 4.3.8 安装提示${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo
    echo -e "${YELLOW}qBittorrent 4.3.8 需要使用原作者脚本安装${NC}"
    echo -e "${RED}请退出当前Docker安装脚本，回到主脚本进行安装${NC}"
    echo
    echo -e "${WHITE}安装步骤：${NC}"
    echo -e "${GREEN}1. 按 Ctrl+C 退出当前脚本${NC}"
    echo -e "${GREEN}2. 回到 pttools.sh 主脚本${NC}"
    echo -e "${GREEN}3. 选择 '1. qbittorrent 4.3.8' 进行安装${NC}"
    echo
    echo -e "${WHITE}主脚本运行命令：${NC}"
    echo -e "${BLUE}bash <(wget -qO- https://raw.githubusercontent.com/everett7623/pttools/main/pttools.sh)${NC}"
    echo
    echo -e "${CYAN}==================================================${NC}"
    read -p "$(echo -e ${YELLOW}按回车键返回菜单...${NC})" -r
}

# qBittorrent 4.3.9 特殊提示
show_qbt_439_notice() {
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${WHITE}          qBittorrent 4.3.9 安装提示${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo
    echo -e "${YELLOW}qBittorrent 4.3.9 需要使用原作者脚本安装${NC}"
    echo -e "${RED}请退出当前Docker安装脚本，回到主脚本进行安装${NC}"
    echo
    echo -e "${WHITE}安装步骤：${NC}"
    echo -e "${GREEN}1. 按 Ctrl+C 退出当前脚本${NC}"
    echo -e "${GREEN}2. 回到 pttools.sh 主脚本${NC}"
    echo -e "${GREEN}3. 选择 '2. qbittorrent 4.3.9' 进行安装${NC}"
    echo
    echo -e "${WHITE}主脚本运行命令：${NC}"
    echo -e "${BLUE}bash <(wget -qO- https://raw.githubusercontent.com/everett7623/pttools/main/pttools.sh)${NC}"
    echo
    echo -e "${CYAN}==================================================${NC}"
    read -p "$(echo -e ${YELLOW}按回车键返回菜单...${NC})" -r
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
        "https://raw.githubusercontent.com/everett7623/PTtools/main/config/docker-compose/${compose_file}"; then
        
        # 进入应用目录并启动
        cd "${DOCKER_DIR}/${app_name}" || exit
        
        if docker-compose up -d; then
            echo -e "${GREEN}✅ ${app_name} 安装成功！${NC}"
            echo -e "${YELLOW}安装路径: ${DOCKER_DIR}/${app_name}${NC}"
        else
            echo -e "${RED}❌ ${app_name} 启动失败！${NC}"
        fi
    else
        echo -e "${RED}❌ 下载 ${app_name} 配置文件失败！${NC}"
    fi
}

# 批量安装热门套餐
install_popular_stack() {
    echo -e "${YELLOW}选择热门套餐:${NC}"
    echo -e "${WHITE}1. 下载管理套餐${NC} (qBittorrent + Transmission + Vertex)"
    echo -e "${WHITE}2. 媒体服务套餐${NC} (Emby + Jellyfin + Tautulli)"
    echo -e "${WHITE}3. 自动化管理套餐${NC} (MoviePilot + IyuuPlus + Sonarr + Radarr)"
    echo -e "${WHITE}4. 完整PT套餐${NC} (包含下载、媒体、自动化)"
    echo -e "${WHITE}5. 热门推荐套餐${NC} (精选最受欢迎的应用)"
    echo -e "${RED}0. 返回${NC}"
    echo
    read -p "$(echo -e ${CYAN}请选择套餐 [0-5]: ${NC})" stack_choice
    
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
            # 监控管理
            install_app "homepage" "homepage.yml"
            install_app "watchtower" "watchtower.yml"
            ;;
        5)
            echo -e "${BLUE}安装热门推荐套餐...${NC}"
            install_app "qbittorrent" "qbittorrent.yml"
            install_app "moviepilot" "moviepilot.yml"
            install_app "iyuuplus" "iyuuplus.yml"
            install_app "emby" "emby.yml"
            install_app "homepage" "homepage.yml"
            install_app "vaultwarden" "vaultwarden.yml"
            install_app "watchtower" "watchtower.yml"
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
    read -p "$(echo -e ${CYAN}请输入应用序号 \(支持多选，用空格分隔，如: 1 2 3\): ${NC})" choices
    
    if [[ -z "$choices" ]]; then
        echo -e "${RED}未选择任何应用！${NC}"
        return
    fi
    
    for choice in $choices; do
        case $choice in
            # 下载管理
            1) show_qbt_438_notice ;;
            2) show_qbt_439_notice ;;
            3) install_app "qbittorrent-467" "qbittorrent-4.6.7.yml" ;;
            4) install_app "qbittorrent" "qbittorrent.yml" ;;
            5) install_app "transmission" "transmission.yml" ;;
            
            # 自动化管理
            6) install_app "iyuuplus" "iyuuplus.yml" ;;
            7) install_app "moviepilot" "moviepilot.yml" ;;
            8) install_app "vertex" "vertex.yml" ;;
            9) install_app "cross-seed" "cross-seed.yml" ;;
            10) install_app "reseedpuppy" "reseedpuppy.yml" ;;
            11) install_app "sonarr" "sonarr.yml" ;;
            12) install_app "radarr" "radarr.yml" ;;
            13) install_app "lidarr" "lidarr.yml" ;;
            14) install_app "prowlarr" "prowlarr.yml" ;;
            15) install_app "autobrr" "autobrr.yml" ;;
            16) install_app "bazarr" "bazarr.yml" ;;
            17) install_app "nastools" "nastools.yml" ;;
            18) install_app "ani-rss" "ani-rss.yml" ;;
            19) install_app "jackett" "jackett.yml" ;;
            20) install_app "cloudsaver" "cloudsaver.yml" ;;
            
            # 音频相关
            21) install_app "navidrome" "navidrome.yml" ;;
            22) install_app "airsonic" "airsonic.yml" ;;
            23) install_app "audiobookshelf" "audiobookshelf.yml" ;;
            24) install_app "music-tag" "music-tag.yml" ;;
            25) install_app "musictab" "musictab.yml" ;;
            
            # 电子书管理
            26) install_app "calibre-web" "calibre-web.yml" ;;
            27) install_app "komga" "komga.yml" ;;
            28) install_app "mango" "mango.yml" ;;
            
            # 文件管理与同步
            29) install_app "filebrowser" "filebrowser.yml" ;;
            30) install_app "alist" "alist.yml" ;;
            31) install_app "clouddrive2" "clouddrive2.yml" ;;
            32) install_app "nextcloud" "nextcloud.yml" ;;
            33) install_app "syncthing" "syncthing.yml" ;;
            34) install_app "rclone" "rclone.yml" ;;
            
            # 字幕工具
            35) install_app "chinesesubfinder" "chinesesubfinder.yml" ;;
            
            # 网络工具
            36) install_app "frps" "frps.yml" ;;
            37) install_app "frpc" "frpc.yml" ;;
            38) install_app "sakura" "sakura.yml" ;;
            39) install_app "v2raya" "v2raya.yml" ;;
            40) install_app "lucky" "lucky.yml" ;;
            41) install_app "npm" "npm.yml" ;;
            42) install_app "wireguard" "wireguard.yml" ;;
            43) install_app "duckdns" "duckdns.yml" ;;
            
            # Web管理面板
            44) install_app "homepage" "homepage.yml" ;;
            45) install_app "organizr" "organizr.yml" ;;
            46) install_app "webmin" "webmin.yml" ;;
            
            # 系统管理与监控
            47) install_app "watchtower" "watchtower.yml" ;;
            48) install_app "dockercopilot" "dockercopilot.yml" ;;
            49) install_app "netdata" "netdata.yml" ;;
            50) install_app "librespeed" "librespeed.yml" ;;
            51) install_app "quota" "quota.yml" ;;
            
            # 媒体服务器
            52) install_app "emby" "emby.yml" ;;
            53) install_app "jellyfin" "jellyfin.yml" ;;
            54) install_app "plex" "plex.yml" ;;
            55) install_app "tautulli" "tautulli.yml" ;;
            
            # 个人服务
            56) install_app "vaultwarden" "vaultwarden.yml" ;;
            57) install_app "memos" "memos.yml" ;;
            58) install_app "qiandao" "qiandao.yml" ;;
            59) install_app "cookiecloud" "cookiecloud.yml" ;;
            60) install_app "harvest" "harvest.yml" ;;
            61) install_app "ombi" "ombi.yml" ;;
            62) install_app "allinone" "allinone.yml" ;;
            
            # 9kg专区
            63) install_app "metatube" "metatube.yml" ;;
            64) install_app "byte-muse" "byte-muse.yml" ;;
            65) install_app "ikaros" "ikaros.yml" ;;
            
            # 特殊选项
            88) install_popular_stack ;;
            99) return ;;
            0) exit 0 ;;
            
            *)
                echo -e "${RED}❌ 无效选择: $choice${NC}"
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
        read -p "$(echo -e ${YELLOW}按回车键继续...${NC})" -r
    done
}

# 脚本入口
main "$@"
