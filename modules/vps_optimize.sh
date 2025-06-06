#!/bin/bash
# VPS Optimization Module for PTtools
# Optimizes VPS settings for PT traffic performance

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Backup directory
BACKUP_DIR="/etc/pttools/backups/$(date +%Y%m%d_%H%M%S)"

log_info() {
    echo -e "${GREEN}[OPTIMIZE]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[OPTIMIZE]${NC} $*"
}

log_error() {
    echo -e "${RED}[OPTIMIZE]${NC} $*"
}

# Create system backup
backup_system_config() {
    log_info "Creating system configuration backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup important files
    cp -p /etc/sysctl.conf "$BACKUP_DIR/" 2>/dev/null || true
    cp -rp /etc/sysctl.d/ "$BACKUP_DIR/" 2>/dev/null || true
    cp -p /etc/security/limits.conf "$BACKUP_DIR/" 2>/dev/null || true
    cp -rp /etc/security/limits.d/ "$BACKUP_DIR/" 2>/dev/null || true
    
    # Save current network settings
    sysctl -a > "$BACKUP_DIR/sysctl_current.txt" 2>/dev/null
    
    log_info "Backup created at: $BACKUP_DIR"
}

# Optimize TCP/IP stack
optimize_network_stack() {
    log_info "Optimizing network stack for PT traffic..."
    
    cat > /etc/sysctl.d/99-pt-network-optimization.conf << 'EOF'
# PT Tools Network Optimization
# Optimized for high-throughput BitTorrent traffic

# Core Network Buffer Sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 31457280
net.core.wmem_default = 31457280
net.core.optmem_max = 40960

# TCP Buffer Sizes (min, default, max)
net.ipv4.tcp_rmem = 8192 87380 134217728
net.ipv4.tcp_wmem = 8192 65536 134217728
net.ipv4.tcp_mem = 786432 1048576 26777216

# Connection Management
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65536
net.core.netdev_budget = 600
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3

# Port Range for Connections
net.ipv4.ip_local_port_range = 2000 65535

# TCP Performance
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1

# Connection Tracking
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 1800

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0

# Enable BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Security
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF
    
    # Apply settings
    sysctl -p /etc/sysctl.d/99-pt-network-optimization.conf
    
    log_info "Network stack optimization completed"
}

# Setup BBR congestion control
setup_bbr() {
    log_info "Setting up BBR congestion control..."
    
    # Check kernel version
    kernel_version=$(uname -r | cut -d. -f1,2)
    required_version="4.9"
    
    if awk "BEGIN {exit !($kernel_version >= $required_version)}"; then
        # Check if BBR module is available
        if modinfo tcp_bbr &> /dev/null; then
            # Load BBR module
            modprobe tcp_bbr
            
            # Make it persistent
            echo "tcp_bbr" > /etc/modules-load.d/bbr.conf
            
            # Set BBR as default
            echo "net.core.default_qdisc = fq" >> /etc/sysctl.d/99-pt-network-optimization.conf
            echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.d/99-pt-network-optimization.conf
            
            sysctl -p /etc/sysctl.d/99-pt-network-optimization.conf
            
            log_info "BBR congestion control enabled"
        else
            log_warn "BBR module not available in current kernel"
        fi
    else
        log_warn "Kernel version $kernel_version is too old for BBR (requires 4.9+)"
    fi
}

# Optimize file system
optimize_filesystem() {
    log_info "Optimizing file system for torrent workloads..."
    
    # Increase file descriptor limits
    cat > /etc/security/limits.d/99-pt-limits.conf << EOF
# PT Tools File Descriptor Limits
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 131072
* hard nproc 131072
root soft nofile 1048576
root hard nofile 1048576
root soft nproc 131072
root hard nproc 131072
EOF
    
    # Update systemd limits
    if systemctl --version &> /dev/null; then
        mkdir -p /etc/systemd/system.conf.d/
        cat > /etc/systemd/system.conf.d/99-pt-limits.conf << EOF
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=131072
EOF
        
        mkdir -p /etc/systemd/user.conf.d/
        cat > /etc/systemd/user.conf.d/99-pt-limits.conf << EOF
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=131072
EOF
        
        systemctl daemon-reload
    fi
    
    log_info "File system optimization completed"
}

# Optimize disk I/O
optimize_disk_io() {
    log_info "Optimizing disk I/O scheduler..."
    
    # Detect disk devices
    for disk in $(lsblk -dno NAME | grep -E '^(sd|vd|nvme)'); do
        # Check if disk is rotational (HDD) or not (SSD)
        rotational=$(cat /sys/block/$disk/queue/rotational 2>/dev/null || echo "1")
        
        if [[ "$rotational" == "0" ]]; then
            # SSD: use none/noop scheduler
            if [[ -f /sys/block/$disk/queue/scheduler ]]; then
                echo none > /sys/block/$disk/queue/scheduler 2>/dev/null || \
                echo noop > /sys/block/$disk/queue/scheduler 2>/dev/null || true
                log_info "Set none/noop scheduler for SSD: $disk"
            fi
        else
            # HDD: use deadline scheduler
            if [[ -f /sys/block/$disk/queue/scheduler ]]; then
                echo deadline > /sys/block/$disk/queue/scheduler 2>/dev/null || \
                echo mq-deadline > /sys/block/$disk/queue/scheduler 2>/dev/null || true
                log_info "Set deadline scheduler for HDD: $disk"
            fi
        fi
        
        # Optimize read-ahead
        if [[ -f /sys/block/$disk/queue/read_ahead_kb ]]; then
            echo 2048 > /sys/block/$disk/queue/read_ahead_kb
        fi
    done
    
    log_info "Disk I/O optimization completed"
}

# Optimize swap settings
optimize_swap() {
    log_info "Optimizing swap settings..."
    
    # Reduce swappiness for better performance
    echo "vm.swappiness = 10" >> /etc/sysctl.d/99-pt-network-optimization.conf
    echo "vm.vfs_cache_pressure = 50" >> /etc/sysctl.d/99-pt-network-optimization.conf
    echo "vm.dirty_ratio = 20" >> /etc/sysctl.d/99-pt-network-optimization.conf
    echo "vm.dirty_background_ratio = 10" >> /etc/sysctl.d/99-pt-network-optimization.conf
    
    sysctl -p /etc/sysctl.d/99-pt-network-optimization.conf
    
    log_info "Swap optimization completed"
}

# Install and configure monitoring tools
setup_monitoring() {
    log_info "Setting up performance monitoring..."
    
    # Install useful monitoring tools
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y htop iotop iftop nethogs vnstat sysstat
    elif command -v yum &> /dev/null; then
        yum install -y htop iotop iftop nethogs vnstat sysstat
    fi
    
    # Enable sysstat
    if command -v systemctl &> /dev/null; then
        systemctl enable sysstat || true
        systemctl start sysstat || true
    fi
    
    log_info "Performance monitoring tools installed"
}

# Create optimization report
generate_report() {
    local report_file="/etc/pttools/optimization_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
PT Tools VPS Optimization Report
Generated: $(date)
================================

System Information:
- Kernel: $(uname -r)
- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
- CPU: $(nproc) cores
- RAM: $(free -h | grep Mem | awk '{print $2}')
- Disk: $(df -h / | tail -1 | awk '{print $2}')

Applied Optimizations:
1. Network Stack: Optimized TCP buffers and connection handling
2. BBR: $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
3. File Descriptors: $(ulimit -n)
4. Disk Schedulers: Optimized for SSD/HDD
5. Swap Settings: Reduced swappiness to 10

Network Settings:
$(sysctl -a 2>/dev/null | grep -E "net.core.(r|w)mem_(max|default)")

Current Performance:
- Load Average: $(uptime | awk -F'load average:' '{print $2}')
- Network Connections: $(ss -s | grep estab | awk '{print $4}')

Backup Location: $BACKUP_DIR
================================
EOF
    
    log_info "Optimization report saved to: $report_file"
    cat "$report_file"
}

# Revert optimizations
revert_optimizations() {
    log_warn "Reverting system optimizations..."
    
    # Remove optimization files
    rm -f /etc/sysctl.d/99-pt-network-optimization.conf
    rm -f /etc/security/limits.d/99-pt-limits.conf
    rm -f /etc/systemd/system.conf.d/99-pt-limits.conf
    rm -f /etc/systemd/user.conf.d/99-pt-limits.conf
    rm -f /etc/modules-load.d/bbr.conf
    
    # Reload settings
    sysctl -p
    systemctl daemon-reload
    
    log_info "System optimizations reverted"
}

# Main optimization function
main() {
    log_info "Starting VPS optimization for PT traffic..."
    
    # Create backup
    backup_system_config
    
    # Apply optimizations
    optimize_network_stack
    setup_bbr
    optimize_filesystem
    optimize_disk_io
    optimize_swap
    setup_monitoring
    
    # Generate report
    generate_report
    
    log_info "VPS optimization completed successfully!"
    log_info "A system reboot is recommended to apply all changes"
}

# Check if running as revert
if [[ "${1:-}" == "revert" ]]; then
    revert_optimizations
else
    main
fi
