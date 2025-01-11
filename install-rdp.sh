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
echo "Windows Server ISO telah berhasil diunduh dan disimpan di: /home/SERVER_EVAL_x64FRE_en-us.iso"
