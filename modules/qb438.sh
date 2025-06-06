#!/bin/bash

# 确保脚本以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo "错误：此脚本必须以 root 权限运行。"
   exit 1
fi

# 检查参数数量
if [ "$#" -lt 2 ]; then
    echo "用法: $0 <qb_用户名> <qb_密码> [webui_端口] [bt_上传端口]"
    echo "  <qb_用户名>: qBittorrent WebUI 的登录用户名。"
    echo "  <qb_密码>: qBittorrent WebUI 的登录密码。"
    echo "  [webui_端口]: qBittorrent WebUI 的监听端口，默认为 8080。"
    echo "  [bt_上传端口]: qBittorrent 的 BT 上传/监听端口，默认为 23333。"
    exit 1
fi

# 参数赋值
QB_USER=$1
QB_PASSWORD=$2
WEBUI_PORT=${3:-8080}
BT_PORT=${4:-23333}

# 计算内存大小用于缓存（此脚本不会自动写入此项，但保留以备将来使用）
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
# CACHE_SIZE_MB=$((RAM_MB / 8))

echo "========================================="
echo "  开始 qBittorrent 4.3.8 直接安装与配置"
echo "========================================="
echo "  qBittorrent 用户名: $QB_USER"
echo "  qBittorrent WebUI 端口: $WEBUI_PORT"
echo "  qBittorrent BT 端口: $BT_PORT"
echo "========================================="

# 1. 更新软件包列表并安装基础工具和 qBittorrent 依赖
echo ">> (1/8) 更新软件包列表并安装必要的工具和 qBittorrent 依赖..."
apt update -y
apt install -y curl htop vnstat git wget build-essential libboost-system-dev libboost-chrono-dev \
    libboost-random-dev libssl-dev libqt5core5a libqt5gui5 libqt5network5 libqt5xml5 \
    libqt5sql5 libqt5dbus5 libqt5concurrent5 libqt5webkit5 libqt5sql5-sqlite \
    pkg-config cmake libssl-dev zlib1g-dev libsqlite3-dev

if [ $? -ne 0 ]; then
    echo "错误：安装依赖包失败。请检查您的网络连接或系统源。"
    exit 1
fi
echo ">> 依赖安装完成。"

# 2. 创建 qBittorrent 运行用户
echo ">> (2/8) 检查并创建 qBittorrent 运行用户 '$QB_USER'..."
if id "$QB_USER" &>/dev/null; then
    echo "用户 '$QB_USER' 已存在，跳过用户创建。"
else
    useradd -m -s /bin/bash "$QB_USER" # -m 创建家目录，-s 指定 shell
    if [ $? -ne 0 ]; then
        echo "错误：创建用户 '$QB_USER' 失败。"
        exit 1
    fi
    echo "$QB_USER:$QB_PASSWORD" | chpasswd # 设置用户密码
    if [ $? -ne 0 ]; then
        echo "错误：设置用户 '$QB_USER' 密码失败。"
        exit 1
    fi
    echo "用户 '$QB_USER' 创建成功。"
fi

# 3. 配置 qBittorrent-nox systemd 服务
echo ">> (3/8) 创建 qBittorrent-nox systemd 服务文件..."
QB_SERVICE_FILE="/etc/systemd/system/qbittorrent-nox@.service"
cat <<EOF > "$QB_SERVICE_FILE"
[Unit]
Description=qBittorrent Command Line Client
After=network.target

[Service]
Type=forking
User=%i
ExecStart=/usr/bin/qbittorrent-nox --webui-port=${WEBUI_PORT} -d --profile=/home/%i/.config/qBittorrent
ExecStop=/usr/bin/killall -w -s 9 qbittorrent-nox
LimitNOFILE=infinity
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload # 重新加载 systemd 配置
if [ $? -ne 0 ]; then
    echo "错误：重新加载 systemd 配置失败。"
    exit 1
fi
echo ">> systemd 服务文件创建成功。"

# 4. 下载并安装 qBittorrent-nox 4.3.8 二进制文件
echo ">> (4/8) 下载 qBittorrent-nox 4.3.8 二进制文件..."
systemARCH=$(uname -m)
DOWNLOAD_URL=""
if [[ "$systemARCH" == "x86_64" ]]; then
    DOWNLOAD_URL="https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox"
elif [[ "$systemARCH" == "aarch64" ]]; then
    DOWNLOAD_URL="https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox"
else
    echo "错误：不支持的系统架构 '$systemARCH'。脚本退出。"
    exit 1
fi

wget -O /usr/bin/qbittorrent-nox "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo "错误：下载 qBittorrent-nox 失败。请检查下载链接或网络。"
    exit 1
fi
chmod +x /usr/bin/qbittorrent-nox
echo ">> qBittorrent-nox 4.3.8 下载并设置执行权限完成。"

# 5. 确保配置文件目录存在并生成默认配置
echo ">> (5/8) 确保 qBittorrent 配置文件目录存在并生成默认配置..."
QB_CONFIG_DIR="/home/$QB_USER/.config/qBittorrent"
install -o "$QB_USER" -g "$QB_USER" -d -m 755 "$QB_CONFIG_DIR"
if [ $? -ne 0 ]; then
    echo "错误：创建 qBittorrent 配置目录失败。"
    exit 1
fi

# 尝试启动 qBittorrent-nox 以生成默认配置文件
echo "尝试启动 qBittorrent-nox 以生成默认配置文件..."
systemctl start qbittorrent-nox@"$QB_USER"
sleep 10 # 等待 qBittorrent 启动并生成配置文件
systemctl stop qbittorrent-nox@"$QB_USER"
echo ">> 默认配置文件生成尝试完成。"

# 6. 配置 qBittorrent 配置文件
echo ">> (6/8) 配置 qBittorrent.conf..."
QB_CONF="$QB_CONFIG_DIR/qBittorrent.conf"

# 确保配置文件存在
if [ ! -f "$QB_CONF" ]; then
    echo "错误：在尝试启动后未找到 qBittorrent 配置文件 ($QB_CONF)。脚本退出。"
    exit 1
fi

# 使用 awk 来更可靠地插入/修改配置项
awk -v webui_port="$WEBUI_PORT" -v bt_port="$BT_PORT" '
BEGIN {
    # 跟踪是否找到了 [Preferences] 节
    in_preferences = 0;
    # 标志是否已设置相关选项
    webui_port_set = 0;
    conn_port_set = 0;
    locale_set = 0;
    prealloc_set = 0;
    csrf_set = 0;
}
/\[Preferences\]/ {
    print; # 打印 [Preferences] 行
    in_preferences = 1;
    next;
}
# 替换或添加 WebUI Port
/WebUI\\\\Port=/ {
    if (in_preferences) {
        print "WebUI\\\\Port=" webui_port;
        webui_port_set = 1;
        next;
    }
}
# 替换或添加 Connection PortRangeMin
/Connection\\\\PortRangeMin=/ {
    if (in_preferences) {
        print "Connection\\\\PortRangeMin=" bt_port;
        conn_port_set = 1;
        next;
    }
}
# 捕获并打印其他行
{ print }
END {
    # 如果在 [Preferences] 节中，并且某些项未被替换（即是新添加）
    if (in_preferences) {
        if (!locale_set) { print "General\\\\Locale=zh"; }
        if (!prealloc_set) { print "Downloads\\\\PreAllocation=false"; }
        if (!csrf_set) { print "WebUI\\\\CSRFProtection=false"; }
        # 如果 WebUI Port 或 Connection PortRangeMin 未被替换（即不存在），则在这里添加
        if (!webui_port_set) { print "WebUI\\\\Port=" webui_port; }
        if (!conn_port_set) { print "Connection\\\\PortRangeMin=" bt_port; }
    } else {
        # 如果文件中根本没有 [Preferences] 节，则在文件末尾添加
        print "[Preferences]";
        print "WebUI\\\\Port=" webui_port;
        print "Connection\\\\PortRangeMin=" bt_port;
        print "General\\\\Locale=zh";
        print "Downloads\\\\PreAllocation=false";
        print "WebUI\\\\CSRFProtection=false";
    }
}' "$QB_CONF" > "${QB_CONF}.tmp" && mv "${QB_CONF}.tmp" "$QB_CONF"
if [ $? -ne 0 ]; then
    echo "错误：配置 qBittorrent.conf 文件失败。"
    exit 1
fi
echo ">> qBittorrent.conf 配置完成。"

# 7. 配置 BBR 及启动命令 (针对 /root/.boot-script.sh 和 /root/BBRx.sh)
echo ">> (7/8) 配置 BBR (TCP 拥塞控制) 和系统启动项..."

# 对 /root/.boot-script.sh 的修改（如果这个文件存在并且需要修改）
if [ -f "/root/.boot-script.sh" ]; then
    echo "修改 /root/.boot-script.sh 以注释掉 'disable_tso_'..."
    sed -i "s/disable_tso_/# disable_tso_/" /root/.boot-script.sh
    if [ $? -ne 0 ]; then
        echo "警告：修改 /root/.boot-script.sh 失败。"
    fi
else
    echo "/root/.boot-script.sh 未找到，跳过其修改。"
fi

# 开启 BBR (如果未开启)
SYSCTL_CONF="/etc/sysctl.conf"
echo "启用 BBR TCP 拥塞控制..."
if ! grep -q "net.core.default_qdisc=fq" "$SYSCTL_CONF"; then
    echo "net.core.default_qdisc=fq" >> "$SYSCTL_CONF"
fi
if ! grep -q "net.ipv4.tcp_congestion_control=bbr" "$SYSCTL_CONF"; then
    echo "net.ipv4.tcp_congestion_control=bbr" >> "$SYSCTL_CONF"
fi
sysctl -p # 应用 sysctl 配置
if [ $? -ne 0 ]; then
    echo "警告：应用 sysctl 配置失败。"
fi
echo ">> BBR 配置完成。"

# 清空并重新写入 BBRx.sh，确保只包含我们需要的启动命令
echo "准备 /root/BBRx.sh 脚本，用于系统重启和 qBittorrent 启动..."
echo "#!/bin/bash" > /root/BBRx.sh # 使用 > 清空并写入 shebang
echo "systemctl enable qbittorrent-nox@$QB_USER" >> /root/BBRx.sh
echo "systemctl start qbittorrent-nox@$QB_USER" >> /root/BBRx.sh
echo "shutdown -r +1" >> /root/BBRx.sh
chmod +x /root/BBRx.sh # 确保脚本可执行
echo ">> /root/BBRx.sh 脚本准备完成。"

# 确保 BBRx.sh 在系统启动时被执行 (通过 /etc/rc.local 或其他方式)
# 这是确保第二次重启和 qBittorrent 自启的关键
if [ -f "/etc/rc.local" ]; then
    if ! grep -q "/root/BBRx.sh" /etc/rc.local; then
        echo "将 /root/BBRx.sh 添加到 /etc/rc.local..."
        echo "/root/BBRx.sh" >> /etc/rc.local
        chmod +x /etc/rc.local
        if [ $? -ne 0 ]; then
            echo "警告：修改 /etc/rc.local 失败。"
        fi
    else
        echo "/root/BBRx.sh 已在 /etc/rc.local 中。"
    fi
else
    echo "警告：/etc/rc.local 未找到。请手动确保 /root/BBRx.sh 在系统启动时执行。"
    echo "  如果您的系统不使用 /etc/rc.local，您可能需要手动配置一个 systemd 服务来执行 /root/BBRx.sh。"
fi


# 8. 调整文件系统预留空间
echo ">> (8/8) 调整文件系统预留空间为 1%..."
# 获取根分区设备名
ROOT_DEVICE=$(df -h / | awk 'NR==2 {print $1}')
if [ -n "$ROOT_DEVICE" ]; then
    tune2fs -m 1 "$ROOT_DEVICE"
    if [ $? -ne 0 ]; then
        echo "警告：调整文件系统预留空间失败。"
    fi
    echo ">> 文件系统 '$ROOT_DEVICE' 预留空间调整完成。"
else
    echo "警告：无法获取根文件系统设备名，跳过调整预留空间。"
fi

echo "========================================="
echo "  安装和配置已完成。系统将自动重启两次。"
echo "  第一次重启将在 1 分钟后触发。"
echo "  第二次重启将由 /root/BBRx.sh 在第一次重启后触发。"
echo "  整个流程预计 5-10 分钟..."
echo "========================================="

# 触发第一次重启
shutdown -r +1

echo "脚本执行完毕。"
