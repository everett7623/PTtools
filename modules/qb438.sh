#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <user> <password> <port> <qb_up_port>"
    exit 1
fi

USER=$1
PASSWORD=$2
PORT=${3:-8080}
UP_PORT=${4:-23333}
RAM=$(free -m | awk '/^Mem:/{print $2}')
CACHE_SIZE=$((RAM / 8))

bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u $USER -p $PASSWORD -c $CACHE_SIZE -q 4.3.9 -l v1.2.20 -x
apt install -y curl htop vnstat
systemctl stop qbittorrent-nox@$USER
#systemctl disable qbittorrent-nox@$USER
systemARCH=$(uname -m)
if [[ $systemARCH == x86_64 ]]; then
    wget -O /usr/bin/qbittorrent-nox https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox
elif [[ $systemARCH == aarch64 ]]; then
    wget -O /usr/bin/qbittorrent-nox https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox
fi
chmod +x /usr/bin/qbittorrent-nox
sed -i "s/WebUI\\\\Port=[0-9]*/WebUI\\\\Port=$PORT/" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "s/Connection\\\\PortRangeMin=[0-9]*/Connection\\\\PortRangeMin=$UP_PORT/" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a General\\\\Locale=zh" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a Downloads\\\\PreAllocation=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a WebUI\\\\CSRFProtection=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "s/disable_tso_/# disable_tso_/" /root/.boot-script.sh
echo "systemctl enable qbittorrent-nox@$USER" >> /root/BBRx.sh
echo "systemctl start qbittorrent-nox@$USER" >> /root/BBRx.sh
echo "shutdown -r +1" >> /root/BBRx.sh
tune2fs -m 1 $(df -h / | awk 'NR==2 {print $1}') 
echo "接下来将自动重启2次，流程预计5-10分钟..."
shutdown -r +1
