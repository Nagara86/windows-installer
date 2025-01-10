#!/bin/bash

# Menanyakan apakah pengguna ingin menginstal Windows
read -p "Apakah Anda ingin menginstal Windows? (y/n): " jawab

if [[ "$jawab" != "y" && "$jawab" != "Y" ]]; then
  echo "Proses instalasi dibatalkan."
  exit 0
fi

# Meminta password RDP
read -sp "Masukkan password RDP: " rdp_password
echo  # Untuk newline setelah input

# Update dan pasang KVM/QEMU
echo "Memperbarui sistem..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst

# Pastikan CPU mendukung KVM
if [[ $(egrep -c '(vmx|svm)' /proc/cpuinfo) -eq 0 ]]; then
    echo "CPU Anda tidak mendukung KVM! Skrip dihentikan."
    exit 1
fi

# Membuat disk virtual untuk Windows
echo "Membuat disk virtual..."
qemu-img create -f qcow2 /var/lib/libvirt/images/windows.img 50G

# Download ISO Windows
ISO_URL="https://software-static.download.prss.microsoft.com/sg/download/888969d5-f34g-4e03-ac9d-1f9786c66749/SERVER_EVAL_x64FRE_en-us.iso"
ISO_PATH="/var/lib/libvirt/images/windows.iso"

echo "Mengunduh ISO Windows dari URL..."
wget -O "$ISO_PATH" "$ISO_URL"

# Menjalankan mesin virtual
echo "Menjalankan installer Windows melalui VNC..."
virt-install \
  --name windows-server \
  --ram 4096 \
  --vcpu 2 \
  --disk path=/var/lib/libvirt/images/windows.img,format=qcow2 \
  --cdrom "$ISO_PATH" \
  --os-type windows \
  --network bridge=virbr0,model=virtio \
  --graphics vnc,listen=0.0.0.0,port=5900

echo "Proses selesai! Akses VNC ke IP-server:5900 untuk menyelesaikan instalasi Windows."

# Menambahkan langkah otomatisasi untuk enable RDP setelah instalasi selesai

echo "Mengonfigurasi RDP di Windows Server..."

# Skrip PowerShell untuk mengaktifkan RDP dan membuka port firewall
cat << EOF > enable_rdp.ps1
# Mengaktifkan Remote Desktop
Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0

# Membuka port 3389 di firewall Windows
New-NetFirewallRule -Name "Allow RDP" -DisplayName "Allow RDP" -Enabled True -Protocol TCP -LocalPort 3389

# Mengatur password RDP
\$SecurePassword = ConvertTo-SecureString "$rdp_password" -AsPlainText -Force
Set-LocalUser -Name "Administrator" -Password \$SecurePassword
EOF

# Salin skrip PowerShell ke Windows Server setelah instalasi
# Anggap bahwa skrip PowerShell ini akan dieksekusi di Windows setelah instalasi
echo "Skrip RDP siap, sekarang Anda dapat mengeksekusi skrip PowerShell tersebut pada server Windows."

# Informasi login RDP
echo "Setelah instalasi selesai, Anda bisa mengakses Windows Server menggunakan aplikasi Remote Desktop (RDP) pada IP-server Anda, melalui port 3389."
echo "Gunakan akun Administrator dengan password yang Anda tentukan."
