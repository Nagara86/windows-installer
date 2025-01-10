#!/bin/bash

# Memperbarui sistem dan pasang KVM/QEMU
echo "Memperbarui sistem..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst wget

# Memeriksa apakah CPU mendukung KVM
if [[ $(egrep -c '(vmx|svm)' /proc/cpuinfo) -eq 0 ]]; then
    echo "CPU Anda tidak mendukung KVM! Skrip dihentikan."
    exit 1
fi

# Memeriksa apakah sudah ada swap, jika belum, buat swap 2GB
if [[ $(free | grep Swap | awk '{print $2}') -eq 0 ]]; then
    echo "Swap tidak ditemukan. Menambahkan swap 2GB..."
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    # Menambahkan swap ke /etc/fstab untuk memastikan aktif setelah reboot
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "Swap berhasil ditambahkan."
else
    echo "Swap sudah tersedia."
fi

# Meminta input untuk username dan password untuk Windows Server
read -p "Masukkan username untuk Windows Server (misalnya: Administrator): " WIN_USERNAME
read -sp "Masukkan password untuk user Windows (akan disembunyikan): " WIN_PASSWORD
echo # Untuk baris baru setelah input password

# Membuat disk virtual untuk Windows Server
echo "Membuat disk virtual..."
qemu-img create -f qcow2 /var/lib/libvirt/images/windows.img 50G

# Download ISO Windows Server
ISO_URL="https://software-static.download.prss.microsoft.com/sg/download/888969d5-f34g-4e03-ac9d-1f9786c66749/SERVER_EVAL_x64FRE_en-us.iso"
ISO_PATH="/var/lib/libvirt/images/windows.iso"

echo "Mengunduh ISO Windows dari URL..."
wget -O "$ISO_PATH" "$ISO_URL"

# Menjalankan mesin virtual
echo "Menjalankan installer Windows melalui VNC..."
virt-install \
  --name windows-server \
  --ram 2048 \
  --vcpu 2 \
  --disk path=/var/lib/libvirt/images/windows.img,format=qcow2 \
  --cdrom "$ISO_PATH" \
  --os-type windows \
  --network bridge=virbr0,model=virtio \
  --graphics vnc,listen=0.0.0.0,port=5900

echo "Selesai! Akses VNC ke IP-server:5900 untuk menyelesaikan instalasi Windows."

# Menambahkan langkah otomatisasi untuk enable RDP setelah instalasi selesai
echo "Mengonfigurasi RDP di Windows Server..."

# Skrip PowerShell untuk mengaktifkan RDP dan membuka port firewall
cat << EOF > enable_rdp.ps1
# Mengaktifkan Remote Desktop
Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0

# Membuka port 3389 di firewall Windows
New-NetFirewallRule -Name "Allow RDP" -DisplayName "Allow RDP" -Enabled True -Protocol TCP -LocalPort 3389
EOF

# Menambahkan skrip PowerShell untuk mengubah password RDP
cat << EOF > set_rdp_password.ps1
# Mengatur password untuk user Windows yang diberikan (gunakan password yang dipilih oleh user)
\$password = ConvertTo-SecureString -String "$WIN_PASSWORD" -AsPlainText -Force
Set-LocalUser -Name "$WIN_USERNAME" -Password \$password
EOF

# Menyalin skrip PowerShell ke Windows Server setelah instalasi
# Salin skrip RDP ke sistem Windows yang baru terinstal dan jalankan untuk mengaktifkan RDP serta mengatur password

echo "Skrip RDP dan password siap, sekarang Anda dapat mengeksekusi skrip PowerShell tersebut pada server Windows."

# Informasi login RDP
echo "Setelah instalasi selesai, Anda bisa mengakses Windows Server menggunakan aplikasi Remote Desktop (RDP) pada IP-server Anda, melalui port 3389."
echo "Gunakan username: $WIN_USERNAME dan password yang telah Anda tentukan selama setup ($WIN_PASSWORD)."
