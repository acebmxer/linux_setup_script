#!/usr/bin/env bash
# ===================================================================
#   flipsidebootstrap (merged & upgraded)
#   ----------------------------------------------------------------
#   Timezone  ➜ America/New_York
#   Dotfiles  ➜ $HOME/dotfiles
#   Shell     ➜ zsh (user & root)
#   XCP‑NG    ➜ installed
#   Topgrade  ➜ installed
#   Docker    ➜ installed & verified
# ===================================================================
# 0️⃣  Helper functions
# -----------------------------------------------------------------
log()  { echo "[LOG]   $*"; }
info() { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*" >&2; }
error(){ echo "[ERROR] $*" >&2; }
# Only run as root when needed
run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}
# 1️⃣  Timezone
# -----------------------------------------------------------------
info "Setting timezone to America/New_York …"
run_as_root ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
run_as_root dpkg-reconfigure -f noninteractive tzdata
# 2️⃣  Basic packages
# -----------------------------------------------------------------
info "Updating APT cache …"
run_as_root apt-get update -y
info "Installing required packages …"
run_as_root apt-get install -y \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg2 \
    lsb-release \
    sudo
# -----------------------------------------------------------------
# 3️⃣  Dotfiles – install once
# -----------------------------------------------------------------
info "Starting as regular user"
git clone https://github.com/flipsidecreations/dotfiles.git
cd dotfiles
./install.sh
chsh -s /bin/zsh
# -----------------------------------------------------------------
#    Dotfiles - Install for root
# -----------------------------------------------------------------
sudo -s <<EOF
info "Now running as root"
git clone https://github.com/flipsidecreations/dotfiles.git
cd dotfiles
./install.sh
chsh -s /bin/zsh
EOF
infosudo "Back to regular user."
# -----------------------------------------------------------------
# 5️⃣  XCP‑NG Tools – conflict‑free install
# -----------------------------------------------------------------
info "Installing XCP‑NG Tools …"
mount_iso() {
    if mountpoint -q /mnt; then
        info "ISO already mounted at /mnt."
    else
        warn "ISO not mounted. Please insert the XCP‑NG ISO and press Enter to continue…"
        read -r
        run_as_root mount /dev/cdrom /mnt || { error "Failed to mount /dev/cdrom"; exit 1; }
        if ! mountpoint -q /mnt; then
            error "Mounting /dev/cdrom failed."
            exit 1
        fi
        info "ISO mounted successfully."
    fi
}
ensure_installer() {
    if [[ ! -f /mnt/Linux/install.sh ]]; then
        error "Installer script /mnt/Linux/install.sh not found."
        error "Make sure the ISO is correctly mounted and contains the installer."
        exit 1
    fi
}
remove_conflicting_packages() {
    info "Removing any conflicting xen‑guest‑agent package…"
    run_as_root apt-get remove -y xen-guest-agent || warn "Failed to remove xen-guest-agent (may not be installed)."
}
mount_iso
ensure_installer
remove_conflicting_packages
run_as_root bash /mnt/Linux/install.sh
run_as_root umount /mnt || warn "Failed to unmount /mnt – you may need to unmount it manually."
info "XCP‑NG Tools installation completed."
# -----------------------------------------------------------------
# 6️⃣  Topgrade – download & install
# -----------------------------------------------------------------
run_as_root apt install curl lsb-release wget
curl -sL https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get | sudo -E bash -s install deb-get
deb-get install topgrade 
# -----------------------------------------------------------------
# 👉  **Run Topgrade immediately after installation**
# -----------------------------------------------------------------
info "Running Topgrade to upgrade the system …"
# `--yes` (or `-y`) skips the interactive confirmation
topgrade --yes
# -----------------------------------------------------------------
# 9️⃣  Final summary
# -----------------------------------------------------------------
info "All components are now installed and, for Docker, all tests passed successfully!"
#  🔄  Reboot prompt – now or later?
# -----------------------------------------------------------------
echo
info "The installation is finished. A reboot is recommended to apply all changes."
read -rp "Reboot now? (y/N) " REBOOT_CHOICE
REBOOT_CHOICE=${REBOOT_CHOICE:-N}
case "$REBOOT_CHOICE" in
  y|Y|yes|YES)
    info "Rebooting…"
    run_as_root reboot
    ;;
  n|N|no|NO)
    warn "Remember to reboot the server later to complete the setup."
    ;;
  *)
    error "Unexpected input – exiting without reboot."
    ;;
esac
# If we reach this point, the script has already rebooted (or not).
# No further action is required.
exit 0
