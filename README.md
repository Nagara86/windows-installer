# windows-installer
Windows Auto-Installer for KVM/QEMU
This project allows you to automatically install Windows Server on a virtual machine using KVM/QEMU. It includes an installer script and configuration files to automate the installation process and enable Remote Desktop (RDP) access after the installation is complete.

Table of Contents
Requirements
Installation
Usage
Files Included
License
Requirements
A server running Ubuntu (or another Linux distro with similar packages) with KVM/QEMU support enabled.
At least 2 vCPUs and 4GB of RAM (virtualization support required).
Internet connection to download the Windows Server ISO.
Windows Server ISO for evaluation or license installation.
Installation
Step 1: Clone the Repository
bash
Copy code
git clone https://github.com/YOUR_USERNAME/windows-installer.git
cd windows-installer
Step 2: Install KVM/QEMU and Required Packages
Run the following commands to install KVM and related tools required for virtualization:

bash
Copy code
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst
Step 3: Make the Script Executable
Ensure that the install_windows.sh script is executable:

bash
Copy code
chmod +x install_windows.sh
Step 4: Run the Installation Script
Execute the script to start the installation process for Windows Server:

bash
Copy code
./install_windows.sh
Script Interaction:
The script will first ask you whether you'd like to continue with the Windows installation (answer with y or n).
If you choose yes, you'll then be prompted to enter an RDP password that will be set for the Administrator user.
Usage
After the Installation:
After the Windows installation is complete, use VNC to access the installation process, which will be available on your server's IP on port 5900.
Once the Windows installation is finished, the script will enable RDP and open the required 3389 port in the Windows firewall for remote access.
Connecting via Remote Desktop (RDP):
On a Windows machine, you can use the built-in Remote Desktop Client (mstsc).

On a Mac or other OS, use the Microsoft Remote Desktop app.

You can connect using the server's IP address and use the Administrator account with the password you provided during installation.

Files Included
install_windows.sh: Main installation script for installing Windows Server on a virtual machine.
enable_rdp.ps1: PowerShell script that enables Remote Desktop and sets the RDP password on the Windows Server after installation.
unattend.xml: Configuration file to automate parts of the Windows Server installation and run the necessary commands during the first login.
License
This project is licensed under the MIT License - see the LICENSE file for details.
