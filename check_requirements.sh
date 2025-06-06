#!/bin/bash
# System Requirements Check for PTtools
# This script checks if the system meets the requirements for PTtools

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Requirements
MIN_MEMORY_MB=1024
MIN_DISK_GB=10
MIN_KERNEL="3.10"
REQUIRED_COMMANDS=("wget" "curl" "tar" "gzip")

# Status tracking
CHECKS_PASSED=0
CHECKS_FAILED=0

print_header() {
    echo
    echo "=================================="
    echo "  PTtools System Requirements Check"
    echo "=================================="
    echo
}

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}!${NC} $1"
}

# Check if running as root
check_root() {
    echo -n "Checking root privileges... "
    if [[ $EUID -eq 0 ]]; then
        check_pass "Running as root"
    else
        check_fail "Not running as root (run with sudo)"
    fi
}

# Check OS
check_os() {
    echo -n "Checking operating system... "
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        
        case $OS in
            ubuntu)
                if [[ "${VER%%.*}" -ge 18 ]]; then
                    check_pass "Ubuntu $VER (supported)"
                else
                    check_fail "Ubuntu $VER (requires 18.04+)"
                fi
                ;;
            debian)
                if [[ "${VER%%.*}" -ge 10 ]]; then
                    check_pass "Debian $VER (supported)"
                else
                    check_fail "Debian $VER (requires 10+)"
                fi
                ;;
            centos|rhel)
                if [[ "${VER%%.*}" -ge 7 ]]; then
                    check_pass "CentOS/RHEL $VER (supported)"
                else
                    check_fail "CentOS/RHEL $VER (requires 7+)"
                fi
                ;;
            *)
                check_warn "$PRETTY_NAME (untested, may work)"
                ;;
        esac
    else
        check_fail "Cannot determine OS"
    fi
}

# Check kernel version
check_kernel() {
    echo -n "Checking kernel version... "
    
    kernel_version=$(uname -r | cut -d. -f1,2)
    
    if awk "BEGIN {exit !($kernel_version >= $MIN_KERNEL)}"; then
        check_pass "Kernel $kernel_version"
        
        # Check for BBR support
        if [[ $kernel_version > "4.9" ]] || [[ $kernel_version == "4.9" ]]; then
            check_pass "BBR support available (kernel 4.9+)"
        else
            check_warn "BBR not available (requires kernel 4.9+)"
        fi
    else
        check_fail "Kernel $kernel_version (requires $MIN_KERNEL+)"
    fi
}

# Check CPU
check_cpu() {
    echo -n "Checking CPU... "
    
    cpu_cores=$(nproc)
    cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    
    if [[ $cpu_cores -ge 1 ]]; then
        check_pass "$cpu_cores cores - $cpu_model"
    else
        check_fail "Cannot determine CPU info"
    fi
}

# Check memory
check_memory() {
    echo -n "Checking memory... "
    
    total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_mem_mb=$((total_mem_kb / 1024))
    
    if [[ $total_mem_mb -ge $MIN_MEMORY_MB ]]; then
        check_pass "${total_mem_mb}MB RAM (minimum ${MIN_MEMORY_MB}MB)"
    else
        check_fail "${total_mem_mb}MB RAM (requires ${MIN_MEMORY_MB}MB+)"
    fi
}

# Check disk space
check_disk() {
    echo -n "Checking disk space... "
    
    # Check root partition
    available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ $available_gb -ge $MIN_DISK_GB ]]; then
        check_pass "${available_gb}GB available (minimum ${MIN_DISK_GB}GB)"
    else
        check_fail "${available_gb}GB available (requires ${MIN_DISK_GB}GB+)"
    fi
}

# Check network
check_network() {
    echo -n "Checking network connectivity... "
    
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        check_pass "Internet connection OK"
    else
        check_fail "No internet connection"
    fi
    
    echo -n "Checking DNS resolution... "
    if host github.com >/dev/null 2>&1; then
        check_pass "DNS resolution OK"
    else
        check_fail "DNS resolution failed"
    fi
}

# Check required commands
check_commands() {
    echo "Checking required commands..."
    
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        echo -n "  - $cmd: "
        if command -v "$cmd" >/dev/null 2>&1; then
            check_pass "installed"
        else
            check_fail "not found"
        fi
    done
}

# Check Docker
check_docker() {
    echo -n "Checking Docker... "
    
    if command -v docker >/dev/null 2>&1; then
        docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
        check_pass "Docker $docker_version installed"
        
        echo -n "Checking Docker service... "
        if systemctl is-active --quiet docker 2>/dev/null || service docker status >/dev/null 2>&1; then
            check_pass "Docker service running"
        else
            check_fail "Docker service not running"
        fi
    else
        check_warn "Docker not installed (will be installed by script)"
    fi
    
    echo -n "Checking Docker Compose... "
    if command -v docker-compose >/dev/null 2>&1; then
        compose_version=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
        check_pass "Docker Compose $compose_version installed"
    else
        check_warn "Docker Compose not installed (will be installed by script)"
    fi
}

# Check ports
check_ports() {
    echo "Checking default ports..."
    
    local ports=(8080 9091 8096 3000 3333 3334)
    
    for port in "${ports[@]}"; do
        echo -n "  - Port $port: "
        if ss -tuln | grep -q ":$port "; then
            check_warn "in use"
        else
            check_pass "available"
        fi
    done
}

# Check SELinux
check_selinux() {
    echo -n "Checking SELinux... "
    
    if command -v getenforce >/dev/null 2>&1; then
        selinux_status=$(getenforce)
        if [[ "$selinux_status" == "Enforcing" ]]; then
            check_warn "SELinux is enforcing (may need configuration)"
        else
            check_pass "SELinux is $selinux_status"
        fi
    else
        check_pass "SELinux not present"
    fi
}

# Check firewall
check_firewall() {
    echo -n "Checking firewall... "
    
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        check_warn "firewalld is active (configure ports as needed)"
    elif systemctl is-active --quiet ufw 2>/dev/null; then
        check_warn "ufw is active (configure ports as needed)"
    elif iptables -L >/dev/null 2>&1; then
        if [[ $(iptables -L | wc -l) -gt 8 ]]; then
            check_warn "iptables has rules (check port access)"
        else
            check_pass "No restrictive firewall rules detected"
        fi
    else
        check_pass "No firewall detected"
    fi
}

# Generate report
generate_report() {
    echo
    echo "=================================="
    echo "        Check Summary"
    echo "=================================="
    echo -e "Checks passed: ${GREEN}$CHECKS_PASSED${NC}"
    echo -e "Checks failed: ${RED}$CHECKS_FAILED${NC}"
    echo
    
    if [[ $CHECKS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ System meets all requirements!${NC}"
        echo "You can proceed with PTtools installation."
        return 0
    else
        echo -e "${RED}✗ System does not meet all requirements.${NC}"
        echo "Please fix the failed checks before proceeding."
        return 1
    fi
}

# Main
main() {
    print_header
    
    echo "System Information:"
    echo "==================="
    check_root
    check_os
    check_kernel
    check_cpu
    check_memory
    check_disk
    
    echo
    echo "Network:"
    echo "========="
    check_network
    
    echo
    echo "Software:"
    echo "=========="
    check_commands
    check_docker
    
    echo
    echo "Configuration:"
    echo "=============="
    check_ports
    check_selinux
    check_firewall
    
    generate_report
}

# Run checks
main
