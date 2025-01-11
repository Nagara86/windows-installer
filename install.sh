#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Check system requirements
echo "Checking system requirements..."

# Check available disk space
available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ $available_space -lt 40 ]; then
    echo -e "${RED}Not enough disk space. Need at least 40GB free.${NC}"
    exit 1
fi

# Check RAM
total_ram=$(free -m | awk '/^Mem:/{print $2}')
if [ $total_ram -lt 2048 ]; then
    echo -e "${RED}Not enough RAM. Need at least 2GB RAM.${NC}"
    exit 1
fi

# Install required packages
echo "Installing required packages..."
apt-get update
apt-get install -y wget gzip curl ntfs-3g

echo "==================================="
echo "Windows Server Installation Script"
echo "==================================="

# Windows Server 2019 Standard Evaluation ISO URL
WIN_ISO="https://go.microsoft.com/fwlink/p/?LinkID=2195167"

# Get password for Administrator account
while true; do
    read -sp "Enter Administrator password (min 12 characters): " PASSADMIN
    echo
    if [ ${#PASSADMIN} -ge 12 ]; then
        break
    else
        echo -e "${RED}Password must be at least 12 characters long${NC}"
    fi
done

# Get IP and Gateway
IP4=$(curl -4 -s icanhazip.com)
GW=$(ip route | awk '/default/ { print $3 }')

# Create network configuration script
cat >/tmp/net.bat<<EOF
@ECHO OFF
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (del /f /q "%windir%\GetAdmin") else (
echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs"
"%temp%\Admin.vbs"
del /f /q "%temp%\Admin.vbs"
exit /b 2)
net user Administrator ${PASSADMIN}
for /f "tokens=3*" %%i in ('netsh interface show interface ^|findstr /I /R "Local.* Ethernet Ins*"') do (set InterfaceName=%%j)
netsh -c interface ip set address name="Ethernet Instance 0" source=static address=${IP4} mask=255.255.240.0 gateway=${GW}
netsh -c interface ip add dnsservers name="Ethernet Instance 0" address=8.8.8.8 index=1 validate=no
netsh -c interface ip add dnsservers name="Ethernet Instance 0" address=8.8.4.4 index=2 validate=no
cd /d "%ProgramData%/Microsoft/Windows/Start Menu/Programs/Startup"
del /f /q net.bat
exit
EOF

# Create disk partition script
cat >/tmp/dpart.bat<<EOF
@ECHO OFF
echo Windows Server Setup
echo DO NOT CLOSE THIS WINDOW
echo RDP will be configured on port 5000. Connect using ${IP4}:5000
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
    echo Rule already exists
) else (
    netsh advfirewall firewall add rule name=%RULE_NAME% dir=in action=allow protocol=TCP localport=%PORT%
)
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber /t REG_DWORD /d 5000
ECHO SELECT VOLUME=%%SystemDrive%% > "%SystemDrive%\diskpart.extend"
ECHO EXTEND >> "%SystemDrive%\diskpart.extend"
START /WAIT DISKPART /S "%SystemDrive%\diskpart.extend"
del /f /q "%SystemDrive%\diskpart.extend"
cd /d "%ProgramData%/Microsoft/Windows/Start Menu/Programs/Startup"
del /f /q dpart.bat
exit
EOF

echo "Downloading and installing Windows..."
wget --no-check-certificate -O windows.iso "$WIN_ISO" || {
    echo -e "${RED}Failed to download Windows ISO${NC}"
    exit 1
}

# Convert and write ISO to disk
echo "Writing ISO to disk..."
dd if=windows.iso of=/dev/vda bs=4M status=progress || {
    echo -e "${RED}Failed to write ISO to disk${NC}"
    rm windows.iso
    exit 1
}

rm windows.iso

# Mount Windows partition
echo "Configuring Windows installation..."
mkdir -p /mnt
mount.ntfs-3g /dev/vda2 /mnt || {
    echo -e "${RED}Failed to mount Windows partition${NC}"
    exit 1
}

# Copy configuration scripts
mkdir -p "/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup"
cp -f /tmp/net.bat "/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup/" || {
    echo -e "${RED}Failed to copy net.bat${NC}"
    exit 1
}
cp -f /tmp/dpart.bat "/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup/" || {
    echo -e "${RED}Failed to copy dpart.bat${NC}"
    exit 1
}

echo -e "${GREEN}Installation completed!${NC}"
echo "System will now reboot. Please wait 5-10 minutes before connecting via RDP."
echo "RDP Connection details:"
echo "IP: ${IP4}"
echo "Port: 5000"
echo "Username: Administrator"
echo "Password: [your configured password]"

# Cleanup and reboot
rm -f /tmp/net.bat /tmp/dpart.bat
umount /mnt
echo "Rebooting in 10 seconds..."
sleep 10
reboot
