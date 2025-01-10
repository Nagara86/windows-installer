#!/bin/bash

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

echo "Selesai! Akses VNC ke IP-server:5900 untuk menyelesaikan instalasi Windows."
