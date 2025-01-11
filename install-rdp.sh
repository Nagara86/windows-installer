#!/bin/bash

# Update sistem
apt update && apt upgrade -y

# Install dependensi yang diperlukan
apt install -y xfce4 xfce4-goodies tightvncserver xrdp wget curl

# Install file Windows jika diperlukan (optional, hanya jika ingin mengunduh Windows file dari link)
wget "https://download1322.mediafire.com/q45q3lnfq46gmouZIGTp712CYsj2ZuIMho3b7Z-7A2TIBmrDCLiePiRXdKLeYvaXkwaIRHaN3UaEiDMbE3npFuMTAxRoP6Iu0tCKma3xJmWL_v1wcLngELHu78oqJ-OJGwSl87JkZzjUKxOLnxYR6mBUMo6-0jfbb2xg8zKnlj8SJA/s92phcj6bgp0yhg/Windows2022.gz"
# Proses unzip jika ada
gzip -d Windows2022.gz

# Install RDP konfigurasi
# Hapus instalasi default xrdp
apt-get remove --purge xrdp

# Unduh dan install xrdp terbaru dari repositori
apt install -y xrdp

# Install beberapa dependensi RDP
apt-get install -y xorgxrdp

# Install sesinya dengan XFCE
echo "startxfce4" >~/.xsession

# Atur agar xrdp bisa berjalan
systemctl enable xrdp
systemctl start xrdp

# Buat user admin dan set password default
useradd -m admin
echo "admin:admin123" | chpasswd

# Setel ulang konfigurasi xrdp untuk port 3389 (default RDP)
sed -i 's/port=3389/port=ask-1/' /etc/xrdp/xrdp.ini

# Restart xrdp untuk aplikasi perubahan
systemctl restart xrdp

# Konfigurasi firewall agar port 3389 terbuka
ufw allow 3389/tcp

# Output
echo "RDP siap dengan username: admin dan password: admin123"
