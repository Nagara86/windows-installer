#!/bin/bash

# Logging dan warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    local type=$1
    local message=$2
    local color=$NC

    case $type in
        "error")
            color=$RED
            ;;
        "success")
            color=$GREEN
            ;;
        "warning")
            color=$YELLOW
            ;;
    esac

    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] $message${NC}"
}

# Fungsi cek root
check_root() {
    if [[ $EUID -ne 0 ]]; then 
        log "error" "Script harus dijalankan sebagai root"
        exit 1
    fi
}

# Fungsi cek versi Ubuntu
check_ubuntu_version() {
    if ! command -v lsb_release &> /dev/null; then
        apt-get update && apt-get install -y lsb-release
    fi
    
    local VERSION=$(lsb_release -rs)
    if [[ "$VERSION" != "20.04" ]]; then
        log "warning" "Script dioptimalkan untuk Ubuntu 20.04"
        log "warning" "Versi saat ini: Ubuntu $VERSION"
        read -p "Lanjutkan? (y/n): " confirm
        [[ $confirm != [yY] ]] && exit 1
    fi
    
    log "success" "Versi Ubuntu $VERSION terdeteksi - Kompatibel"
}

# Fungsi cek persyaratan sistem
check_system_requirements() {
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    local cpu_cores=$(nproc)
    local free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

    if [[ $total_ram -lt 2800 ]]; then
        log "error" "RAM tidak mencukupi. Minimal 2.8GB diperlukan. Saat ini: ${total_ram}MB"
        exit 1
    fi
    
    if [[ $cpu_cores -lt 2 ]]; then
        log "error" "Core CPU tidak mencukupi. Minimal 2 core diperlukan. Saat ini: $cpu_cores"
        exit 1
    fi
    
    if [[ $free_space -lt 25 ]]; then
        log "error" "Ruang disk tidak mencukupi. Minimal 25GB diperlukan. Saat ini: ${free_space}GB"
        exit 1
    fi
    
    log "success" "Pemeriksaan persyaratan sistem berhasil"
}

# Fungsi optimasi sistem
optimize_system() {
    log "warning" "Mengoptimalkan sistem..."
    
    apt-get clean
    sync
    echo 3 > /proc/sys/vm/drop_caches
    
    systemctl stop apache2 2>/dev/null
    systemctl stop mysql 2>/dev/null
    systemctl stop postgresql 2>/dev/null
    
    echo 10 > /proc/sys/vm/swappiness
    
    log "success" "Sistem berhasil dioptimalkan"
}

# Fungsi instalasi paket
install_required_packages() {
    log "warning" "Menginstal paket yang diperlukan..."
    
    apt-get update
    apt-get install -y wget gzip curl mount ntfs-3g
    
    if [[ $? -ne 0 ]]; then
        log "error" "Gagal menginstal paket"
        exit 1
    fi
    
    log "success" "Paket berhasil diinstal"
}

# Fungsi utama
main() {
    check_root
    check_ubuntu_version
    check_system_requirements
    optimize_system
    install_required_packages
}

# Jalankan fungsi utama
main
