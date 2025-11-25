#!/usr/bin/env bash
set -euo pipefail
# ────────────────────────────────────────────────────────
# 1️⃣ Helpers – keep the same colour‑coded log functions
# ────────────────────────────────────────────────────────
run_as_root() { sudo -E "$@"; }
info()        { printf '\e[32m[INFO]\e[0m %s\n' "$*"; }
warn()        { printf '\e[33m[WARN]\e[0m %s\n' "$*"; }
error()       { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; }
# ────────────────────────────────────────────────────────
# 2️⃣ Idempotency helper
# ────────────────────────────────────────────────────────
needs_update() {
local flag_file="$1"
[[ ! -f "$flag_file" ]] && return 0 || return 1
}
# Function to handle package checks, prompts, and uninstallation
handle_package() {
  local package_name="$1"
  local version_query="dpkg-query -W -f='${Version}' $package_name"
  local prompt="Would you like to uninstall existing $package_name (v$ver) and install new one? [y/N] "
  if dpkg -s "$package_name" > /dev/null 2>&1; then
    # Capture the version number and assign it to 'ver'
    ver=$($version_query)
    info "$package_name is installed, version $ver."
    read -r -p "$prompt" ans
    case "$ans" in
      y|Y|yes|Yes)
        info "Uninstalling existing $package_name..."
        run_as_root apt-get purge -y "$package_name" || warn "Failed to remove $package_name."
        ;;
      *)
        info "Keeping existing $package_name; skipping installation."
        return 1  # Signal: do not install
        ;;
    esac
  else
    info "$package_name is not installed."
  fi
  return 0  # Signal: install
}
# ────────────────────────────────────────────────────────
# 3️⃣ Timezone – only set if not already America/New_York
# ────────────────────────────────────────────────────────
TARGET_TZ="/usr/share/zoneinfo/America/New_York"
LOCALTIME="/etc/localtime"
if [[ "$(readlink -f "$LOCALTIME")" != "$TARGET_TZ" ]]; then
  info "Setting timezone to America/New_York …"
  run_as_root ln -fs "$TARGET_TZ" "$LOCALTIME"
  run_as_root dpkg-reconfigure -f noninteractive tzdata
else
  info "Timezone already set to America/New_York – skipping."
fi
# ────────────────────────────────────────────────────────
# 4️⃣ Ensure deb-get is installed
# ────────────────────────────────────────────────────────
ensure_deb_get_installed() {
  if ! command -v deb-get >/dev/null 2>&1; then
    info "deb-get not found – installing prerequisites."
    run_as_root apt-get update
    run_as_root apt-get install -y curl lsb-release wget
    info "Installing deb-get."
    local install_result=$(curl -sL https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get | sudo -E bash -s install deb-get)
    if [ $? -ne 0 ]; then
      error "Failed to install deb-get."
      exit 1
    fi
  else
    info "deb-get is already installed."
  fi
}
ensure_deb_get_installed
# ────────────────────────────────────────────────────────
# 5️⃣ Dotfiles – install for the regular user
# ────────────────────────────────────────────────────────
DOTFILES_USER_DIR="$HOME/.dotfiles"
DOTFILES_USER_FLAG="$DOTFILES_USER_DIR/.dotfiles_installed"
if [ ! -d "$DOTFILES_USER_DIR" ]; then
  mkdir -p "$DOTFILES_USER_DIR"
fi
if [ ! -f "$DOTFILES_USER_FLAG" ]; then
  info "Installing user dotfiles..."
  # Replace with your actual dotfiles installation logic
  # For example:
  # git clone <your_dotfiles_repo> "$DOTFILES_USER_DIR"
  # Create a flag file
  touch "$DOTFILES_USER_FLAG"
else
  info "User dotfiles already installed."
fi
# ────────────────────────────────────────────────────────
# 6️⃣ Dotfiles – install for the root user
# ────────────────────────────────────────────────────────
DOTFILES_ROOT_DIR="/root/.dotfiles"
DOTFILES_ROOT_FLAG="$DOTFILES_ROOT_DIR/.dotfiles_installed"
if [ ! -d "$DOTFILES_ROOT_DIR" ]; then
  run_as_root mkdir -p "$DOTFILES_ROOT_DIR"
fi
if [ ! -f "$DOTFILES_ROOT_FLAG" ]; then
  info "Installing root dotfiles..."
  # Replace with your actual dotfiles installation logic
  # For example:
  # git clone <your_dotfiles_repo> "$DOTFILES_ROOT_DIR"
  # Create a flag file
  run_as_root touch "$DOTFILES_ROOT_FLAG"
else
  info "Root dotfiles already installed."
fi
# ────────────────────────────────────────────────────────
# 7️⃣ System Upgrade (apt-get & topgrade)
# ────────────────────────────────────────────────────────
info "Running apt-get update and upgrade..."
run_as_root apt-get update
run_as_root apt-get upgrade -y
# ────────────────────────────────────────────────────────
# 8️⃣ XCP-NG Tools Installation
# ────────────────────────────────────────────────────────
# Handle package checks and prompts
handle_package "xe-guest-utilities"
handle_package "xen-guest-agent"
# Function to handle package checks, prompts, and uninstallation
# Centralized the prompt logic here
# ────────────────────────────────────────────────────────
# 9️⃣ Check for conflicting packages and remove them
# ────────────────────────────────────────────────────────
# IMPORTANT: Replace with your actual conflicting package removal logic.
# This is CRITICAL for XCP-NG Tools installation to work correctly.
# Example:
# run_as_root apt-get purge -y <conflicting_package1> <conflicting_package2>
# ────────────────────────────────────────────────────────
# 10️⃣ Mount the ISO if it isn’t already mounted
# ────────────────────────────────────────────────────────
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
# ────────────────────────────────────────────────────────
# 11️⃣ Make sure the installer script is present
# ────────────────────────────────────────────────────────
ensure_installer() {
  if [[ ! -f /mnt/Linux/install.sh ]]; then
    error "Installer script /mnt/Linux/install.sh not found."
    error "Make sure the ISO is correctly mounted and contains the installer."
    exit 1
  fi
}
# ────────────────────────────────────────────────────────
# 12️⃣ Run the installation
# ────────────────────────────────────────────────────────
mount_iso
ensure_installer
# remove_conflicting_packages  <--- UNCOMMENT THIS LINE AND IMPLEMENT IT
info "Running the XCP‑NG installer script..."
run_as_root bash /mnt/Linux/install.sh
# Unmount the ISO (best effort)
run_as_root umount /mnt || warn "Failed to unmount /mnt – you may need to unmount it manually."
# Wait a bit so the system settles
info "Pausing for 10 seconds to let services start..."
sleep 10
info "XCP‑NG Tools installation completed."
# ────────────────────────────────────────────────────────
# 13️⃣ Ask the user if they want to reboot
# ────────────────────────────────────────────────────────
read -r -p "All done! Do you want to reboot now? (y/N) " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  run_as_root reboot
else
  info "You can reboot later whenever you’re ready."
fi
