#!/bin/bash
# Exit script if any command fails
set -e

# User and password variables
USER="one"
PASSWORD="1234"

# Update system and install required packages
sudo apt update -y
sudo apt upgrade -y

# Install XFCE, XServer, and other essential tools
sudo DEBIAN_FRONTEND=noninteractive apt install -y xfce4 xfce4-goodies xorg dbus-x11 xrdp git zsh curl

# Install additional Xorg packages
sudo apt install -y xorgxrdp

# Set up a new user with the provided password
sudo adduser --disabled-password --gecos "" $USER
echo "$USER:$PASSWORD" | sudo chpasswd
sudo usermod -aG sudo $USER

# Allow 'one' user to use sudo without password
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER

# Configure XRDP
sudo cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak
sudo sed -i 's/^port=3389/port=3390/' /etc/xrdp/xrdp.ini
sudo sed -i 's/^max_bpp=32/#max_bpp=32\nmax_bpp=128/' /etc/xrdp/xrdp.ini
sudo sed -i 's/^xserverbpp=24/#xserverbpp=24\nxserverbpp=128/' /etc/xrdp/xrdp.ini

# Configure Xwrapper to allow any user to start the X server
echo "allowed_users=anybody" | sudo tee /etc/X11/Xwrapper.config

# Set up XFCE desktop session for XRDP
echo "startxfce4" | sudo tee /etc/skel/.xsession
sudo cp /etc/skel/.xsession /home/$USER/
sudo chown $USER:$USER /home/$USER/.xsession

# Configure PolicyKit for XRDP
echo "[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes" | sudo tee /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla

# Enable XRDP service and restart it
sudo systemctl enable xrdp
sudo systemctl restart xrdp
sudo systemctl restart xrdp-sesman

# Allow XRDP in the firewall using firewalld
sudo apt install -y firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld
sudo firewall-cmd --permanent --add-port=3390/tcp
sudo firewall-cmd --reload

# Install Vivaldi browser (latest ARM64 version)
curl -O https://downloads.vivaldi.com/stable/vivaldi-stable_6.4.3160.34-1_arm64.deb
sudo apt install -y ./vivaldi-stable_6.4.3160.34-1_arm64.deb

# Change default shell to Zsh for the new user and root
sudo chsh -s /bin/zsh $USER
sudo chsh -s /bin/zsh root

# Install Oh My Zsh for root
sudo ZSH="/root/.oh-my-zsh" RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
sudo cp /root/.oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc

# Install Oh My Zsh for the new user and configure .zshrc
sudo -u $USER sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
sudo -u $USER sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' /home/$USER/.zshrc
echo '
# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt incappendhistory' | sudo -u $USER tee -a /home/$USER/.zshrc

# Clean up Vivaldi installation file
sudo rm vivaldi-stable_6.4.3160.34-1_arm64.deb
sudo apt autoremove -y

# Verify the xrdp-sesman service is running
sudo systemctl status xrdp-sesman

# Output success message
echo "Installation complete! User $USER created with password $PASSWORD. XRDP is available on port 3390."
echo "Zsh is set as the default shell for root and $USER, and Oh My Zsh is installed with proper configuration."
echo "User $USER can use sudo without being prompted for a password."
echo "Please check the status of xrdp-sesman above to ensure it's running correctly."
