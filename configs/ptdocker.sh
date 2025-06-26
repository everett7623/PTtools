#!/bin/bash

# PTtools Docker应用管理脚本
# 脚本名称: ptdocker.sh
# 脚本描述: PT Docker应用的分类选择安装管理
# 脚本路径: https://raw.githubusercontent.com/everett7623/PTtools/main/configs/ptdocker.sh
# 使用方法: bash ptdocker.sh
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
NC='\033[0m'

# 全局变量
DOCKER_DIR="/opt/docker"
DOWNLOADS_DIR="/opt/downloads"
GITHUB_RAW="https://raw.githubusercontent.com/everett7623/PTtools/main"

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                            🐳 PT Docker 应用管理中心                          ║${NC}"
    echo -e "${CYAN}║                                                                              ║${NC}"
    echo -e "${CYAN}║                     🎯 64+ 应用 | 🚀 一键安装 | 📊 分类管理                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# 显示PT应用菜单
show_pt_apps_menu() {
    show_banner
    
    # 使用多列布局显示应用
    echo -e "${GREEN}╭─────────────────────────────────── 📥 下载管理 ────────────────────────────────╮${NC}"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "1." "qBittorrent 4.3.8" "(原作者脚本)" \
           "2." "qBittorrent 4.3.9" "(原作者脚本)"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "3." "qBittorrent 4.6.7" "(Docker)🔥" \
           "4." "qBittorrent Latest" "(Docker)🆕"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} %-36s ${WHITE}│${NC}\n" \
           "5." "Transmission 4.0.5" "(Docker)" ""
    echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo
    
    echo -e "${GREEN}╭─────────────────────────────────── 🤖 自动化管理 ───────────────────────────────╮${NC}"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "6." "IYUUPlus🔥" "PT站点管理" \
           "7." "MoviePilot🔥" "影视自动化"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "8." "Vertex" "媒体管理" \
           "9." "Cross-Seed" "交叉做种"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "10." "ReseedPuppy🆕" "自动补种" \
           "11." "Sonarr🔥" "电视剧管理"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "12." "Radarr🔥" "电影管理" \
           "13." "Lidarr" "音乐管理"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "14." "Prowlarr🔥" "索引器管理" \
           "15." "AutoBRR" "自动抓取"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "16." "Bazarr" "字幕管理" \
           "17." "NASTools" "NAS工具"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} %-36s ${WHITE}│${NC}\n" \
           "18." "Ani-RSS🆕" "动漫RSS" ""
    echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo
    
    echo -e "${GREEN}╭─────────────────────────────────── 🔍 搜索 & 📺 媒体服务器 ──────────────────────╮${NC}"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "19." "Jackett🔥" "BT搜索聚合" \
           "20." "CloudSaver🆕" "TG网盘搜索"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "21." "Emby🔥" "媒体服务器" \
           "22." "Jellyfin🔥" "开源媒体服务器"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "23." "Plex" "媒体服务器" \
           "24." "Tautulli" "Plex监控"
    echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo
    
    echo -e "${GREEN}╭─────────────────────── 🎵 音频 & 📚 电子书 & 📁 文件管理 ───────────────────────╮${NC}"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "25." "Navidrome🔥" "音乐服务器" \
           "26." "Airsonic" "音乐流媒体"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "27." "AudioBookshelf" "有声书管理" \
           "28." "Music-Tag" "音乐标签"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "29." "MusicTab🆕" "音乐刮削" \
           "30." "Calibre-Web🔥" "电子书管理"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "31." "Komga" "漫画管理" \
           "32." "Mango" "漫画服务器"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "33." "FileBrowser🔥" "文件管理器" \
           "34." "AList🔥" "网盘列表"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "35." "CloudDrive2🆕" "云盘挂载" \
           "36." "NextCloud" "私有云"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "37." "SyncThing" "文件同步" \
           "38." "RClone" "云存储同步"
    echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo
    
    echo -e "${GREEN}╭────────────────────── 💬 字幕 & 🌐 网络 & 🎛️ 管理面板 ─────────────────────────╮${NC}"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "39." "ChineseSubFinder🔥" "中文字幕" \
           "40." "FRP" "内网穿透"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "41." "Sakura🆕" "内网穿透" \
           "42." "V2rayA" "代理工具"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "43." "Lucky🆕" "DDNS反代" \
           "44." "Nginx" "反向代理"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "45." "WireGuard" "VPN工具" \
           "46." "DuckDNS" "动态DNS"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "47." "Homepage🔥" "个人主页" \
           "48." "Organizr" "服务整合"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} %-36s ${WHITE}│${NC}\n" \
           "49." "Webmin" "系统管理" ""
    echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo
    
    echo -e "${GREEN}╭───────────── ⚙️ 系统监控 & 👤 个人服务 & 🔥 9kg专区 ──────────────╮${NC}"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "50." "Watchtower🔥" "容器更新" \
           "51." "DockerCopilot🆕" "Docker管理"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "52." "NetData🔥" "系统监控" \
           "53." "LibreSpeed" "网速测试"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "54." "Quota" "磁盘配额" \
           "55." "Vaultwarden🔥" "密码管理"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "56." "Memos🆕" "笔记服务" \
           "57." "Qiandao" "自动签到"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "58." "CookieCloud🆕" "Cookie同步" \
           "59." "Harvest" "系统监控"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "60." "Ombi" "媒体请求" \
           "61." "AllInOne🆕" "多功能集成"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC}\n" \
           "62." "MetaTube🔥" "元数据管理" \
           "63." "Byte-Muse🆕" "数据分析"
    printf "${WHITE}│${NC} ${BLUE}%-2s${NC} %-18s ${GRAY}%-15s${NC} ${WHITE}│${NC} %-36s ${WHITE}│${NC}\n" \
           "64." "Ikaros🔥" "刮削小姐姐" ""
    echo -e "${GREEN}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo
    
    echo -e "${YELLOW}╭─────────────────────────────── 🚀 快捷操作 ───────────────────────────────╮${NC}"
    printf "${YELLOW}│${NC} ${PURPLE}%-3s${NC} %-25s ${YELLOW}│${NC} ${PURPLE}%-3s${NC} %-25s ${YELLOW}│${NC}\n" \
           "88." "🎯 批量安装 (1 2 3 4)" \
           "99." "📊 查看已安装应用"
    printf "${YELLOW}│${NC} ${PURPLE}%-3s${NC} %-25s ${YELLOW}│${NC} ${WHITE}%-29s${NC} ${YELLOW}│${NC}\n" \
           "0." "🏠 返回主菜单" ""
    echo -e "${YELLOW}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo
    
    echo -e "${BLUE}💡 使用说明：${NC}"
    echo -e "${GRAY}   🔥 = 热门推荐  🆕 = 新增应用  📦 = Docker应用  ⚡ = 原作者脚本${NC}"
    echo -e "${GRAY}   单选: 输入序号 (如: 21)  批量: 空格分隔 (如: 21 22 25)  范围: 连字符 (如: 21-25)${NC}"
    echo
}

# PT Docker应用管理主循环
main() {
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}检测到未安装Docker，大部分应用需要Docker支持${NC}"
        echo -e "${YELLOW}是否现在安装Docker？[Y/n]: ${NC}"
        read -r install_docker_choice
        install_docker_choice=${install_docker_choice:-Y}
        
        if [[ $install_docker_choice =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}正在安装Docker...${NC}"
            install_docker_func
        fi
    fi
    
    while true; do
        show_pt_apps_menu
        read -p "请输入选项: " choice
        
        case $choice in
            0)
                echo -e "${GREEN}返回主菜单...${NC}"
                exit 0
                ;;
            88)
                batch_install_apps
                ;;
            99)
                show_installed_apps
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -le 64 ]]; then
                    handle_single_app "$choice"
                else
                    echo -e "${RED}❌ 无效选项，请输入1-64的数字或特殊选项${NC}"
                    echo -e "${YELLOW}按任意键继续...${NC}"
                    read -n 1
                fi
                ;;
        esac
    done
}

# 处理单个应用安装
handle_single_app() {
    local choice="$1"
    echo -e "${CYAN}正在处理应用 $choice...${NC}"
    echo -e "${YELLOW}功能开发中，请等待后续更新${NC}"
    echo -e "${YELLOW}按任意键返回...${NC}"
    read -n 1
}

# 批量安装应用
batch_install_apps() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                              🎯 批量安装PT应用                               ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -e "${YELLOW}📝 请输入要安装的应用序号：${NC}"
    echo -e "${BLUE}   支持格式：${NC}"
    echo -e "${WHITE}   • 空格分隔: ${GREEN}21 22 25 33${NC} (安装Emby、Jellyfin、Navidrome、FileBrowser)"
    echo -e "${WHITE}   • 连续范围: ${GREEN}21-25${NC} (安装序号21到25的所有应用)"
    echo -e "${WHITE}   • 混合格式: ${GREEN}21 22 30-35 50${NC} (混合使用)"
    echo -e "${WHITE}   • 全部安装: ${GREEN}all${NC} (安装所有Docker应用 3-64)"
    echo
    echo -e "${GRAY}   💡 提示: 序号1-2为原作者脚本，建议单独安装${NC}"
    echo
    
    read -p "应用序号: " app_numbers
    
    if [[ -z "$app_numbers" ]]; then
        echo -e "${YELLOW}❌ 未输入任何序号${NC}"
        echo -e "${YELLOW}按任意键返回...${NC}"
        read -n 1
        return
    fi
    
    echo -e "${BLUE}📊 正在解析输入...${NC}"
    echo -e "${YELLOW}批量安装功能开发中${NC}"
    echo -e "${YELLOW}按任意键返回...${NC}"
    read -n 1
}

# 显示已安装应用
show_installed_apps() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                              📊 已安装应用状态                               ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker未安装，无法检查Docker应用${NC}"
        echo -e "${YELLOW}按任意键返回...${NC}"
        read -n 1
        return
    fi
    
    echo -e "${YELLOW}检查已安装应用功能开发中${NC}"
    echo -e "${YELLOW}按任意键返回...${NC}"
    read -n 1
}

# 安装Docker（简化版本）
install_docker_func() {
    echo -e "${YELLOW}Docker安装功能请返回主菜单使用${NC}"
    echo -e "${YELLOW}按任意键继续...${NC}"
    read -n 1
}

# 运行主程序
main