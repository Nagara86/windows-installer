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
    if [[ "$VERSION" != "18.04" && "$VERSION" != "20.04" ]]; then
        echo -e "${RED}This script is only compatible with Ubuntu 18.04 or 20.04${NC}"
        echo -e "${YELLOW}Current version: Ubuntu $VERSION${NC}"
        exit 1
    fi
    echo -e "${GREEN}Ubuntu version $VERSION detected - Compatible${NC}"
}

# Function to check system requirements
check_system_requirements() {
    # Check RAM
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ $total_ram -lt 4000 ]; then
        echo -e "${RED}Insufficient RAM. Minimum 4GB required. Current: ${total_ram}MB${NC}"
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
    if [ $free_space -lt 40 ]; then
        echo -e "${RED}Insufficient disk space. Minimum 40GB required. Current: ${free_space}GB${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}System requirements check passed${NC}"
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

# Main installation script
echo "SCRIPT AUTO INSTALL WINDOWS SERVER 2016 DATACENTER"
echo "------------------------------------------------"

# Run preliminary checks
check_root
check_ubuntu_version
check_system_requirements
install_required_packages

# Prompt for Administrator password
echo -e "\n${YELLOW}[*] Password yang saya buat sudah masuk wordlist bruteforce, silahkan masukkan password yang lebih aman!${NC}"
read -p "[?] Masukkan password untuk akun Administrator RDP anda(minimal 12 karakter) : " PASSADMIN

# Validate password length
if [ ${#PASSADMIN} -lt 12 ]; then
    echo -e "${RED}Password terlalu pendek. Minimal 12 karakter.${NC}"
    exit 1
fi

# Get IP and Gateway information
IP4=$(curl -4 -s icanhazip.com)
if [ -z "$IP4" ]; then
    echo -e "${RED}Tidak dapat mendapatkan IP address. Periksa koneksi internet anda.${NC}"
    exit 1
fi
GW=$(ip route | awk '/default/ { print $3 }')

# Create network configuration batch script
cat >/tmp/net.bat<<EOF
@ECHO OFF
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (del /f /q "%windir%\GetAdmin") else (
echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs"
"%temp%\Admin.vbs"
del /f /q "%temp%\Admin.vbs"
exit /b 2)
net user Administrator $PASSADMIN
for /f "tokens=3*" %%i in ('netsh interface show interface ^|findstr /I /R "Local.* Ethernet Ins*"') do (set InterfaceName=%%j)
netsh -c interface ip set address name="Ethernet Instance 0" source=static address=$IP4 mask=255.255.240.0 gateway=$GW
netsh -c interface ip add dnsservers name="Ethernet Instance 0" address=8.8.8.8 index=1 validate=no
netsh -c interface ip add dnsservers name="Ethernet Instance 0" address=8.8.4.4 index=2 validate=no
cd /d "%ProgramData%/Microsoft/Windows/Start Menu/Programs/Startup"
del /f /q net.bat
exit
EOF

# Create disk partitioning and RDP configuration batch script
cat >/tmp/dpart.bat<<EOF
@ECHO OFF
echo Windows Server 2016 Installation
echo JENDELA INI JANGAN DITUTUP
echo SCRIPT INI AKAN MERUBAH PORT RDP MENJADI 5000, UNTUK MENYAMBUNG KE RDP GUNAKAN ALAMAT $IP4:5000
echo KETIK YES LALU ENTER!
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (del /f /q "%windir%\GetAdmin") else (
echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs"
"%temp%\Admin.vbs"
del /f /q "%temp%\Admin.vbs"
exit /b 2)
set PORT=5000
set RULE_NAME="Open Port %PORT%"
netsh advfirewall firewall show rule name=%RULE_NAME% >nul
if not ERRORLEVEL 1 (
    rem Rule %RULE_NAME% already exists.
    echo Rule already exists!
) else (
    echo Rule %RULE_NAME% does not exist. Creating...
    netsh advfirewall firewall add rule name=%RULE_NAME% dir=in action=allow protocol=TCP localport=%PORT%
)
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber /t REG_DWORD /d 5000
ECHO SELECT VOLUME=%%SystemDrive%% > "%SystemDrive%\diskpart.extend"
ECHO EXTEND >> "%SystemDrive%\diskpart.extend"
START /WAIT DISKPART /S "%SystemDrive%\diskpart.extend"
del /f /q "%SystemDrive%\diskpart.extend"
cd /d "%ProgramData%/Microsoft/Windows/Start Menu/Programs/Startup"
del /f /q dpart.bat
timeout 50 >nul
del /f /q ChromeSetup.exe
echo JENDELA INI JANGAN DITUTUP
exit
EOF

# Download and mount Windows ISO
ISO_URL="https://software-static.download.prss.microsoft.com/pr/download/Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.ISO"
echo -e "${YELLOW}Downloading Windows Server 2016 Datacenter ISO...${NC}"
wget --no-check-certificate -O windows_server_2016.iso "$ISO_URL" || {
    echo -e "${RED}Failed to download Windows ISO${NC}"
    exit 1
}

# Create a temporary mount point
mkdir -p /mnt/windows_iso
mount -o loop windows_server_2016.iso /mnt/windows_iso || {
    echo -e "${RED}Failed to mount ISO${NC}"
    rm windows_server_2016.iso
    exit 1
}

# Copy Windows installation files to target drive
echo -e "${YELLOW}Copying Windows installation files...${NC}"
dd if=/mnt/windows_iso/sources/install.wim of=/dev/vda bs=3M status=progress || {
    echo -e "${RED}Failed to copy Windows files${NC}"
    umount /mnt/windows_iso
    rm windows_server_2016.iso
    exit 1
}

# Mount the Windows partition
mount.ntfs-3g /dev/vda2 /mnt || {
    echo -e "${RED}Failed to mount Windows partition${NC}"
    exit 1
}

# Copy startup scripts
cd "/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/"
cd Start* || cd start*
wget https://nixpoin.com/ChromeSetup.exe
cp -f /tmp/net.bat net.bat
cp -f /tmp/dpart.bat dpart.bat

# Cleanup
umount /mnt/windows_iso
rm -f windows_server_2016.iso
rmdir /mnt/windows_iso

echo -e "${GREEN}Installation complete! Please reboot your system to start Windows Server 2016.${NC}"
echo -e "${YELLOW}RDP will be available at $IP4:5000 after the system initialization.${NC}"
