#!/bin/bash

# Set system timezone to New York
echo "Setting timezone to America/New_York..."
sudo timedatectl set-timezone America/New_York
echo "Current system time:"
timedatectl

# Clone dotfiles repository and run install script as user
echo "Cloning dotfiles repository..."
git clone https://github.com/flipsidecreations/dotfiles.git
cd dotfiles || exit
echo "Running dotfiles installation script as user..."
./install.sh

# Change default shell to zsh as user
echo "Changing default shell to zsh (user)..."
chsh -s /bin/zsh
cd ~

# Run required setup steps as root in a subshell
sudo bash -c '
# Clone dotfiles repository and run install script as root
echo "Cloning dotfiles repository (root)..."
git clone https://github.com/flipsidecreations/dotfiles.git
cd dotfiles || exit
echo "Running dotfiles installation script as root..."
./install.sh

# Change default shell to zsh for root
echo "Changing default shell to zsh (root)..."
chsh -s /bin/zsh
cd ~

# Prompt user to insert VM Tools ISO and wait
echo "Please insert the XCP-NG Tools ISO and press [Enter] when ready..."
read -r

echo "Mounting CD-ROM..."
mount /dev/cdrom /mnt

if [[ ! -d "/mnt/Linux" ]]; then
    echo "Error: XCP-NG Tools ISO not found or not mounted correctly. Please check the ISO and try again."
    exit 1
fi

# Run XCP-NG Tools installation
echo "Running XCP-NG Tools installation..."
bash /mnt/Linux/install.sh && umount /mnt
'

# Download and install topgrade
echo "Downloading and installing topgrade..."
wget https://github.com/topgrade-rs/topgrade/releases/download/v16.0.4/topgrade_16.0.4-1_amd64.deb
sudo apt install ./topgrade_16.0.4-1_amd64.deb

# Run topgrade
echo "Running topgrade..."
topgrade

# Install Docker after topgrade and before reboot
echo "Installing Docker..."

sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

sudo groupadd docker
sudo usermod -aG docker $USER
echo "User added to 'docker' group. Changes take effect after you log out and log back in, or after a reboot."

# Reboot system
echo "Rebooting system..."
sudo reboot
