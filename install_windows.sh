#!/bin/bash
echo "SCRIPT AUTO INSTALL WINDOWS SERVER 2016 DATACENTER"
echo

# Prompt for Administrator password
echo "[*] Password yang saya buat sudah masuk wordlist bruteforce, silahkan masukkan password yang lebih aman!"
read -p "[?] Masukkan password untuk akun Administrator RDP anda(minimal 12 karakter) : " PASSADMIN

# Get IP and Gateway information
IP4=$(curl -4 -s icanhazip.com)
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
echo "Downloading Windows Server 2016 Datacenter ISO..."
wget --no-check-certificate -O windows_server_2016.iso "$ISO_URL"

# Create a temporary mount point
mkdir -p /mnt/windows_iso
mount -o loop windows_server_2016.iso /mnt/windows_iso

# Copy Windows installation files to target drive
echo "Copying Windows installation files..."
dd if=/mnt/windows_iso/sources/install.wim of=/dev/vda bs=3M status=progress

# Mount the Windows partition
mount.ntfs-3g /dev/vda2 /mnt

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

echo "Installation complete! Please reboot your system to start Windows Server 2016."
echo "RDP will be available at $IP4:5000 after the system initialization."
