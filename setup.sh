#!/bin/bash

# Ensure the script is running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Update and upgrade packages
apt update && apt upgrade -y

# Install Uncomplicated Firewall (UFW)
apt install ufw -y

# Allow incoming traffic on tailscale0 interface
ufw allow in on tailscale0

# Set default policy to drop all incoming connections
ufw default deny incoming

# Prompt for a custom SSH port
read -p "Enter a custom SSH port: " custom_ssh_port
if [[ $custom_ssh_port =~ ^[0-9]+$ ]] && [ $custom_ssh_port -le 65535 ] && [ $custom_ssh_port -gt 0 ]; then
    # Change SSH port
    sed -i "/^#Port 22/a Port $custom_ssh_port" /etc/ssh/sshd_config
    ufw allow $custom_ssh_port/tcp
    echo "SSH port changed to $custom_ssh_port."
else
    echo "Invalid port. Aborting."
    exit 1
fi

# Prompt for disabling root password login
read -p "Would you like to disable root password login? (yes/no): " disable_root_login
case $disable_root_login in
    [Yy]* )
        sed -i "/^#PermitRootLogin prohibit-password/c\PermitRootLogin no" /etc/ssh/sshd_config
        echo "Root password login disabled."
        ;;
    [Nn]* )
        echo "Root password login not modified."
        ;;
    * )
        echo "Invalid response. Please answer yes or no. Aborting."
        exit 1
        ;;
esac

# Continue with the rest of the script...

# Create the new user 'mastervash' if it doesn't already exist
if id "mastervash" &>/dev/null; then
    echo "User mastervash already exists."
else
    adduser --disabled-password --gecos "" mastervash
    echo "User mastervash created."
fi

# Import the public SSH key from GitHub for the user 'mastervash'
mkdir -p /home/mastervash/.ssh
curl https://github.com/mastervash.keys -o /home/mastervash/.ssh/authorized_keys
chown -R mastervash:mastervash /home/mastervash/.ssh
chmod 700 /home/mastervash/.ssh
chmod 600 /home/mastervash/.ssh/authorized_keys

# Add 'mastervash' to the sudo group
usermod -aG sudo mastervash

# Configure sudoers file to allow 'mastervash' to execute sudo commands without a password
echo "mastervash ALL=(ALL) NOPASSWD: ALL" | EDITOR="tee -a" visudo

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Enable and start the Tailscale service
systemctl enable tailscale
systemctl start tailscale

# Run Tailscale up with specific options
tailscale up --accept-dns=false

echo "Setup completed."
