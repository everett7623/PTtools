#!/bin/bash
# Uninstall Module for PTtools
# Handles removal of PT tools and system cleanup

set -euo pipefail

# Get uninstall mode
UNINSTALL_MODE="${1:-selective}"
DOCKER_PATH="${DOCKER_PATH:-/opt/docker}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[UNINSTALL]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[UNINSTALL]${NC} $*"
}

log_error() {
    echo -e "${RED}[UNINSTALL]${NC} $*"
}

# List installed applications
list_installed_apps() {
    local installed_file="/etc/pttools/installed.list"
    
    if [[ -f "$installed_file" ]]; then
        cat "$installed_file" | cut -d'|' -f1 | sort -u
    else
        # Fallback: check running containers
        docker ps --format "table {{.Names}}" | tail -n +2
    fi
}

# Stop and remove container
stop_and_remove_container() {
    local container_name="$1"
    
    log_info "Stopping container: $container_name"
    
    # Stop container
    if docker ps -a | grep -q "$container_name"; then
        docker stop "$container_name" 2>/dev/null || true
        docker rm "$container_name" 2>/dev/null || true
        log_info "Container $container_name removed"
    else
        log_warn "Container $container_name not found"
    fi
}

# Remove Docker image
remove_docker_image() {
    local image_name="$1"
    
    log_info "Removing Docker image: $image_name"
    
    # Get image ID
    local image_id=$(docker images | grep "$image_name" | awk '{print $3}' | head -1)
    
    if [[ -n "$image_id" ]]; then
        docker rmi "$image_id" 2>/dev/null || true
        log_info "Image $image_name removed"
    fi
}

# Remove application data
remove_app_data() {
    local app_name="$1"
    local data_path="${DOCKER_PATH}/${app_name}"
    
    if [[ -d "$data_path" ]]; then
        log_warn "Removing application data: $data_path"
        read -p "Are you sure you want to delete all data for $app_name? (yes/no): " confirm
        
        if [[ "$confirm" == "yes" ]]; then
            rm -rf "$data_path"
            log_info "Application data removed"
        else
            log_info "Application data preserved"
        fi
    fi
}

# Uninstall specific application
uninstall_application() {
    local app_name="$1"
    
    log_info "Uninstalling $app_name..."
    
    # Stop and remove container
    stop_and_remove_container "$app_name"
    
    # Remove from docker-compose if exists
    remove_from_compose "$app_name"
    
    # Ask about data removal
    remove_app_data "$app_name"
    
    # Update installation registry
    update_registry "$app_name"
    
    log_info "$app_name uninstalled successfully"
}

# Remove service from docker-compose.yml
remove_from_compose() {
    local service_name="$1"
    local compose_file="${DOCKER_PATH}/docker-compose.yml"
    
    if [[ -f "$compose_file" ]]; then
        # Create backup
        cp "$compose_file" "${compose_file}.bak"
        
        # Remove service section (this is simplified, real implementation would be more robust)
        log_info "Updating docker-compose.yml..."
        
        # This is a placeholder - in production, use proper YAML parser
        log_warn "Manual edit of docker-compose.yml may be required"
    fi
}

# Update installation registry
update_registry() {
    local app_name="$1"
    local registry_file="/etc/pttools/installed.list"
    
    if [[ -f "$registry_file" ]]; then
        grep -v "^${app_name}|" "$registry_file" > "${registry_file}.tmp" || true
        mv "${registry_file}.tmp" "$registry_file"
    fi
}

# Selective uninstall
selective_uninstall() {
    log_info "Starting selective uninstall..."
    
    # Get list of installed apps
    local apps=($(list_installed_apps))
    
    if [[ ${#apps[@]} -eq 0 ]]; then
        log_warn "No PT tools found to uninstall"
        return
    fi
    
    # Display menu
    echo "Installed applications:"
    for i in "${!apps[@]}"; do
        echo "$((i+1)). ${apps[i]}"
    done
    echo "0. Cancel"
    
    # Get selection
    read -p "Select application to uninstall [0-${#apps[@]}]: " choice
    
    if [[ "$choice" -eq 0 ]]; then
        log_info "Uninstall cancelled"
        return
    fi
    
    if [[ "$choice" -ge 1 && "$choice" -le ${#apps[@]} ]]; then
        local selected_app="${apps[$((choice-1))]}"
        uninstall_application "$selected_app"
    else
        log_error "Invalid selection"
    fi
}

# Remove all PT tools
remove_all_pt_tools() {
    log_warn "Removing all PT tools..."
    
    # Get all PT-related containers
    local containers=(
        "qbittorrent"
        "transmission"
        "emby"
        "iyuuplus"
        "moviepilot"
        "vertex"
        "nas-tools"
        "filebrowser"
        "metatube"
        "byte-muse"
    )
    
    for container in "${containers[@]}"; do
        stop_and_remove_container "$container"
    done
    
    # Stop docker-compose stack
    if [[ -f "${DOCKER_PATH}/docker-compose.yml" ]]; then
        cd "$DOCKER_PATH"
        docker-compose down || true
    fi
    
    log_info "All PT tools removed"
}

# Remove entire Docker environment
remove_docker_environment() {
    log_warn "Removing entire Docker environment..."
    
    # Stop all containers
    log_info "Stopping all containers..."
    docker stop $(docker ps -aq) 2>/dev/null || true
    
    # Remove all containers
    log_info "Removing all containers..."
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # Remove all images
    log_info "Removing all images..."
    docker rmi $(docker images -q) 2>/dev/null || true
    
    # Clean up volumes
    log_info "Cleaning up volumes..."
    docker volume prune -f 2>/dev/null || true
    
    # Clean up networks
    log_info "Cleaning up networks..."
    docker network prune -f 2>/dev/null || true
    
    log_info "Docker environment cleaned"
}

# Complete system cleanup
complete_cleanup() {
    log_warn "Starting complete system cleanup..."
    
    # Remove all PT tools
    remove_all_pt_tools
    
    # Remove Docker environment
    remove_docker_environment
    
    # Remove PTtools directories
    log_info "Removing PTtools directories..."
    rm -rf "$DOCKER_PATH"
    rm -rf /etc/pttools
    rm -rf /var/log/pttools*
    
    # Revert system optimizations
    log_info "Reverting system optimizations..."
    if [[ -f "/opt/pttools/modules/vps_optimize.sh" ]]; then
        bash /opt/pttools/modules/vps_optimize.sh revert
    else
        # Manual revert
        rm -f /etc/sysctl.d/99-pt-*
        rm -f /etc/security/limits.d/99-pt-*
        rm -f /etc/systemd/system.conf.d/99-pt-*
        rm -f /etc/systemd/user.conf.d/99-pt-*
        sysctl -p
        systemctl daemon-reload
    fi
    
    log_info "Complete system cleanup finished"
}

# Clean orphaned data
clean_orphaned_data() {
    log_info "Cleaning orphaned data..."
    
    # Docker system prune
    docker system prune -af --volumes
    
    # Remove unused networks
    docker network prune -f
    
    # Clean build cache
    docker builder prune -af
    
    log_info "Orphaned data cleaned"
}

# Main uninstall function
main() {
    case "$UNINSTALL_MODE" in
        "selective")
            selective_uninstall
            ;;
        "all")
            remove_all_pt_tools
            clean_orphaned_data
            ;;
        "docker")
            remove_docker_environment
            ;;
        "complete")
            complete_cleanup
            ;;
        *)
            log_error "Unknown uninstall mode: $UNINSTALL_MODE"
            exit 1
            ;;
    esac
    
    log_info "Uninstall process completed"
}

# Run main
main
