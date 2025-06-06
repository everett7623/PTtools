#!/bin/bash
# PT Tools Installation Script
# Author: everett7623
# Version: 1.0.0
# Description: One-click installation script for PT tools

set -euo pipefail

# Script Configuration
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
GITHUB_RAW="https://raw.githubusercontent.com/everett7623/pttools/main"

# Default Configuration
DEFAULT_DOCKER_PATH="/opt/docker"
DEFAULT_DOWNLOAD_PATH="/opt/downloads"
INSTALLATION_LOG="/var/log/pttools-install.log"
CONFIG_FILE="/etc/pttools/config.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Rollback stack for error handling
ROLLBACK_STACK=()

# Installation registry
declare -A INSTALLED_APPS

# ===============================================
# Basic Functions
# ===============================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$INSTALLATION_LOG"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$INSTALLATION_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$INSTALLATION_LOG"
}

print_separator() {
    echo "========================================"
}

# Error handler
error_handler() {
    local exit_code=$1
    local line_number=$2
    local bash_lineno=$3
    local last_command=$4
    
    log_error "Installation failed with exit code $exit_code at line $line_number"
    log_error "Command: $last_command"
    
    execute_rollback
    
    exit $exit_code
}

trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND"' ERR

# Rollback registration
rb() {
    ROLLBACK_STACK+=("$*")
}

execute_rollback() {
    if [[ ${#ROLLBACK_STACK[@]} -gt 0 ]]; then
        log_info "Executing rollback operations..."
        for (( i=${#ROLLBACK_STACK[@]}-1; i>=0; i-- )); do
            log_info "Rollback: ${ROLLBACK_STACK[i]}"
            eval "${ROLLBACK_STACK[i]}" || true
        done
    fi
}

# ===============================================
# System Checks and Validation
# ===============================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "Cannot determine OS version"
        exit 1
    fi
    
    case $OS in
        ubuntu|debian)
            log_info "Detected OS: $OS $VER"
            ;;
        centos|rhel|fedora)
            log_info "Detected OS: $OS $VER"
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

check_dependencies() {
    local deps=("wget" "curl" "docker" "docker-compose")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing dependencies: ${missing[*]}"
        install_dependencies "${missing[@]}"
    fi
}

install_dependencies() {
    log_info "Installing dependencies..."
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y "$@"
            ;;
        centos|rhel|fedora)
            yum install -y "$@"
            ;;
    esac
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com | bash
        systemctl enable docker
        systemctl start docker
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker-compose &> /dev/null; then
        log_info "Installing Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
}

# ===============================================
# Configuration Management
# ===============================================

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        create_default_config
    fi
}

create_default_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
# PTtools Configuration File
DOCKER_PATH="${DEFAULT_DOCKER_PATH}"
DOWNLOAD_PATH="${DEFAULT_DOWNLOAD_PATH}"
SEEDBOX_USER="admin"
SEEDBOX_PASSWORD="adminadmin"
WEBUI_PORT=8080
DAEMON_PORT=23333
QB_PASSWORD="adminadmin"
PASSKEY=""
EOF
    log_info "Created default configuration file at $CONFIG_FILE"
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
# PTtools Configuration File
DOCKER_PATH="${DOCKER_PATH}"
DOWNLOAD_PATH="${DOWNLOAD_PATH}"
SEEDBOX_USER="${SEEDBOX_USER}"
SEEDBOX_PASSWORD="${SEEDBOX_PASSWORD}"
WEBUI_PORT=${WEBUI_PORT}
DAEMON_PORT=${DAEMON_PORT}
QB_PASSWORD="${QB_PASSWORD}"
PASSKEY="${PASSKEY}"
EOF
}

# ===============================================
# User Input Functions
# ===============================================

prompt_user() {
    local prompt="$1"
    local default="${2:-}"
    local response
    
    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " response
        echo "${response:-$default}"
    else
        read -p "$prompt: " response
        echo "$response"
    fi
}

prompt_password() {
    local prompt="$1"
    local password
    
    read -s -p "$prompt: " password
    echo
    echo "$password"
}

validate_port() {
    local port="$1"
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        log_error "Invalid port number: $port"
        return 1
    fi
    
    if ss -tulwn | grep -q ":$port "; then
        log_warn "Port $port is already in use"
        return 1
    fi
    
    return 0
}

# ===============================================
# Docker Management Functions
# ===============================================

setup_docker_environment() {
    log_info "Setting up Docker environment..."
    
    # Create necessary directories
    mkdir -p "$DOCKER_PATH"
    chmod -R 777 "$DOCKER_PATH"
    
    mkdir -p "$DOWNLOAD_PATH"
    chmod -R 777 "$DOWNLOAD_PATH"
    
    # Create sub-directories for each application
    local apps=("qbittorrent" "transmission" "emby" "iyuuplus" "moviepilot" "vertex" "nas-tools" "filebrowser" "metatube" "byte-muse")
    for app in "${apps[@]}"; do
        mkdir -p "$DOCKER_PATH/$app"
    done
    
    log_info "Docker environment setup completed"
}

# ===============================================
# Main Menu Functions
# ===============================================

show_banner() {
    clear
    cat << 'EOF'
 ____  _____   _____           _     
|  _ \|_   _| |_   _|___  ___ | |___ 
| |_) | | |     | | / _ \/ _ \| / __|
|  __/  | |     | || (_) | (_) | \__ \
|_|     |_|     |_| \___/ \___/|_|___/
                                      
EOF
    echo "Version: $SCRIPT_VERSION"
    echo "Author: everett7623"
    print_separator
}

show_main_menu() {
    show_banner
    echo "Main Menu:"
    echo "1. Install qBittorrent 4.3.8"
    echo "2. Install qBittorrent 4.3.9 (Jerry's)"
    echo "3. Install qBittorrent 4.3.8 + Vertex"
    echo "4. Install qBittorrent 4.3.9 + Vertex"
    echo "5. Install Selected Applications"
    echo "6. VPS Optimization"
    echo "7. Uninstall Options"
    echo "8. Exit"
    print_separator
    
    local choice
    read -p "Enter your choice [1-8]: " choice
    
    case $choice in
        1) install_qb_438 ;;
        2) install_qb_439_jerry ;;
        3) install_qb_438_vertex ;;
        4) install_qb_439_vertex ;;
        5) show_app_selection_menu ;;
        6) optimize_vps ;;
        7) show_uninstall_menu ;;
        8) exit_script ;;
        *) 
            log_error "Invalid choice"
            sleep 2
            show_main_menu
            ;;
    esac
}

# ===============================================
# qBittorrent Installation Functions
# ===============================================

install_qb_438() {
    log_info "Installing qBittorrent 4.3.8..."
    
    # Get user inputs
    SEEDBOX_USER=$(prompt_user "Enter username" "${SEEDBOX_USER}")
    PASSKEY=$(prompt_user "Enter passkey" "${PASSKEY}")
    WEBUI_PORT=$(prompt_user "Enter WebUI port" "${WEBUI_PORT}")
    DAEMON_PORT=$(prompt_user "Enter daemon port" "${DAEMON_PORT}")
    
    # Validate inputs
    validate_port "$WEBUI_PORT" || return 1
    validate_port "$DAEMON_PORT" || return 1
    
    # Save configuration
    save_config
    
    # Run installation script
    log_info "Running qBittorrent 4.3.8 installation script..."
    bash <(wget -qO- https://raw.githubusercontent.com/everett7623/pttools/main/modules/qb438.sh) \
        "$SEEDBOX_USER" "$PASSKEY" "$WEBUI_PORT" "$DAEMON_PORT"
    
    register_installation "qbittorrent" "4.3.8"
    log_info "qBittorrent 4.3.8 installation completed"
    
    read -p "Press Enter to continue..."
    show_main_menu
}

install_qb_439_jerry() {
    log_info "Installing qBittorrent 4.3.9 using Jerry's script..."
    
    # Get user inputs
    local username=$(prompt_user "Enter username" "${SEEDBOX_USER}")
    local password=$(prompt_password "Enter password")
    local cache_size=$(prompt_user "Enter cache size (MiB)" "2048")
    local custom_port=$(prompt_user "Enter custom port (leave empty for default)" "")
    
    # Build command
    local cmd="bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh)"
    cmd+=" -u $username -p $password -c $cache_size -q 4.3.9 -l v1.2.20"
    
    if [[ -n "$custom_port" ]]; then
        cmd+=" -o $custom_port"
    fi
    
    # Run installation
    log_info "Running Jerry's qBittorrent 4.3.9 installation script..."
    eval "$cmd"
    
    register_installation "qbittorrent" "4.3.9"
    log_info "qBittorrent 4.3.9 installation completed"
    
    read -p "Press Enter to continue..."
    show_main_menu
}

install_qb_438_vertex() {
    log_info "Installing qBittorrent 4.3.8 + Vertex..."
    
    # First install qBittorrent 4.3.8
    install_qb_438
    
    # Then install Vertex
    install_vertex "4.3.8"
    
    log_info "qBittorrent 4.3.8 + Vertex installation completed"
    read -p "Press Enter to continue..."
    show_main_menu
}

install_qb_439_vertex() {
    log_info "Installing qBittorrent 4.3.9 + Vertex..."
    
    # First install qBittorrent 4.3.9
    install_qb_439_jerry
    
    # Then install Vertex
    install_vertex "4.3.9"
    
    log_info "qBittorrent 4.3.9 + Vertex installation completed"
    read -p "Press Enter to continue..."
    show_main_menu
}

install_vertex() {
    local qb_version="$1"
    log_info "Installing Vertex for qBittorrent $qb_version..."
    
    # Download and run Vertex installation module
    wget -qO- "$GITHUB_RAW/modules/install_vertex.sh" | bash -s "$qb_version" "$DOCKER_PATH"
    
    register_installation "vertex" "latest"
}

# ===============================================
# Application Selection Menu
# ===============================================

show_app_selection_menu() {
    show_banner
    echo "Select Applications to Install:"
    echo
    echo "Download Management:"
    echo "  1. qBittorrent (Docker)"
    echo "  2. Transmission"
    echo
    echo "Automation Tools:"
    echo "  3. IYUUPlus"
    echo "  4. MoviePilot"
    echo "  5. Vertex"
    echo "  6. NAS-Tools"
    echo
    echo "Media Servers:"
    echo "  7. Emby"
    echo
    echo "File Management:"
    echo "  8. FileBrowser"
    echo
    echo "Special Tools:"
    echo "  9. MetaTube"
    echo "  10. Byte-Muse"
    echo
    echo "0. Back to Main Menu"
    print_separator
    
    echo "Enter numbers separated by space (e.g., 1 3 5): "
    read -a selections
    
    if [[ "${selections[0]}" == "0" ]]; then
        show_main_menu
        return
    fi
    
    # Process selections
    local selected_apps=()
    for sel in "${selections[@]}"; do
        case $sel in
            1) selected_apps+=("qbittorrent") ;;
            2) selected_apps+=("transmission") ;;
            3) selected_apps+=("iyuuplus") ;;
            4) selected_apps+=("moviepilot") ;;
            5) selected_apps+=("vertex") ;;
            6) selected_apps+=("nas-tools") ;;
            7) selected_apps+=("emby") ;;
            8) selected_apps+=("filebrowser") ;;
            9) selected_apps+=("metatube") ;;
            10) selected_apps+=("byte-muse") ;;
        esac
    done
    
    if [[ ${#selected_apps[@]} -gt 0 ]]; then
        install_docker_apps "${selected_apps[@]}"
    else
        log_error "No valid selections made"
    fi
    
    read -p "Press Enter to continue..."
    show_main_menu
}

install_docker_apps() {
    local apps=("$@")
    
    log_info "Installing selected applications: ${apps[*]}"
    
    # Setup Docker environment
    setup_docker_environment
    
    # Generate docker-compose.yml
    wget -qO- "$GITHUB_RAW/modules/generate_compose.sh" | bash -s "$DOCKER_PATH" "${apps[@]}"
    
    # Start Docker containers
    cd "$DOCKER_PATH"
    docker-compose up -d
    
    # Register installations
    for app in "${apps[@]}"; do
        register_installation "$app" "latest"
    done
    
    log_info "Docker applications installation completed"
}

# ===============================================
# VPS Optimization
# ===============================================

optimize_vps() {
    log_info "Starting VPS optimization for PT traffic..."
    
    # Download and run optimization module
    wget -qO- "$GITHUB_RAW/modules/vps_optimize.sh" | bash
    
    log_info "VPS optimization completed"
    read -p "Press Enter to continue..."
    show_main_menu
}

# ===============================================
# Uninstall Functions
# ===============================================

show_uninstall_menu() {
    show_banner
    echo "Uninstall Options:"
    echo "1. Remove specific application"
    echo "2. Remove all PT tools"
    echo "3. Remove all Docker containers"
    echo "4. Complete system cleanup"
    echo "5. Back to main menu"
    print_separator
    
    local choice
    read -p "Enter your choice [1-5]: " choice
    
    case $choice in
        1) selective_uninstall ;;
        2) remove_all_pt_tools ;;
        3) remove_docker_environment ;;
        4) complete_system_cleanup ;;
        5) show_main_menu ;;
        *) 
            log_error "Invalid choice"
            show_uninstall_menu
            ;;
    esac
}

selective_uninstall() {
    log_info "Loading uninstall module..."
    wget -qO- "$GITHUB_RAW/modules/uninstall.sh" | bash -s "selective"
    read -p "Press Enter to continue..."
    show_uninstall_menu
}

remove_all_pt_tools() {
    log_warn "This will remove all PT tools"
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        wget -qO- "$GITHUB_RAW/modules/uninstall.sh" | bash -s "all"
    fi
    
    read -p "Press Enter to continue..."
    show_uninstall_menu
}

remove_docker_environment() {
    log_warn "This will remove all Docker containers and images"
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        wget -qO- "$GITHUB_RAW/modules/uninstall.sh" | bash -s "docker"
    fi
    
    read -p "Press Enter to continue..."
    show_uninstall_menu
}

complete_system_cleanup() {
    log_warn "This will remove EVERYTHING and revert system changes"
    read -p "Are you sure? Type 'yes' to confirm: " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        wget -qO- "$GITHUB_RAW/modules/uninstall.sh" | bash -s "complete"
    fi
    
    read -p "Press Enter to continue..."
    show_uninstall_menu
}

# ===============================================
# Utility Functions
# ===============================================

register_installation() {
    local app_name="$1"
    local version="$2"
    local install_path="${3:-$DOCKER_PATH/$app_name}"
    
    # Save to installation registry
    echo "$app_name|$version|$install_path|$(date '+%Y-%m-%d %H:%M:%S')" >> /etc/pttools/installed.list
}

list_installed_tools() {
    if [[ -f /etc/pttools/installed.list ]]; then
        cat /etc/pttools/installed.list
    fi
}

exit_script() {
    log_info "Exiting PT Tools installer..."
    exit 0
}

# ===============================================
# Main Execution
# ===============================================

main() {
    # Initial checks
    check_root
    check_os
    
    # Create log directory
    mkdir -p "$(dirname "$INSTALLATION_LOG")"
    
    log_info "Starting PT Tools Installation Script v$SCRIPT_VERSION"
    
    # Load configuration
    load_config
    
    # Check dependencies
    check_dependencies
    
    # Show main menu
    show_main_menu
}

# Run main function
main "$@"
