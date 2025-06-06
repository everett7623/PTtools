#!/bin/bash
# Vertex Installation Module for PTtools
# This module handles Vertex installation and configuration

set -euo pipefail

# Get parameters
QB_VERSION="${1:-4.3.8}"
DOCKER_PATH="${2:-/opt/docker}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[VERTEX]${NC} $*"
}

log_error() {
    echo -e "${RED}[VERTEX ERROR]${NC} $*"
}

# Check if qBittorrent is running
check_qbittorrent() {
    if ! docker ps | grep -q "qbittorrent"; then
        log_error "qBittorrent container is not running"
        return 1
    fi
    return 0
}

# Install Vertex via Docker
install_vertex_docker() {
    log_info "Installing Vertex via Docker..."
    
    # Create Vertex directories
    mkdir -p "$DOCKER_PATH/vertex/config"
    mkdir -p "$DOCKER_PATH/vertex/data"
    
    # Create Vertex configuration
    cat > "$DOCKER_PATH/vertex/config/config.yml" << EOF
# Vertex Configuration
server:
  host: 0.0.0.0
  port: 3334

qbittorrent:
  host: qbittorrent
  port: 8080
  username: admin
  password: adminadmin

features:
  auto_management:
    enabled: true
    check_interval: 300
  
  ratio_management:
    enabled: true
    min_ratio: 1.0
    target_ratio: 3.0
    max_seed_time: 2592000
  
  cross_seeding:
    enabled: true
    match_mode: exact
  
  disk_management:
    enabled: true
    min_free_space: 10GB
    
  tracker_management:
    enabled: true
    update_interval: 3600

logging:
  level: info
  file: /vertex/logs/vertex.log
EOF
    
    # Create docker-compose entry for Vertex
    if [[ -f "$DOCKER_PATH/docker-compose.yml" ]]; then
        # Append to existing docker-compose.yml
        if ! grep -q "vertex:" "$DOCKER_PATH/docker-compose.yml"; then
            cat >> "$DOCKER_PATH/docker-compose.yml" << EOF

  vertex:
    image: lswl/vertex:stable
    container_name: vertex
    environment:
      - TZ=Asia/Shanghai
      - VERTEX_CONFIG=/vertex/config/config.yml
    volumes:
      - $DOCKER_PATH/vertex/config:/vertex/config
      - $DOCKER_PATH/vertex/data:/vertex/data
      - $DOCKER_PATH/downloads:/downloads
    ports:
      - 3334:3334
    depends_on:
      - qbittorrent
    restart: unless-stopped
    networks:
      - pt_network
EOF
        fi
    else
        # Create new docker-compose.yml
        cat > "$DOCKER_PATH/docker-compose.yml" << EOF
version: '3.8'

services:
  vertex:
    image: lswl/vertex:stable
    container_name: vertex
    environment:
      - TZ=Asia/Shanghai
      - VERTEX_CONFIG=/vertex/config/config.yml
    volumes:
      - $DOCKER_PATH/vertex/config:/vertex/config
      - $DOCKER_PATH/vertex/data:/vertex/data
      - $DOCKER_PATH/downloads:/downloads
    ports:
      - 3334:3334
    restart: unless-stopped

networks:
  pt_network:
    driver: bridge
EOF
    fi
    
    # Start Vertex container
    cd "$DOCKER_PATH"
    docker-compose up -d vertex
    
    log_info "Vertex Docker container started"
}

# Configure Vertex for specific qBittorrent version
configure_vertex_for_qb() {
    local qb_version="$1"
    
    log_info "Configuring Vertex for qBittorrent $qb_version..."
    
    case "$qb_version" in
        "4.3.8")
            # Specific configuration for QB 4.3.8
            cat > "$DOCKER_PATH/vertex/config/qb438-rules.yml" << EOF
# Special rules for qBittorrent 4.3.8
compatibility:
  api_version: 2.8.3
  libtorrent_version: 1.2.x
  
optimizations:
  concurrent_downloads: 5
  max_connections: 200
  upload_slots: 10
EOF
            ;;
        "4.3.9")
            # Specific configuration for QB 4.3.9
            cat > "$DOCKER_PATH/vertex/config/qb439-rules.yml" << EOF
# Special rules for qBittorrent 4.3.9
compatibility:
  api_version: 2.8.4
  libtorrent_version: 1.2.19
  
optimizations:
  concurrent_downloads: 8
  max_connections: 500
  upload_slots: 20
EOF
            ;;
    esac
    
    log_info "Vertex configuration updated for qBittorrent $qb_version"
}

# Setup Vertex automation rules
setup_automation_rules() {
    log_info "Setting up Vertex automation rules..."
    
    cat > "$DOCKER_PATH/vertex/config/automation-rules.json" << 'EOF'
{
  "rules": [
    {
      "name": "Freeleech Priority",
      "enabled": true,
      "conditions": {
        "tracker_status": "freeleech"
      },
      "actions": {
        "priority": "high",
        "force_start": true
      }
    },
    {
      "name": "Auto Remove Completed",
      "enabled": true,
      "conditions": {
        "ratio": ">= 3.0",
        "seed_time": ">= 7d"
      },
      "actions": {
        "remove_torrent": true,
        "delete_files": false
      }
    },
    {
      "name": "Low Disk Space Management",
      "enabled": true,
      "conditions": {
        "free_space": "< 10GB"
      },
      "actions": {
        "pause_all": true,
        "notify": true
      }
    },
    {
      "name": "Cross Seed Detection",
      "enabled": true,
      "conditions": {
        "matching_hash": true
      },
      "actions": {
        "add_cross_seed": true,
        "tag": "cross-seed"
      }
    }
  ]
}
EOF
    
    log_info "Automation rules configured"
}

# Wait for service to be ready
wait_for_vertex() {
    log_info "Waiting for Vertex to be ready..."
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:3334/api/health > /dev/null 2>&1; then
            log_info "Vertex is ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        log_info "Waiting for Vertex... ($attempt/$max_attempts)"
        sleep 2
    done
    
    log_error "Vertex failed to start within timeout"
    return 1
}

# Main installation
main() {
    log_info "Starting Vertex installation..."
    log_info "qBittorrent version: $QB_VERSION"
    log_info "Docker path: $DOCKER_PATH"
    
    # Check prerequisites
    if ! check_qbittorrent; then
        log_error "Please ensure qBittorrent is installed and running first"
        exit 1
    fi
    
    # Install Vertex
    install_vertex_docker
    
    # Configure for specific QB version
    configure_vertex_for_qb "$QB_VERSION"
    
    # Setup automation rules
    setup_automation_rules
    
    # Wait for service
    if wait_for_vertex; then
        log_info "Vertex installation completed successfully!"
        log_info "Access Vertex at: http://localhost:3334"
    else
        log_error "Vertex installation completed but service is not responding"
        exit 1
    fi
}

# Run main
main
