# enable_rdp.ps1

# Pertanyaan untuk konfirmasi instalasi
$response = Read-Host "Apakah Anda ingin menginstal Windows? (yes/no)"
if ($response -eq "yes") {
    Write-Output "Memulai konfigurasi RDP dan setup..."

    # Meminta pengguna untuk mengkonfirmasi password untuk RDP
    $password = Read-Host "Masukkan password untuk RDP" -AsSecureString

    # Mengonversi password dari SecureString menjadi String (diperlukan untuk set ke akun)
    $PasswordPlainText = [System.Net.NetworkCredential]::new("", $password).Password

    # Menyiapkan akun Administrator atau membuat akun baru dan mengatur password
    $admin = [ADSI]"WinNT://./Administrator,user"
    $admin.setPassword($PasswordPlainText)

    # Enable Remote Desktop
    $rdpKey = "HKLM:\System\CurrentControlSet\Control\Terminal Server"
    Set-ItemProperty -Path $rdpKey -Name "fDenyTSConnections" -Value 0

    # Allow RDP through Windows Firewall
    New-NetFirewallRule -DisplayName "Allow RDP" -Enabled True -Protocol TCP -LocalPort 3389 -Action Allow

    Write-Output "RDP diaktifkan dan password telah disetting."
} else {
    Write-Output "Instalasi dibatalkan."
    Exit
}

