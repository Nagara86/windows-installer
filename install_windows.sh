#!/bin/bash

# Menanyakan kepada user apakah ingin menginstall Windows
echo "Apakah Anda ingin menginstall Windows 2022? (y/n)"
read INSTALL_WINDOWS

if [ "$INSTALL_WINDOWS" != "y" ]; then
    echo "Proses dibatalkan."
    exit 1
fi

# Meminta username RDP
echo "Masukkan username RDP yang ingin anda buat:"
read RDP_USER

# Meminta password RDP
echo "Masukkan password RDP untuk akses (minimal 8 karakter):"
read -s RDP_PASS

# Update dan Install KVM/QEMU
echo "Memperbarui sistem dan menginstal KVM/QEMU..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst wget

# Periksa apakah sistem mendukung Virtualisasi KVM
if [[ $(egrep -c '(vmx|svm)' /proc/cpuinfo) -eq 0 ]]; then
    echo "CPU Anda tidak mendukung KVM. Skrip dihentikan."
    exit 1
fi

# Memastikan Sistem Memiliki Swap Memory (Tambahkan jika belum ada)
if [[ ! -f /swapfile ]]; then
    echo "Swap file tidak ditemukan. Menambahkan swap..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    # Tambahkan ke fstab agar swap tetap aktif setelah reboot
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Verifikasi swap
echo "Verifikasi swap yang aktif:"
swapon --show

# Download ISO Windows Server 2022
ISO_URL="https://software-static.download.prss.microsoft.com/sg/download/888969d5-f34g-4e03-ac9d-1f9786c66749/SERVER_EVAL_x64FRE_en-us.iso"
ISO_PATH="/var/lib/libvirt/images/windows.iso"

echo "Mengunduh ISO Windows Server 2022..."
wget -O "$ISO_PATH" "$ISO_URL"

# Membuat disk virtual untuk Windows
echo "Membuat disk virtual untuk mesin Windows..."
qemu-img create -f qcow2 /var/lib/libvirt/images/windows.img 50G

# Menjalankan mesin virtual menggunakan KVM
echo "Memulai mesin virtual untuk menginstal Windows Server..."
virt-install \
  --name windows-server \
  --ram 4096 \
  --vcpu 2 \
  --disk path=/var/lib/libvirt/images/windows.img,format=qcow2 \
  --cdrom "$ISO_PATH" \
  --os-type windows \
  --network bridge=virbr0,model=virtio \
  --graphics none \
  --extra-args "file=/var/lib/libvirt/images/unattend.xml" \
  --noautoconsole

echo "Proses instalasi Windows dimulai..."

# Membuat file unattend.xml untuk otomatisasi Windows
echo "Membuat file unattend.xml untuk setup otomatis..."
cat << EOF > /var/lib/libvirt/images/unattend.xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup">
            <ImageInstall>
                <OSImage>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>1</PartitionID>
                    </InstallTo>
                </OSImage>
            </ImageInstall>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup">
            <ComputerName>Windows2022</ComputerName>
            <ProductKey></ProductKey>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Name>$RDP_USER</Name>
                        <Group>Administrators</Group>
                        <Password>
                            <Value>$RDP_PASS</Value>
                            <PlainText>true</PlainText>
                        </Password>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <TimeZone>UTC</TimeZone>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <NetworkLocation>Home</NetworkLocation>
            </OOBE>
        </component>
    </settings>
</unattend>
EOF

echo "File unattend.xml untuk otomatisasi setup sudah siap."

# Proses selesai, menunggu instalasi dan memberikan instruksi untuk login RDP
echo "Setelah instalasi selesai, Anda dapat mengakses Windows Server menggunakan aplikasi Remote Desktop (RDP)."
echo "Login dengan username: $RDP_USER dan password yang Anda tentukan."
