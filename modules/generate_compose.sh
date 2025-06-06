#!/bin/bash
# Docker Compose Generation Module for PTtools
# Generates docker-compose.yml based on selected applications

set -euo pipefail

# Get parameters
DOCKER_PATH="${1:-/opt/docker}"
shift
SELECTED_APPS=("$@")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[COMPOSE]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[COMPOSE]${NC} $*"
}

# Initialize docker-compose.yml
init_compose() {
    cat > "$DOCKER_PATH/docker-compose.yml" << 'EOF'
version: '3.8'

services:
EOF
}

# Add qBittorrent service
add_qbittorrent() {
    cat >> "$DOCKER_PATH/docker-compose.yml" << EOF
  qbittorrent:
    image: linuxserver/qbittorrent:4.6.7
    container_name: qbittorrent
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
      - WEBUI_PORT=8080
    volumes:
      - $DOCKER_PATH/qbittorrent/config:/config
      - $DOCKER_PATH/downloads:/downloads
    ports:
      - 8080:8080
      - 6881:6881
      - 6881:6881/udp
    restart: unless-stopped
    networks:
      - pt_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
}

# Add Transmission service
add_transmission() {
    cat >> "$DOCKER_PATH/docker-compose.yml" << EOF

  transmission:
    image: linuxserver/transmission:4.0.5
    container_name: transmission
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
      - TRANSMISSION_WEB_HOME=/config/webui/trguing-zh
      - USER=admin
      - PASS=adminadmin
    volumes:
      - $DOCKER_PATH/transmission/config:/config
      - $DOCKER_PATH/downloads:/downloads
    ports:
      - 9091:9091
      - 51413:51413
      - 51413:51413/udp
    restart: unless-stopped
    networks:
      - pt_network
EOF
}

# Add Emby service
add_emby() {
    cat >> "$DOCKER_PATH/docker-compose.yml" << EOF

  emby:
    image: emby/embyserver:latest
    container_name: emby
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
    volumes:
      - $DOCKER_PATH/emby/config:/config
      - $DOCKER_PATH/downloads:/media
      - /dev/shm:/dev/shm
    ports:
      - 8096:8096
      - 8920:8920
    devices:
      - /dev/dri:/dev/dri
    privileged: true
    restart: unless-stopped
    networks:
      - pt_network
EOF
}

# Add IYUUPlus service
add_iyuuplus() {
    cat >> "$DOCKER_PATH/docker-compose.yml" << EOF

  iyuuplus:
    image: iyuucn/iyuuplus-dev:latest
    container_name: iyuuplus
    stdin_open: true
    tty: true
    volumes:
      - $DOCKER_PATH/iyuuplus/iyuu:/iyuu
      - $DOCKER_PATH/iyuuplus/data:/data
      - $DOCKER_PATH/qbittorrent/config/qBittorrent/BT_backup:/qb
      - $DOCKER_PATH/transmission/config/torrents:/tr
    ports:
      - 8780:8780
    restart: always
    networks:
      - pt_network
    environment:
      - TZ=Asia/Shanghai
EOF
}

# Add MoviePilot service
add_moviepilot() {
    cat >> "$DOCKER_PATH/docker-compose.yml" << EOF

  moviepilot:
    stdin_open: true
    tty: true
    container_name: moviepilot-v2
    hostname: moviepilot-v2
    network_mode: host
    volumes:
      - $DOCKER_PATH/downloads:/media
      - $DOCKER_PATH/moviepilot/config:/config
      - $DOCKER_PATH/moviepilot/core:/moviepilot/.cache/ms-playwright
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - $DOCKER_PATH/qbittorrent/config/qBittorrent/BT_backup:/qb
      - $DOCKER_PATH/transmission/config/torrents:/tr
    environment:
      - NGINX_PORT=3000
      - PORT=3001
      - PUID=0
      - PGID=0
      - UMASK=000
      - TZ=Asia/Shanghai
      - SUPERUSER=admin
    restart: always
    image: jxxghp/moviepilot-v2:latest
EOF
}

# Add Vertex service
add_vertex() {
    cat >> "$DOCKER_PATH/docker-compose.yml" << EOF

  vertex:
    image: lswl/vertex:stable
    container_name: vertex
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - $DOCKER_PATH/vertex:/vertex
    ports:
      - 3334:3000
    restart: unless-stopped
    networks:
      - pt_network
EOF
}

# Add NAS-Tools service
add_nas_tools() {
    cat >> "$DOCKER_PATH/docker-compose.yml" << EOF

  nas-tools:
    image: 0xforee/nas-tools:latest
    container_name: nas-tools
    hostname: nas-tools
    ports:
      - 3333:3000
    volumes:
      - $DOCKER_PATH/nastool/config:/config 
      - $DOCKER_PATH/downloads:/media
    environment: 
      - PUID=0 
      - PGID=0
      - UMASK=000
      - NASTOOL_AUTO_UPDATE=true
      - NASTOOL_CN_UPDATE=false
    restart: always
    networks:
      - pt_network
EOF
}

# Add FileBrowser service
add_filebrowser() {
    cat >> "$DOCKER_PATH/docker-compose.yml" << EOF

  filebrowser:
    image: hurlenko/filebrowser:latest
    container_name: filebrowser
    environment:
      - UID=0
      - GID=0
      - TZ=Asia/Shanghai
    ports:
      - 8081:8080
    volumes:
      - $DOCKER_PATH/filebrowser/config:/config
      - $DOCKER_PATH/downloads:/data
    restart: unless-stopped
    networks:
      - pt_network
EOF
}

# Add MetaTube service
add_metatube() {
    cat >> "$DOCKER_PATH/docker-compose.yml" << EOF

  metatube:
    image: ghcr.io/metatube-community/metatube-server:latest
    container_name: metatube
    ports:
      - 9080:8080
    volumes:
      - $DOCKER_PATH/metatube/config:/config
    command: -dsn /config/metatube.db
    restart: unless-stopped
    networks:
      - pt_network
EOF
}

# Add Byte-Muse service
add_byte_muse() {
    cat >> "$DOCKER_PATH/docker-compose.yml" << EOF

  byte-muse:
    image: envyafish/byte-muse:latest
    container_name: byte-muse
    restart: always
    ports:
      - 8043:80
    volumes:
      - $DOCKER_PATH/byte-muse:/data
    networks:
      - pt_network
EOF
}

# Add networks and volumes section
add_networks_volumes() {
    cat >> "$DOCKER_PATH/docker-compose.yml" << EOF

networks:
  pt_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  downloads:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: $DOCKER_PATH/downloads
EOF
}

# Generate environment file
generate_env_file() {
    cat > "$DOCKER_PATH/.env" << EOF
# PTtools Docker Environment Variables
DOCKER_PATH=$DOCKER_PATH
DOWNLOAD_PATH=$DOCKER_PATH/downloads
TZ=Asia/Shanghai

# Default credentials (please change!)
DEFAULT_USER=admin
DEFAULT_PASS=adminadmin

# Network settings
SUBNET=172.20.0.0/16
EOF
}

# Main generation function
main() {
    log_info "Generating docker-compose.yml for: ${SELECTED_APPS[*]}"
    
    # Initialize compose file
    init_compose
    
    # Add selected services
    for app in "${SELECTED_APPS[@]}"; do
        case "$app" in
            "qbittorrent")
                log_info "Adding qBittorrent..."
                add_qbittorrent
                ;;
            "transmission")
                log_info "Adding Transmission..."
                add_transmission
                ;;
            "emby")
                log_info "Adding Emby..."
                add_emby
                ;;
            "iyuuplus")
                log_info "Adding IYUUPlus..."
                add_iyuuplus
                ;;
            "moviepilot")
                log_info "Adding MoviePilot..."
                add_moviepilot
                ;;
            "vertex")
                log_info "Adding Vertex..."
                add_vertex
                ;;
            "nas-tools")
                log_info "Adding NAS-Tools..."
                add_nas_tools
                ;;
            "filebrowser")
                log_info "Adding FileBrowser..."
                add_filebrowser
                ;;
            "metatube")
                log_info "Adding MetaTube..."
                add_metatube
                ;;
            "byte-muse")
                log_info "Adding Byte-Muse..."
                add_byte_muse
                ;;
            *)
                log_warn "Unknown application: $app"
                ;;
        esac
    done
    
    # Add networks and volumes
    add_networks_volumes
    
    # Generate environment file
    generate_env_file
    
    log_info "docker-compose.yml generated successfully at $DOCKER_PATH/docker-compose.yml"
    
    # Create necessary directories
    log_info "Creating application directories..."
    for app in "${SELECTED_APPS[@]}"; do
        mkdir -p "$DOCKER_PATH/$app/config"
        mkdir -p "$DOCKER_PATH/$app/data"
    done
    
    # Create downloads directory
    mkdir -p "$DOCKER_PATH/downloads"
    chmod -R 777 "$DOCKER_PATH/downloads"
    
    log_info "Docker Compose generation completed!"
}

# Run main
main
