#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Please run as root (use sudo)${NC}"
        exit 1
    fi
}

# Function to check Ubuntu version
check_ubuntu_version() {
    if ! command -v lsb_release >/dev/null 2>&1; then
        apt-get update && apt-get install -y lsb-release
    fi
    
    VERSION=$(lsb_release -rs)
    if [[ "$VERSION" != "20.04" ]]; then
        echo -e "${RED}This script is optimized for Ubuntu 20.04${NC}"
        echo -e "${YELLOW}Current version: Ubuntu $VERSION${NC}"
        exit 1
    fi
    echo -e "${GREEN}Ubuntu version $VERSION detected - Compatible${NC}"
}

# Function to check system requirements
check_system_requirements() {
    # Check RAM
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ $total_ram -lt 2800 ]; then  # Changed to 2.8GB minimum
        echo -e "${RED}Insufficient RAM. Minimum 2.8GB required. Current: ${total_ram}MB${NC}"
        exit 1
    fi
    
    # Check CPU cores
    cpu_cores=$(nproc)
    if [ $cpu_cores -lt 2 ]; then
        echo -e "${RED}Insufficient CPU cores. Minimum 2 cores required. Current: $cpu_cores${NC}"
        exit 1
    fi
    
    # Check available disk space
    free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ $free_space -lt 25 ]; then  # Reduced minimum space requirement
        echo -e "${RED}Insufficient disk space. Minimum 25GB required. Current: ${free_space}GB${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}System requirements check passed${NC}"
}

# Function to optimize system for Windows installation
optimize_system() {
    # Clean package cache
    apt-get clean
    
    # Clear system memory cache
    sync; echo 3 > /proc/sys/vm/drop_caches
    
    # Disable unnecessary services
    systemctl stop apache2 2>/dev/null
    systemctl stop mysql 2>/dev/null
    systemctl stop postgresql 2>/dev/null
    
    # Set swappiness to improve performance
    echo 10 > /proc/sys/vm/swappiness
    
    echo -e "${GREEN}System optimized for installation${NC}"
}

# Function to install required packages
install_required_packages() {
    echo "Installing required packages..."
    apt-get update
    apt-get install -y wget gzip curl mount ntfs-3g
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install required packages${NC}"
        exit 1
    fi
    echo -e "${GREEN}Required packages installed successfully${NC}"
}

# Rest of the script remains the same as before...
[Previous installation code continues...]
