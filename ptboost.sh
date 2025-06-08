#!/bin/bash

# PTBoost - qBittorrent性能优化脚本
# 专为qBittorrent刷流优化设计
# Github: https://github.com/everett7623/PTtools
# 作者: everett7623

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 全局变量
QB_CONFIG_DIR="/home/qbittorrent/.config/qBittorrent"
QB_DATA_DIR="/home/qbittorrent/.local/share/data/qBittorrent"
DOWNLOAD_DIR="/home/qbittorrent/Downloads"

# 日志函数
log_info() {
    echo -e "${GREEN}[PTBOOST]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[PTBOOST]${NC} $1"
}

log_error() {
    echo -e "${RED}[PTBOOST]${NC} $1"
}

# 检查qBittorrent是否已安装
check_qbittorrent() {
    if ! command -v qbittorrent-nox &> /dev/null; then
        log_error "qBittorrent未安装，请先安装qBittorrent"
        exit 1
    fi
    
    if [ ! -d "$QB_CONFIG_DIR" ]; then
        log_error "qBittorrent配置目录不存在"
        exit 1
    fi
    
    log_info "检测到qBittorrent，开始应用PTBoost优化..."
}

# 停止qBittorrent服务
stop_qbittorrent() {
    log_info "停止qBittorrent服务..."
    systemctl stop qbittorrent 2>/dev/null
    sleep 2
}

# 启动qBittorrent服务
start_qbittorrent() {
    log_info "启动qBittorrent服务..."
    systemctl start qbittorrent
    sleep 3
    
    if systemctl is-active --quiet qbittorrent; then
        log_info "qBittorrent服务启动成功"
    else
        log_error "qBittorrent服务启动失败"
        systemctl status qbittorrent
    fi
}

# 备份原始配置
backup_config() {
    log_info "备份原始配置..."
    
    if [ -f "$QB_CONFIG_DIR/qBittorrent.conf" ]; then
        cp "$QB_CONFIG_DIR/qBittorrent.conf" "$QB_CONFIG_DIR/qBittorrent.conf.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "配置文件已备份"
    fi
}

# 生成PTBoost优化配置
generate_ptboost_config() {
    log_info "生成PTBoost性能优化配置..."
    
    # 获取服务器IP和随机端口
    SERVER_IP=$(curl -s ip.sb 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "127.0.0.1")
    RANDOM_PORT=$((RANDOM % 55000 + 10000))
    
    # 检测可用内存并设置缓存
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$TOTAL_MEM" -ge 8192 ]; then
        DISK_CACHE=512  # 8GB+ 内存
        CONNECTION_LIMIT=800
        TORRENT_LIMIT=300
    elif [ "$TOTAL_MEM" -ge 4096 ]; then
        DISK_CACHE=256  # 4-8GB 内存
        CONNECTION_LIMIT=600
        TORRENT_LIMIT=200
    elif [ "$TOTAL_MEM" -ge 2048 ]; then
        DISK_CACHE=128  # 2-4GB 内存
        CONNECTION_LIMIT=400
        TORRENT_LIMIT=150
    else
        DISK_CACHE=64   # <2GB 内存
        CONNECTION_LIMIT=200
        TORRENT_LIMIT=100
    fi
    
    log_info "检测到内存: ${TOTAL_MEM}MB，设置磁盘缓存: ${DISK_CACHE}MB"
    
    # 生成高度优化的qBittorrent配置
    cat > "$QB_CONFIG_DIR/qBittorrent.conf" << EOF
[Application]
FileLogger\\Enabled=true
FileLogger\\Age=1
FileLogger\\MaxSizeBytes=66560
FileLogger\\Path=$QB_DATA_DIR

[AutoRun]
OnTorrentAdded\\Enabled=false
OnTorrentAdded\\Program=
OnTorrentFinished\\Enabled=false
OnTorrentFinished\\Program=

[BitTorrent]
Session\\DefaultSavePath=$DOWNLOAD_DIR
Session\\Port=$RANDOM_PORT
Session\\TempPath=$DOWNLOAD_DIR/incomplete
Session\\TempPathEnabled=true
Session\\AddExtensionToIncompleteFiles=true
Session\\Preallocation=true
Session\\UseAlternativeGlobalSpeedLimit=false
Session\\GlobalMaxRatio=0
Session\\GlobalMaxSeedingMinutes=-1
Session\\MaxConnections=$CONNECTION_LIMIT
Session\\MaxConnectionsPerTorrent=100
Session\\MaxUploads=50
Session\\MaxUploadsPerTorrent=10
Session\\GlobalDLSpeedLimit=0
Session\\GlobalUPSpeedLimit=0
Session\\AlternativeGlobalDLSpeedLimit=0
Session\\AlternativeGlobalUPSpeedLimit=0
Session\\UseAlternativeGlobalSpeedLimit=false
Session\\BTProtocol=Both
Session\\CreateTorrentSubfolder=false
Session\\DisableAutoTMMByDefault=false
Session\\DisableAutoTMMTriggers\\CategorySavePathChanged=false
Session\\DisableAutoTMMTriggers\\DefaultSavePathChanged=false
Session\\GlobalMaxSeedingMinutes=-1
Session\\QueueingSystemEnabled=true
Session\\MaxActiveDownloads=10
Session\\MaxActiveTorrents=$TORRENT_LIMIT
Session\\MaxActiveUploads=20
Session\\IgnoreSlowTorrentsForQueueing=true
Session\\SlowTorrentsDownloadRate=2
Session\\SlowTorrentsUploadRate=2
Session\\SlowTorrentsInactivityTimer=60
Session\\OutgoingPortsMin=1024
Session\\OutgoingPortsMax=65535
Session\\UPnP=false
Session\\PeXEnabled=true
Session\\LSDEnabled=true
Session\\DHTEnabled=true
Session\\AnonymousModeEnabled=false
Session\\Encryption=1
Session\\ForceProxy=false
Session\\ProxyOnlyForTorrents=false
Session\\AnnounceToAllTrackers=true
Session\\AnnounceToAllTiers=true
Session\\AsyncIOThreadsCount=8
Session\\CheckingMemUsageSize=$DISK_CACHE
Session\\FilePoolSize=5000
Session\\GuidedReadCache=true
Session\\MultiConnectionsPerIp=true
Session\\SendBufferWatermark=500
Session\\SendBufferLowWatermark=10
Session\\SendBufferWatermarkFactor=50
Session\\SocketBacklogSize=30
Session\\UploadSlotsBehavior=0
Session\\UploadChokingAlgorithm=1
Session\\AnnounceTorrentAdded=true
Session\\AnnounceTrackerError=true
Session\\EnableCoalesceReads=true
Session\\EnableCoalesceWrites=true
Session\\EnableEmbeddedTracker=false
Session\\EnableFastResume=true
Session\\EnableMultiConnectionsFromSameIP=true
Session\\EnableOSCache=true
Session\\EnablePieceExtentAffinity=false
Session\\EnableUploadSuggestions=false
Session\\SaveResumeDataInterval=60
Session\\SendRedundantRequests=true
Session\\MaxConcurrentHTTPAnnounces=50
Session\\StopTrackerTimeout=5
Session\\PeerTurnover=4
Session\\PeerTurnoverCutoff=90
Session\\PeerTurnoverInterval=300
Session\\RequestQueueSize=500

[Core]
AutoDeleteAddedTorrentFile=Never

[Meta]
MigrationVersion=4

[Network]
Cookies=@Invalid()
Proxy\\OnlyForTorrents=false

[Preferences]
Advanced\\AnnounceToAllTrackers=true
Advanced\\AnnounceToAllTiers=true
Advanced\\AnonymousModeEnabled=false
Advanced\\AsyncIOThreadsCount=8
Advanced\\CheckingMemUsageSize=$DISK_CACHE
Advanced\\FilePoolSize=5000
Advanced\\GuidedReadCache=true
Advanced\\IgnoreSlowTorrentsForQueueing=true
Advanced\\MultiConnectionsPerIp=true
Advanced\\OutgoingPortsMax=65535
Advanced\\OutgoingPortsMin=1024
Advanced\\RecheckCompletedTorrents=false
Advanced\\SendBufferWatermark=500
Advanced\\SendBufferLowWatermark=10
Advanced\\SendBufferWatermarkFactor=50
Advanced\\SlowTorrentsDownloadRate=2
Advanced\\SlowTorrentsInactivityTimer=60
Advanced\\SlowTorrentsUploadRate=2
Advanced\\SocketBacklogSize=30
Advanced\\SuperSeedingEnabled=false
Advanced\\UploadChokingAlgorithm=1
Advanced\\UploadSlotsBehavior=0
Advanced\\EnableCoalesceReads=true
Advanced\\EnableCoalesceWrites=true
Advanced\\EnableEmbeddedTracker=false
Advanced\\EnableMultiConnectionsFromSameIP=true
Advanced\\EnableOSCache=true
Advanced\\EnablePieceExtentAffinity=false
Advanced\\EnableUploadSuggestions=false
Advanced\\MaxConcurrentHTTPAnnounces=50
Advanced\\PeerTurnover=4
Advanced\\PeerTurnoverCutoff=90
Advanced\\PeerTurnoverInterval=300
Advanced\\RequestQueueSize=500
Advanced\\SaveResumeDataInterval=60
Advanced\\SendRedundantRequests=true
Advanced\\StopTrackerTimeout=5
Bittorrent\\AddTrackers=false
Bittorrent\\DHT=true
Bittorrent\\Encryption=1
Bittorrent\\LSD=true
Bittorrent\\MaxConnections=$CONNECTION_LIMIT
Bittorrent\\MaxConnectionsPerTorrent=100
Bittorrent\\MaxRatio=0
Bittorrent\\MaxRatioAction=0
Bittorrent\\MaxUploads=50
Bittorrent\\MaxUploadsPerTorrent=10
Bittorrent\\PeX=true
Bittorrent\\Port=$RANDOM_PORT
Bittorrent\\SameTorrentThrottling=false
Connection\\GlobalDLLimitAlt=0
Connection\\GlobalDLLimit=0
Connection\\GlobalUPLimitAlt=0
Connection\\GlobalUPLimit=0
Connection\\PortRangeMin=$RANDOM_PORT
Connection\\PortRangeMax=$RANDOM_PORT
Connection\\UPnP=false
Connection\\ResolvePeerCountries=false
Connection\\ResolvePeerHostNames=false
Downloads\\DiskWriteCacheSize=-1
Downloads\\DiskWriteCacheTTL=60
Downloads\\FinishedTorrentExportDir=
Downloads\\PreallocateAll=true
Downloads\\SavePath=$DOWNLOAD_DIR
Downloads\\SaveResumeDataInterval=60
Downloads\\ScanDirs\\1\\enabled=true
Downloads\\ScanDirs\\1\\path=$DOWNLOAD_DIR/../watch
Downloads\\ScanDirs\\size=1
Downloads\\StartInPause=false
Downloads\\TempPath=$DOWNLOAD_DIR/incomplete
Downloads\\TempPathEnabled=true
Downloads\\TorrentExportDir=
Downloads\\UseIncompleteExtension=true
DynDNS\\DomainName=changeme.dyndns.org
DynDNS\\Enabled=false
DynDNS\\Password=
DynDNS\\Service=0
DynDNS\\Username=
General\\AlternatingRowColors=true
General\\CloseToTray=true
General\\CloseToTrayNotified=true
General\\CustomUITheme=
General\\DeleteTorrentFilesAsDefault=false
General\\ExitConfirm=true
General\\HideZeroComboValues=0
General\\HideZeroValues=false
General\\Locale=
General\\MinimizeToTray=false
General\\NoSplashScreen=true
General\\PreventFromSuspendWhenDownloading=false
General\\PreventFromSuspendWhenSeeding=false
General\\StartMinimized=false
General\\SystrayEnabled=true
General\\UseSystemIconTheme=true
MailNotification\\email=
MailNotification\\enabled=false
MailNotification\\password=
MailNotification\\req_auth=true
MailNotification\\req_ssl=false
MailNotification\\sender=qBittorrent_notification@example.com
MailNotification\\smtp_server=smtp.changeme.com
MailNotification\\smtp_server_port=465
MailNotification\\username=
Queueing\\IgnoreSlowTorrents=true
Queueing\\MaxActiveDownloads=10
Queueing\\MaxActiveTorrents=$TORRENT_LIMIT
Queueing\\MaxActiveUploads=20
Queueing\\QueueingEnabled=true
RSS\\AutoDownloader\\DownloadRepacks=true
RSS\\AutoDownloader\\SmartEpisodeFilter=s(\\d+)e(\\d+), (\\d+)x(\\d+), "(\\d{4}[.\\-]\\d{1,2}[.\\-]\\d{1,2})", "(\\d{1,2}[.\\-]\\d{1,2}[.\\-]\\d{4})"
RSS\\RefreshInterval=30
Schedule\\days=EveryDay
Schedule\\end_time=@Variant(\\0\\0\\0\\xf\\x4J\\xa2\\0)
Schedule\\start_time=@Variant(\\0\\0\\0\\xf\\x1\\xb7t\\0)
WebUI\\Address=*
WebUI\\AlternativeUIEnabled=false
WebUI\\AuthSubnetWhitelist=
WebUI\\AuthSubnetWhitelistEnabled=false
WebUI\\BanDuration=3600
WebUI\\CSRFProtection=false
WebUI\\ClickjackingProtection=false
WebUI\\CustomHTTPHeaders=
WebUI\\CustomHTTPHeadersEnabled=false
WebUI\\HTTPS\\CertificatePath=
WebUI\\HTTPS\\Enabled=false
WebUI\\HTTPS\\KeyPath=
WebUI\\HostHeaderValidation=false
WebUI\\LocalHostAuth=false
WebUI\\MaxAuthenticationFailureCount=5
WebUI\\Port=8080
WebUI\\RootFolder=
WebUI\\SecureCookie=true
WebUI\\ServerDomains=*
WebUI\\SessionTimeout=3600
WebUI\\TrustedReverseProxiesList=
WebUI\\UseUPnP=false
WebUI\\Username=admin
WebUI\\Password_PBKDF2="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)"
EOF

    # 设置配置文件权限
    chown qbittorrent:qbittorrent "$QB_CONFIG_DIR/qBittorrent.conf"
    chmod 600 "$QB_CONFIG_DIR/qBittorrent.conf"
    
    log_info "PTBoost配置已生成 (端口: $RANDOM_PORT)"
}

# 应用磁盘I/O优化
optimize_disk_io() {
    log_info "应用磁盘I/O优化..."
    
    # 检测下载目录所在的磁盘
    DISK_DEVICE=$(df "$DOWNLOAD_DIR" | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
    
    if [ ! -z "$DISK_DEVICE" ]; then
        # 设置I/O调度器为deadline或mq-deadline (适合SSD)
        if [ -f "/sys/block/$(basename $DISK_DEVICE)/queue/scheduler" ]; then
            echo mq-deadline > "/sys/block/$(basename $DISK_DEVICE)/queue/scheduler" 2>/dev/null || \
            echo deadline > "/sys/block/$(basename $DISK_DEVICE)/queue/scheduler" 2>/dev/null
            log_info "I/O调度器已优化"
        fi
        
        # 优化读前瞻
        echo 4096 > "/sys/block/$(basename $DISK_DEVICE)/queue/read_ahead_kb" 2>/dev/null
    fi
    
    # 创建磁盘优化脚本
    cat > /etc/init.d/ptboost-disk-optimize << 'EOF'
#!/bin/bash
# PTBoost磁盘优化脚本

case "$1" in
    start)
        # 优化所有磁盘的I/O
        for disk in /sys/block/sd*; do
            if [ -d "$disk" ]; then
                disk_name=$(basename "$disk")
                # 设置I/O调度器
                echo mq-deadline > "/sys/block/$disk_name/queue/scheduler" 2>/dev/null || \
                echo deadline > "/sys/block/$disk_name/queue/scheduler" 2>/dev/null
                # 设置读前瞻
                echo 4096 > "/sys/block/$disk_name/queue/read_ahead_kb" 2>/dev/null
                # 禁用NCQ (某些情况下可能有帮助)
                echo 1 > "/sys/block/$disk_name/queue/nomerges" 2>/dev/null
            fi
        done
        ;;
esac
EOF

    chmod +x /etc/init.d/ptboost-disk-optimize
    
    # 在系统启动时运行优化
    if command -v systemctl &> /dev/null; then
        cat > /etc/systemd/system/ptboost-disk-optimize.service << EOF
[Unit]
Description=PTBoost Disk I/O Optimization
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/etc/init.d/ptboost-disk-optimize start
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        systemctl enable ptboost-disk-optimize.service
    fi
}

# 创建PTBoost监控脚本
create_monitoring_script() {
    log_info "创建PTBoost性能监控脚本..."
    
    cat > /usr/local/bin/ptboost-monitor << 'EOF'
#!/bin/bash

# PTBoost性能监控脚本
# 显示qBittorrent和系统的性能指标

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    PTBoost 性能监控                         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo

# qBittorrent状态
if systemctl is-active --quiet qbittorrent; then
    echo -e "${GREEN}✓${NC} qBittorrent: 运行中"
else
    echo -e "${RED}✗${NC} qBittorrent: 停止"
fi

# 系统负载
echo -e "${BLUE}📊 系统负载:${NC}"
uptime

# 内存使用
echo -e "${BLUE}💾 内存使用:${NC}"
free -h

# 磁盘I/O
echo -e "${BLUE}💿 磁盘I/O:${NC}"
iostat -d 1 1 2>/dev/null | tail -n +4 | head -10

# 网络连接数
echo -e "${BLUE}🌐 网络连接:${NC}"
CONNECTIONS=$(ss -ant | grep -c ESTAB)
echo "活跃连接数: $CONNECTIONS"

# qBittorrent进程信息
if pgrep qbittorrent-nox > /dev/null; then
    echo -e "${BLUE}🔧 qBittorrent进程:${NC}"
    ps aux | grep qbittorrent-nox | grep -v grep | awk '{printf "CPU: %s%%, MEM: %s%%, PID: %s\n", $3, $4, $2}'
fi

# TCP连接状态
echo -e "${BLUE}📡 TCP连接状态:${NC}"
ss -ant | awk '{print $1}' | sort | uniq -c | sort -nr

echo
echo -e "${YELLOW}提示: 使用 'watch -n 5 ptboost-monitor' 实时监控${NC}"
EOF

    chmod +x /usr/local/bin/ptboost-monitor
    log_info "监控脚本已创建: ptboost-monitor"
}

# 创建PTBoost管理脚本
create_management_script() {
    log_info "创建PTBoost管理脚本..."
    
    cat > /usr/local/bin/ptboost-manage << 'EOF'
#!/bin/bash

# PTBoost管理脚本
# 提供qBittorrent的高级管理功能

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

QB_CONFIG="/home/qbittorrent/.config/qBittorrent/qBittorrent.conf"

show_menu() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    PTBoost 管理工具                         ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${WHITE}选择操作:${NC}"
    echo -e "${GREEN}1.${NC} 重启qBittorrent服务"
    echo -e "${GREEN}2.${NC} 查看服务状态"
    echo -e "${GREEN}3.${NC} 查看实时日志"
    echo -e "${GREEN}4.${NC} 性能监控"
    echo -e "${GREEN}5.${NC} 备份配置"
    echo -e "${GREEN}6.${NC} 恢复配置"
    echo -e "${GREEN}7.${NC} 清理缓存"
    echo -e "${GREEN}8.${NC} 网络测试"
    echo -e "${RED}0.${NC} 退出"
    echo
}

restart_service() {
    echo -e "${BLUE}重启qBittorrent服务...${NC}"
    systemctl restart qbittorrent
    sleep 3
    if systemctl is-active --quiet qbittorrent; then
        echo -e "${GREEN}✓ 服务重启成功${NC}"
    else
        echo -e "${RED}✗ 服务重启失败${NC}"
    fi
}

show_status() {
    echo -e "${BLUE}qBittorrent服务状态:${NC}"
    systemctl status qbittorrent --no-pager
}

show_logs() {
    echo -e "${BLUE}实时日志 (按Ctrl+C退出):${NC}"
    journalctl -u qbittorrent -f
}

performance_monitor() {
    ptboost-monitor
}

backup_config() {
    if [ -f "$QB_CONFIG" ]; then
        backup_file="$QB_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$QB_CONFIG" "$backup_file"
        echo -e "${GREEN}✓ 配置已备份到: $backup_file${NC}"
    else
        echo -e "${RED}✗ 配置文件不存在${NC}"
    fi
}

restore_config() {
    echo -e "${YELLOW}可用的备份文件:${NC}"
    ls -la /home/qbittorrent/.config/qBittorrent/qBittorrent.conf.backup.* 2>/dev/null | nl
    echo
    read -p "请输入要恢复的备份文件编号: " choice
    
    backup_file=$(ls /home/qbittorrent/.config/qBittorrent/qBittorrent.conf.backup.* 2>/dev/null | sed -n "${choice}p")
    
    if [ -f "$backup_file" ]; then
        systemctl stop qbittorrent
        cp "$backup_file" "$QB_CONFIG"
        chown qbittorrent:qbittorrent "$QB_CONFIG"
        systemctl start qbittorrent
        echo -e "${GREEN}✓ 配置已恢复${NC}"
    else
        echo -e "${RED}✗ 备份文件不存在${NC}"
    fi
}

clear_cache() {
    echo -e "${BLUE}清理qBittorrent缓存...${NC}"
    systemctl stop qbittorrent
    rm -rf /home/qbittorrent/.local/share/data/qBittorrent/logs/*
    rm -rf /home/qbittorrent/.cache/qBittorrent/*
    systemctl start qbittorrent
    echo -e "${GREEN}✓ 缓存清理完成${NC}"
}

network_test() {
    echo -e "${BLUE}网络性能测试:${NC}"
    echo
    echo "1. 测试网络连接性..."
    ping -c 4 8.8.8.8
    echo
    echo "2. 测试TCP连接数..."
    ss -s
    echo
    echo "3. 测试端口监听..."
    ss -tlnp | grep :8080
}

while true; do
    show_menu
    read -p "请选择 [0-8]: " choice
    
    case $choice in
        1) restart_service ;;
        2) show_status ;;
        3) show_logs ;;
        4) performance_monitor ;;
        5) backup_config ;;
        6) restore_config ;;
        7) clear_cache ;;
        8) network_test ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac
    
    if [ "$choice" != "3" ] && [ "$choice" != "4" ]; then
        read -p "按回车键继续..."
    fi
done
EOF

    chmod +x /usr/local/bin/ptboost-manage
    log_info "管理脚本已创建: ptboost-manage"
}

# 应用高级网络优化
apply_advanced_network_optimization() {
    log_info "应用高级网络优化..."
    
    # 增强型网络参数
    cat >> /etc/sysctl.d/99-pttools-optimization.conf << EOF

# PTBoost高级网络优化
net.core.somaxconn = 65535
net.core.netdev_budget = 600
net.core.netdev_max_backlog = 10000
net.ipv4.tcp_max_orphans = 65536
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_moderate_rcvbuf = 1
EOF

    sysctl -p /etc/sysctl.d/99-pttools-optimization.conf
}

# 创建性能调优脚本
create_performance_tuning() {
    log_info "创建性能调优脚本..."
    
    cat > /usr/local/bin/ptboost-tune << 'EOF'
#!/bin/bash

# PTBoost性能调优脚本
# 根据当前系统负载动态调整参数

QB_CONFIG="/home/qbittorrent/.config/qBittorrent/qBittorrent.conf"

# 获取当前系统状态
CPU_CORES=$(nproc)
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

echo "系统信息:"
echo "CPU核心数: $CPU_CORES"
echo "总内存: ${TOTAL_MEM}MB"
echo "可用内存: ${AVAILABLE_MEM}MB"
echo "负载均值: $LOAD_AVG"

# 根据负载调整连接数
if (( $(echo "$LOAD_AVG > 2.0" | bc -l) )); then
    MAX_CONNECTIONS=300
    echo "高负载模式: 降低连接数到 $MAX_CONNECTIONS"
elif (( $(echo "$LOAD_AVG > 1.0" | bc -l) )); then
    MAX_CONNECTIONS=500
    echo "中等负载模式: 设置连接数为 $MAX_CONNECTIONS"
else
    MAX_CONNECTIONS=800
    echo "低负载模式: 设置连接数为 $MAX_CONNECTIONS"
fi

# 根据内存调整缓存
if [ "$AVAILABLE_MEM" -lt 1024 ]; then
    CACHE_SIZE=32
    echo "内存紧张: 设置缓存为 ${CACHE_SIZE}MB"
elif [ "$AVAILABLE_MEM" -lt 2048 ]; then
    CACHE_SIZE=64
    echo "内存适中: 设置缓存为 ${CACHE_SIZE}MB"
else
    CACHE_SIZE=128
    echo "内存充足: 设置缓存为 ${CACHE_SIZE}MB"
fi

# 应用调优参数
if [ -f "$QB_CONFIG" ]; then
    systemctl stop qbittorrent
    sed -i "s/Session\\\\MaxConnections=.*/Session\\\\MaxConnections=$MAX_CONNECTIONS/" "$QB_CONFIG"
    sed -i "s/Advanced\\\\CheckingMemUsageSize=.*/Advanced\\\\CheckingMemUsageSize=$CACHE_SIZE/" "$QB_CONFIG"
    systemctl start qbittorrent
    echo "调优完成！"
else
    echo "配置文件不存在！"
fi
EOF

    chmod +x /usr/local/bin/ptboost-tune
    log_info "性能调优脚本已创建: ptboost-tune"
}

# 设置定时任务
setup_cron_jobs() {
    log_info "设置定时维护任务..."
    
    # 创建cron任务
    cat > /etc/cron.d/ptboost-maintenance << EOF
# PTBoost维护任务

# 每小时进行性能调优
0 * * * * root /usr/local/bin/ptboost-tune >/dev/null 2>&1

# 每天凌晨2点清理日志
0 2 * * * root find /home/qbittorrent/.local/share/data/qBittorrent/logs -name "*.log" -mtime +7 -delete >/dev/null 2>&1

# 每周重启qBittorrent服务
0 3 * * 0 root systemctl restart qbittorrent >/dev/null 2>&1
EOF

    chmod 644 /etc/cron.d/ptboost-maintenance
    log_info "定时维护任务已设置"
}

# 主函数
main() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    PTBoost 性能优化器                       ║${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}║    🚀 极致性能优化  ⚡ 智能参数调优  📊 实时监控           ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${WHITE}PTBoost将为您的qBittorrent进行以下优化:${NC}"
    echo -e "  🔧 高级配置参数优化"
    echo -e "  💾 内存和磁盘缓存优化"
    echo -e "  🌐 网络连接数优化"
    echo -e "  📁 磁盘I/O性能优化"
    echo -e "  📊 性能监控工具"
    echo -e "  🤖 智能调优脚本"
    echo -e "  ⏰ 自动维护任务"
    echo
    read -p "按回车键开始PTBoost优化..."
    
    # 执行优化步骤
    check_qbittorrent
    backup_config
    stop_qbittorrent
    generate_ptboost_config
    optimize_disk_io
    apply_advanced_network_optimization
    create_monitoring_script
    create_management_script
    create_performance_tuning
    setup_cron_jobs
    start_qbittorrent
    
    # 显示完成信息
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  🎉 PTBoost优化完成！                       ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}🎯 优化结果:${NC}"
    echo -e "  ✅ qBittorrent配置已优化"
    echo -e "  ✅ 系统性能已调优"
    echo -e "  ✅ 监控工具已安装"
    echo -e "  ✅ 自动维护已启用"
    echo
    echo -e "${CYAN}🛠️  管理工具:${NC}"
    echo -e "  📊 性能监控: ${WHITE}ptboost-monitor${NC}"
    echo -e "  🔧 服务管理: ${WHITE}ptboost-manage${NC}"
    echo -e "  ⚡ 性能调优: ${WHITE}ptboost-tune${NC}"
    echo
    echo -e "${YELLOW}💡 建议在高峰时段运行 'ptboost-tune' 进行动态优化${NC}"
    echo
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
