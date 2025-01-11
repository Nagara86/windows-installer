#!/bin/bash

# Windows Server Auto Install Script
echo "================================"
echo "Windows Server Auto Install Tool"
echo "================================"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check system requirements
MEMORY=$(free -m | awk '/^Mem:/{print $2}')
CPUS=$(nproc)
if [[ $MEMORY -lt 2048 || $CPUS -lt 2 ]]; then
    echo "Error: Insufficient system resources"
    echo "Required: Minimum 2GB RAM and 2 CPU cores"
    echo "Current: $MEMORY MB RAM, $CPUS CPU cores"
    exit 1
fi

# Define Windows ISO URL
ISO_URL="https://software-static.download.prss.microsoft.com/pr/download/Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.ISO"

# Get system information
IP4=$(curl -4 -s icanhazip.com)
if [[ -z "$IP4" ]]; then
    echo "Error: Could not detect public IP address"
    exit 1
fi

GW=$(ip route | awk '/default/ { print $3 }')
if [[ -z "$GW" ]]; then
    echo "Error: Could not detect default gateway"
    exit 1
fi

# Password prompt with validation
while true; do
    read -sp "Enter Administrator password (min 12 chars): " PASSADMIN
    echo
    if [[ ${#PASSADMIN} -lt 12 ]]; then
        echo "Password must be at least 12 characters long"
        continue
    fi
    read -sp "Confirm password: " PASSCONFIRM
    echo
    if [[ "$PASSADMIN" == "$PASSCONFIRM" ]]; then
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

# Create Windows network configuration script
cat >/tmp/net.bat<<EOF
@ECHO OFF
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (del /f /q "%windir%\GetAdmin") else (
echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs"
"%temp%\Admin.vbs"
del /f /q "%temp%\Admin.vbs"
exit /b 2)
net user Administrator ${PASSADMIN}
netsh -c interface ip set address name="Ethernet Instance 0" source=static address=${IP4} mask=255.255.240.0 gateway=${GW}
netsh -c interface ip add dnsservers name="Ethernet Instance 0" address=8.8.8.8 index=1 validate=no
netsh -c interface ip add dnsservers name="Ethernet Instance 0" address=8.8.4.4 index=2 validate=no
cd /d "%ProgramData%/Microsoft/Windows/Start Menu/Programs/Startup"
del /f /q net.bat
exit
EOF

# Create disk partition and RDP configuration script
cat >/tmp/dpart.bat<<EOF
@ECHO OFF
echo Windows Server Setup Configuration
echo ================================
echo DO NOT CLOSE THIS WINDOW
echo RDP will be configured on port 5000 (${IP4}:5000)
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (del /f /q "%windir%\GetAdmin") else (
echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs"
"%temp%\Admin.vbs"
del /f /q "%temp%\Admin.vbs"
exit /b 2)

rem Configure RDP Port
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber /t REG_DWORD /d 5000 /f

rem Add Firewall Rule
netsh advfirewall firewall add rule name="RDP on 5000" dir=in action=allow protocol=TCP localport=5000

rem Extend Disk
ECHO SELECT VOLUME=%%SystemDrive%% > "%SystemDrive%\diskpart.extend"
ECHO EXTEND >> "%SystemDrive%\diskpart.extend"
START /WAIT DISKPART /S "%SystemDrive%\diskpart.extend"
del /f /q "%SystemDrive%\diskpart.extend"

cd /d "%ProgramData%/Microsoft/Windows/Start Menu/Programs/Startup"
del /f /q dpart.bat
exit
EOF

# Install required tools
echo "Installing required packages..."
apt-get update >/dev/null 2>&1
apt-get install -y wget ntfs-3g gzip curl >/dev/null 2>&1

# Download and extract Windows ISO
echo "Downloading Windows Server 2016 ISO..."
wget --no-check-certificate -O windows.iso "$ISO_URL" || {
    echo "Error downloading Windows ISO"
    exit 1
}

echo "Writing ISO to disk..."
dd if=windows.iso of=/dev/vda bs=4M status=progress || {
    echo "Error writing ISO to disk"
    exit 1
}

# Mount and configure Windows
echo "Configuring Windows installation..."
mkdir -p /mnt
mount.ntfs-3g /dev/vda2 /mnt || {
    echo "Error mounting Windows partition"
    exit 1
}

# Copy configuration scripts
cp /tmp/net.bat "/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup/"
cp /tmp/dpart.bat "/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup/"

# Cleanup
rm -f /tmp/net.bat /tmp/dpart.bat
rm -f windows.iso

echo "================================================"
echo "Installation completed! Please reboot your system."
echo "RDP will be available at: ${IP4}:5000"
echo "Username: Administrator"
echo "Password: [your entered password]"
echo "================================================"
