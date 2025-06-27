#!/bin/bash

# PTtools Docker应用菜单
# 脚本名称: ptdocker.sh
# 脚本描述: PT Docker应用一键安装管理脚本
# 脚本路径: https://raw.githubusercontent.com/everett7623/PTtools/main/configs/ptdocker.sh
# 作者: Jensfrank
# Github: https://github.com/everett7623/PTtools
# 更新时间: 2025-06-27

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
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    echo -e -n "${GREEN}请输入要安装的应用序号 (多选用空格分隔，0返回): ${NC}"
}

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

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
