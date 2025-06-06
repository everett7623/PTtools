#!/bin/bash

# 确保脚本以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <user> <password> <port> <qb_up_port>"
    exit 1
fi

USER=$1
PASSWORD=$2
PORT=${3:-8080}
UP_PORT=${4:-23333}
RAM=$(free -m | awk '/^Mem:/{print $2}')
CACHE_SIZE=$((RAM / 8)) # 用于后续 qBittorrent 配置文件中的缓存设置，尽管此脚本不会自动写入此项

echo "Starting qBittorrent 4.3.8 direct installation..."

# 1. 安装基础工具和依赖
echo "Installing essential tools and qBittorrent dependencies..."
apt update -y
# qBittorrent 4.3.8 (libtorrent v1.2.14) 的常见依赖
apt install -y curl htop vnstat git wget build-essential libboost-system-dev libboost-chrono-dev \
    libboost-random-dev libssl-dev libqt5core5a libqt5gui5 libqt5network5 libqt5xml5 \
    libqt5sql5 libqt5dbus5 libqt5concurrent5 libqt5webkit5 libqt5sql5-sqlite \
    pkg-config cmake libssl-dev zlib1g-dev libsqlite3-dev # 确保所有必要依赖都包含
# 对于 libtorrent 1.2.x 系列，可能还需要以下一些依赖
apt install -y libtorrent-rasterbar-dev # 尝试安装，不确定是否会安装到正确版本
# 如果系统自带的 libtorrent-rasterbar-dev 版本不匹配 4.3.8 所需的 1.2.14
# 你可能需要手动编译 libtorrent 1.2.14，但这会大大增加脚本的复杂性。
# 考虑到你直接下载预编译的 qbittorrent-nox，通常这些预编译版本已经包含了正确的 libtorrent 静态链接或依赖。
# 所以这里主要安装其运行时依赖。

# 2. 创建 qBittorrent 运行用户
if id "$USER" &>/dev/null; then
    echo "User $USER already exists. Skipping user creation."
else
    echo "Creating user $USER..."
    useradd -m -s /bin/bash "$USER" # -m 创建家目录，-s 指定 shell
    echo "$USER:$PASSWORD" | chpasswd # 设置用户密码
    echo "User $USER created."
fi

# 3. 配置 qBittorrent-nox systemd 服务
echo "Creating systemd service file for qBittorrent-nox..."
QB_SERVICE_FILE="/etc/systemd/system/qbittorrent-nox@.service"
cat <<EOF > "$QB_SERVICE_FILE"
[Unit]
Description=qBittorrent Command Line Client
After=network.target

[Service]
Type=forking
User=%i
ExecStart=/usr/bin/qbittorrent-nox --webui-port=$PORT -d --profile=/home/%i/.config/qBittorrent
ExecStop=/usr/bin/killall -w -s 9 qbittorrent-nox
LimitNOFILE=infinity
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload # 重新加载 systemd 配置

# 4. 下载并安装 qBittorrent-nox 4.3.8 二进制文件
echo "Downloading qBittorrent-nox 4.3.8..."
systemARCH=$(uname -m)
if [[ "$systemARCH" == "x86_64" ]]; then
    wget -O /usr/bin/qbittorrent-nox https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox
elif [[ "$systemARCH" == "aarch64" ]]; then
    wget -O /usr/bin/qbittorrent-nox https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox
else
    echo "Unsupported architecture: $systemARCH. Exiting."
    exit 1
fi
chmod +x /usr/bin/qbittorrent-nox

# 5. 确保配置文件目录存在并生成默认配置
# 如果用户是新创建的，家目录下的 .config/qBittorrent 可能不存在
echo "Ensuring qBittorrent configuration directory exists and generating default config..."
install -o "$USER" -g "$USER" -d -m 755 "/home/$USER/.config/qBittorrent"
# 首次启动以生成默认配置文件
systemctl start qbittorrent-nox@"$USER"
sleep 5 # 等待 qBittorrent 启动并生成配置文件，5秒应该足够
systemctl stop qbittorrent-nox@"$USER"

# 6. 配置 qBittorrent 配置文件
echo "Configuring qBittorrent.conf..."
QB_CONF="/home/$USER/.config/qBittorrent/qBittorrent.conf"

# 确保配置文件存在
if [ ! -f "$QB_CONF" ]; then
    echo "Error: qBittorrent configuration file not found after initial start. Exiting."
    exit 1
fi

# 使用 awk 来更可靠地插入/修改配置项
# 因为 sed 在处理特定行插入时，如果目标行不存在，行为可能不一致
# 并且，直接替换比插入更稳妥，如果 Preferences 部分不存在，awk 会在文件末尾添加
awk -v port="$PORT" -v up_port="$UP_PORT" '
BEGIN {
    # 跟踪是否找到了 [Preferences] 节
    in_preferences = 0;
    # 跟踪是否已设置相关选项
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
/WebUI\\Port=/ {
    if (in_preferences) {
        print "WebUI\\\\Port=" port;
        webui_port_set = 1;
        next;
    }
}
# 替换或添加 Connection PortRangeMin
/Connection\\PortRangeMin=/ {
    if (in_preferences) {
        print "Connection\\\\PortRangeMin=" up_port;
        conn_port_set = 1;
        next;
    }
}
# 捕获并打印其他行
{ print }
END {
    # 如果在 [Preferences] 节中未找到并设置，则在 [Preferences] 节后添加
    if (in_preferences) {
        if (!locale_set) { print "General\\\\Locale=zh"; }
        if (!prealloc_set) { print "Downloads\\\\PreAllocation=false"; }
        if (!csrf_set) { print "WebUI\\\\CSRFProtection=false"; }
    } else {
        # 如果文件中根本没有 [Preferences] 节，则在文件末尾添加
        print "[Preferences]";
        print "General\\\\Locale=zh";
        print "Downloads\\\\PreAllocation=false";
        print "WebUI\\\\CSRFProtection=false";
        # 这里还需要处理 WebUI\\Port 和 Connection\\PortRangeMin，如果它们没有出现在其他地方
        print "WebUI\\\\Port=" port;
        print "Connection\\\\PortRangeMin=" up_port;
    }
}' "$QB_CONF" > "${QB_CONF}.tmp" && mv "${QB_CONF}.tmp" "$QB_CONF"

# 对 /root/.boot-script.sh 的修改（如果这个文件存在并且需要修改）
if [ -f "/root/.boot-script.sh" ]; then
    echo "Modifying /root/.boot-script.sh..."
    sed -i "s/disable_tso_/# disable_tso_/" /root/.boot-script.sh
else
    echo "/root/.boot-script.sh not found. Skipping modification."
fi


# 7. 配置 BBR 及启动命令
echo "Setting up BBR and qBittorrent auto-start..."
# BBR 安装（可选，如果原始脚本的 Install.sh 负责BBR）
# 这是一个简化的 BBR 开启方法，更复杂的 BBR 脚本可能会有更多检查和优化
# 参考：https://www.linuxbyexample.com/bbr-ubuntu-debian/
sysctl_conf="/etc/sysctl.conf"
if ! grep -q "net.core.default_qdisc=fq" "$sysctl_conf"; then
    echo "net.core.default_qdisc=fq" >> "$sysctl_conf"
fi
if ! grep -q "net.ipv4.tcp_congestion_control=bbr" "$sysctl_conf"; then
    echo "net.ipv4.tcp_congestion_control=bbr" >> "$sysctl_conf"
fi
sysctl -p # 应用 sysctl 配置

# 清空并重新写入 BBRx.sh，确保只包含我们需要的启动命令
echo "#!/bin/bash" > /root/BBRx.sh # 添加 shebang
echo "systemctl enable qbittorrent-nox@$USER" >> /root/BBRx.sh
echo "systemctl start qbittorrent-nox@$USER" >> /root/BBRx.sh
echo "shutdown -r +1" >> /root/BBRx.sh
chmod +x /root/BBRx.sh # 确保脚本可执行

# 如果 BBRx.sh 是在系统启动时由其他方式（如rc.local）调用的，请确保其配置正确
# 例如，如果 /etc/rc.local 存在且被 systemd 管理
if [ -f "/etc/rc.local" ]; then
    if ! grep -q "/root/BBRx.sh" /etc/rc.local; then
        echo "/root/BBRx.sh" >> /etc/rc.local
        chmod +x /etc/rc.local
    fi
else
    echo "Warning: /etc/rc.local not found. Ensure /root/BBRx.sh is executed on boot."
    echo "You may need to manually configure a systemd service for /root/BBRx.sh if you rely on it for second reboot."
fi

# 8. 调整文件系统预留空间
echo "Adjusting file system reserved space..."
tune2fs -m 1 "$(df -h / | awk 'NR==2 {print $1}')"

echo "Installation and configuration complete. The system will now reboot twice."
echo "First reboot in 1 minute. The second reboot will be triggered by /root/BBRx.sh."
shutdown -r +1
