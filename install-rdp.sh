#!/bin/bash

# Ubuntu RDP Auto Installer
# For Ubuntu 24.10 with Windows Server RDP

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Custom RDP Port
RDP_PORT=9999

# Function to print status
print_status() {
    echo -e "${GREEN}[*] $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}[!] $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit
fi

# Update system
print_status "Updating system..."
apt-get update && apt-get upgrade -y

# Install required packages
print_status "Installing required packages..."
apt-get install -y \
    xrdp \
    xfce4 \
    xfce4-goodies \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager

# Configure XRDP with custom port
print_status "Configuring XRDP with custom port ${RDP_PORT}..."
sed -i "s/port=3389/port=${RDP_PORT}/g" /etc/xrdp/xrdp.ini
systemctl enable xrdp
systemctl restart xrdp

# Create new user function
create_rdp_user() {
    local username=$1
    local password=$2
    
    print_status "Creating new user: $username"
    useradd -m -s /bin/bash "$username"
    echo "$username:$password" | chpasswd
    usermod -aG sudo "$username"
    
    # Configure XFCE4 for the new user
    echo "xfce4-session" > /home/$username/.xsession
    chown $username:$username /home/$username/.xsession
}

# Function to setup KVM
setup_kvm() {
    print_status "Setting up KVM..."
    
    # Check KVM support
    if [ $(egrep -c '(vmx|svm)' /proc/cpuinfo) -eq 0 ]; then
        print_error "Your CPU doesn't support hardware virtualization"
        exit 1
    fi
    
    # Add user to required groups
    usermod -aG libvirt $SUDO_USER
    usermod -aG kvm $SUDO_USER
}

# Function to create Windows VM
create_windows_vm() {
    local iso_url=$1
    local vm_name="WindowsRDP"
    
    print_status "Downloading Windows ISO..."
    wget -O /tmp/windows.iso "$iso_url"
    
    print_status "Creating Windows VM..."
    virt-install \
        --name=$vm_name \
        --ram=2048 \
        --vcpus=2 \
        --disk size=50 \
        --os-type=windows \
        --os-variant=win2k19 \
        --network bridge=virbr0 \
        --graphics spice \
        --cdrom=/tmp/windows.iso
}

# Function to configure firewall
configure_firewall() {
    print_status "Configuring firewall..."
    # Remove old RDP rule if exists
    ufw delete allow 3389/tcp 2>/dev/null
    # Add new RDP port rule
    ufw allow ${RDP_PORT}/tcp
    ufw enable
}

# Main execution
main() {
    print_status "Starting RDP Auto Installation..."
    
    # Get username and password
    read -p "Enter username for RDP: " rdp_username
    read -s -p "Enter password for RDP: " rdp_password
    echo ""
    
    # Create RDP user
    create_rdp_user "$rdp_username" "$rdp_password"
    
    # Setup KVM
    setup_kvm
    
    # Create Windows VM
    create_windows_vm "https://software-static.download.prss.microsoft.com/sg/download/888969d5-f34g-4e03-ac9d-1f9786c66749/SERVER_EVAL_x64FRE_en-us.iso"
    
    # Configure firewall with new port
    configure_firewall
    
    print_status "Installation completed!"
    echo "RDP Server Information:"
    echo "------------------------"
    echo "IP Address: $(hostname -I | cut -d' ' -f1)"
    echo "Port: ${RDP_PORT}"
    echo "Username: $rdp_username"
    echo "------------------------"
    
    # Restart XRDP to apply all changes
    systemctl restart xrdp
}

# Run main function
main
