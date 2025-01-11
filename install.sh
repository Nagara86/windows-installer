#!/bin/bash

# Windows Server 2016 Installation Script
# Enhanced version with better security and features
# For Ubuntu 20.04 VPS (2vCPU, 3GB RAM, 80GB disk)

# Strict error handling
set -euo pipefail
IFS=$'\n\t'

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function definitions
print_status() { echo -e "${GREEN}[*] $1${NC}"; }
print_error() { echo -e "${RED}[!] $1${NC}"; exit 1; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
print_info() { echo -e "${BLUE}[+] $1${NC}"; }

# Banner
echo "================================================================"
echo "   Windows Server 2016 Installation Script - Enhanced Version"
echo "   For Ubuntu 20.04 VPS"
echo "================================================================"

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    print_error "Script harus dijalankan sebagai root (sudo)"
fi

# System requirements check
print_status "Memeriksa spesifikasi sistem..."

# Memory check
mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
mem_gb=$((mem_kb / 1024 / 1024))
if [ $mem_gb -lt 3 ]; then
    print_error "Minimal RAM 3GB diperlukan. Terdeteksi: ${mem_gb}GB"
fi
print_info "RAM: ${mem_gb}GB [OK]"

# Disk space check
disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
if [ $disk_gb -lt 80 ]; then
    print_error "Minimal disk space 80GB diperlukan. Terdeteksi: ${disk_gb}GB"
fi
print_info "Disk Space: ${disk_gb}GB [OK]"

# CPU check
cpu_count=$(nproc)
if [ $cpu_count -lt 2 ]; then
    print_error "Minimal 2 CPU cores diperlukan. Terdeteksi: ${cpu_count}"
fi
print_info "CPU Cores: ${cpu_count} [OK]"

# Install required packages
print_status "Menginstall paket yang diperlukan..."
apt-get update -qq || print_error "Gagal update package list"
apt-get install -y wget gzip ntfs-3g curl fdisk gdisk parted -qq || print_error "Gagal install packages"

# Configuration variables
ISO_URL="https://software-static.download.prss.microsoft.com/pr/download/Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.ISO"
ISO_PATH="/tmp/windows.iso"
MOUNT_PATH="/mnt/windows"

# Get network information
print_status "Mengambil informasi jaringan..."
IP4=$(curl -4 -s icanhazip.com) || print_error "Gagal mendapatkan IP address"
GW=$(ip route | awk '/default/ { print $3 }') || print_error "Gagal mendapatkan Gateway"
print_info "IP Address: ${IP4}"
print_info "Gateway: ${GW}"

# Password setup with requirements
print_status "Setup password Administrator..."
while true; do
    read -sp "Masukkan password Administrator (min. 12 karakter, harus mengandung huruf besar, kecil, dan angka): " PASSADMIN
    echo
    if [[ ${#PASSADMIN} -ge 12 && "$PASSADMIN" =~ [A-Z] && "$PASSADMIN" =~ [a-z] && "$PASSADMIN" =~ [0-9] ]]; then
        break
    else
        print_error "Password tidak memenuhi persyaratan keamanan! Silakan coba lagi."
    fi
done

# Create Windows configuration scripts
print_status "Membuat script konfigurasi Windows..."

# Network configuration script
cat >/tmp/net.bat<<EOF
@ECHO OFF
ECHO Setting up network configuration...
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (del /f /q "%windir%\GetAdmin") else (
    echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs"
    "%temp%\Admin.vbs"
    del /f /q "%temp%\Admin.vbs"
    exit /b 2
)

net user Administrator ${PASSADMIN}
wmic useraccount where "name='Administrator'" set PasswordExpires=false

netsh interface ip set address name="Ethernet Instance 0" source=static address=${IP4} mask=255.255.240.0 gateway=${GW}
netsh interface ip add dns name="Ethernet Instance 0" addr=8.8.8.8 index=1
netsh interface ip add dns name="Ethernet Instance 0" addr=8.8.4.4 index=2

REM Enable Remote Desktop
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

cd /d "%ProgramData%/Microsoft/Windows/Start Menu/Programs/Startup"
del /f /q net.bat
exit
EOF

# System optimization script
cat >/tmp/optimize.bat<<EOF
@ECHO OFF
ECHO Optimizing system configuration...
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (del /f /q "%windir%\GetAdmin") else (
    echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs"
    "%temp%\Admin.vbs"
    del /f /q "%temp%\Admin.vbs"
    exit /b 2
)

REM Disable unnecessary services
sc config "WSearch" start= disabled
sc config "wuauserv" start= disabled
sc config "BITS" start= disabled

REM Configure Windows Firewall
netsh advfirewall firewall add rule name="RDP" dir=in action=allow protocol=TCP localport=3389
netsh advfirewall firewall add rule name="ICMP" dir=in action=allow protocol=icmpv4

REM Optimize performance settings
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "IoPageLockLimit" /t REG_DWORD /d 983040 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "MaxUserPort" /t REG_DWORD /d 65534 /f

REM Extend disk partition
ECHO SELECT VOLUME=%%SystemDrive%% > "%SystemDrive%\diskpart.extend"
ECHO EXTEND >> "%SystemDrive%\diskpart.extend"
START /WAIT DISKPART /S "%SystemDrive%\diskpart.extend"
del /f /q "%SystemDrive%\diskpart.extend"

cd /d "%ProgramData%/Microsoft/Windows/Start Menu/Programs/Startup"
del /f /q optimize.bat
exit
EOF

# Download Windows ISO
print_status "Downloading Windows Server 2016 ISO..."
wget --no-check-certificate -O "${ISO_PATH}" "${ISO_URL}" || print_error "Gagal download Windows ISO"

# Prepare disk
print_status "Mempersiapkan disk..."
# Clear partition table
dd if=/dev/zero of=/dev/vda bs=512 count=1 conv=notrunc

# Create new partition table and partitions
parted -s /dev/vda mklabel gpt
parted -s /dev/vda mkpart primary ntfs 1MiB 100%
parted -s /dev/vda set 1 boot on

# Install Windows
print_status "Menginstall Windows..."
dd if="${ISO_PATH}" of=/dev/vda bs=4M status=progress || print_error "Gagal write Windows ke disk"

# Mount and configure
print_status "Mengkonfigurasi Windows..."
mkdir -p "${MOUNT_PATH}"
sleep 5  # Wait for device to settle
mount.ntfs-3g /dev/vda1 "${MOUNT_PATH}" || print_error "Gagal mount Windows partition"

# Copy configuration files
STARTUP_PATH="${MOUNT_PATH}/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup"
mkdir -p "${STARTUP_PATH}"
cp /tmp/net.bat "${STARTUP_PATH}/net.bat"
cp /tmp/optimize.bat "${STARTUP_PATH}/optimize.bat"

# Cleanup
print_status "Membersihkan temporary files..."
umount "${MOUNT_PATH}"
rm -f "${ISO_PATH}" /tmp/net.bat /tmp/optimize.bat
rmdir "${MOUNT_PATH}"

# Installation complete
echo "================================================================"
print_status "Instalasi selesai! Informasi koneksi:"
print_info "IP Address: ${IP4}"
print_info "Port: 3389"
print_info "Username: Administrator"
print_info "Password: [sesuai yang anda setting]"
echo "================================================================"
print_warning "Sistem akan restart dalam 10 detik..."
print_warning "Tunggu 3-5 menit setelah restart untuk proses konfigurasi Windows selesai."
echo "================================================================"

sleep 10
reboot
