# 脚本名称: qbittorrent-4.3.8.sh
# 脚本描述: qBittorrent 4.3.8 BT下载客户端安装脚本（使用原作者脚本）
# 脚本路径: https://raw.githubusercontent.com/everett7623/PTtools/main/config/qbittorrent-4.3.8.sh
# 使用方法: 通过PTtools主脚本选择安装
# 作者: Jensfrank
# 更新时间: 2024-12-29

#!/bin/bash

# qBittorrent 4.3.8 安装脚本（原作者脚本）
echo "正在安装 qBittorrent 4.3.8 (使用原作者脚本)..."

# 使用原作者的qBittorrent 4.3.8安装脚本
echo "检测系统类型..."
if [[ -f /etc/redhat-release ]]; then
    # CentOS/RHEL 系统
    echo "检测到 CentOS/RHEL 系统"
    bash <(wget -qO- https://github.com/Aniverse/inexistence/raw/master/00.Installation/package/qbittorrent/qqbb)
elif [[ -f /etc/debian_version ]]; then
    # Debian/Ubuntu 系统
    echo "检测到 Debian/Ubuntu 系统"
    bash <(wget -qO- https://github.com/Aniverse/inexistence/raw/master/00.Installation/package/qbittorrent/qqbb)
else
    echo "不支持的系统类型"
    exit 1
fi

echo "qBittorrent 4.3.8 安装完成！"
echo "Web界面访问地址: http://您的IP:8080"
echo "默认用户名: admin"
echo "默认密码请查看安装日志或使用: cat /home/用户名/.config/qBittorrent/config/qBittorrent.conf | grep WebUI"
