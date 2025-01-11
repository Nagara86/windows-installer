#!/bin/bash

# Update sistem
apt update && apt upgrade -y

# Install dependensi yang diperlukan
apt install -y xfce4 xfce4-goodies tightvncserver xrdp wget curl unzip

# Download ISO file Windows Server 2022
echo "Downloading Windows Server 2022 ISO..."
wget -O /home/SERVER_EVAL_x64FRE_en-us.iso "https://software-static.download.prss.microsoft.com/sg/download/888969d5-f34g-4e03-ac9d-1f9786c66749/SERVER_EVAL_x64FRE_en-us.iso"

# Menunjukkan hasil download untuk memastikan ISO ada
ls -lh /home/SERVER_EVAL_x64FRE_en-us.iso

# Install RDP konfigurasi
# Hapus instalasi default xrdp
apt-get remove --purge xrdp -y

# Install xrdp terbaru
apt install -y xrdp

# Install beberapa dependensi RDP
apt-get install -y xorgxrdp

# Install sesinya dengan XFCE
echo "startxfce4" >~/.xsession

# Perbaiki pengaturan port xrdp menjadi 3389
sed -i 's/port=1/port=3389/' /etc/xrdp/xrdp.ini

# Pastikan xrdp bisa berjalan
systemctl enable xrdp
systemctl start xrdp

# Mengatasi potensi masalah port yang sudah digunakan (3389)
# Cek apakah port 3389 sudah digunakan
if sudo ss -tuln | grep ':3389'; then
    echo "Port 3389 sudah digunakan, mencari proses yang menggunakan port tersebut..."
    pid=$(sudo lsof -t -i:3389)
    if [ ! -z "$pid" ]; then
        echo "Menghentikan proses dengan PID: $pid"
        sudo kill -9 $pid
    fi
else
    echo "Port 3389 tidak digunakan, melanjutkan..."
fi

# Membuat user bella dan mengatur password
# Memastikan grup admin sudah ada
groupadd -f admin
useradd -m -g admin bella
echo "bella:bella123" | chpasswd

# Setel ulang konfigurasi xrdp untuk port 3389 (default RDP)
systemctl restart xrdp

# Konfigurasi firewall agar port 3389 terbuka
ufw allow 3389/tcp

# Output
echo "RDP siap dengan username: bella dan password: bella123"
echo "Windows Server ISO telah berhasil diunduh dan disimpan di: /home/SERVER_EVAL_x64FRE_en-us.iso"
