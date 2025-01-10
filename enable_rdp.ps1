# Mengaktifkan Remote Desktop
Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0

# Membuka port 3389 di firewall Windows
New-NetFirewallRule -Name "Allow RDP" -DisplayName "Allow RDP" -Enabled True -Protocol TCP -LocalPort 3389

