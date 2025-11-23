#!/usr/bin/env bash
# =============================================================================
#  ──────  BOOTSTRAP SCRIPT  ──────
#  Installs:
#   • zsh (for the current user + root)
#   • dotfiles (once)
#   • XCP‑NG Tools (conflict‑free)
#   • Topgrade (download + install)
#   • Docker
#   • (Optional) Reboot
# =============================================================================

set -euo pipefail

# --------------------------------------------------------------------------- #
# Helper functions
# --------------------------------------------------------------------------- #

log()   { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
info()  { printf '    \e[32m%s\e[0m\n' "$*"; }
warn()  { printf '    \e[33m%s\e[0m\n' "$*"; }
error() { printf '    \e[31m%s\e[0m\n' "$*"; }

# Run a command with root privileges; if we are already root it just runs.
run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# --------------------------------------------------------------------------- #
# 1️⃣  Timezone
# --------------------------------------------------------------------------- #
info "Setting timezone to America/New_York …"
run_as_root ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
run_as_root dpkg-reconfigure -f noninteractive tzdata

# --------------------------------------------------------------------------- #
# 2️⃣  Basic packages
# --------------------------------------------------------------------------- #
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

# --------------------------------------------------------------------------- #
# 3️⃣  Dotfiles – install once
# --------------------------------------------------------------------------- #
DOTFILES_DIR="$HOME/dotfiles"
if [[ ! -d "$DOTFILES_DIR" ]]; then
    info "Cloning dotfiles repository …"
    run_as_root git clone --depth 1 https://github.com/flipsidecreations/dotfiles.git "$DOTFILES_DIR"
    run_as_root chown -R "$USER":"$USER" "$DOTFILES_DIR"
else
    info "Dotfiles already present – skipping clone"
fi

info "Running dotfiles installer (once) …"
run_as_root bash "$DOTFILES_DIR/install.sh" --once

# --------------------------------------------------------------------------- #
# 4️⃣  Shell – zsh for user and root
# --------------------------------------------------------------------------- #
info "Setting shell to zsh for the current user …"
chsh -s "$(command -v zsh)" "$USER"

info "Setting shell to zsh for root …"
run_as_root usermod -s "$(command -v zsh)" root

# ---------- --------------------------------------------------- #
# 5️⃣  XCP‑NG Tools – conflict‑free install
# ---------- --------------------------------------------------- #
info "Installing XCP‑NG Tools …"

# ------------------------------------------------------------------
# Helper: Mount the ISO if it isn’t already mounted
# ------------------------------------------------------------------
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

# ------------------------------------------------------------------
# Helper: Verify that the installer script exists on the mounted ISO
# ------------------------------------------------------------------
ensure_installer() {
    if [[ ! -f /mnt/Linux/install.sh ]]; then
        error "Installer script /mnt/Linux/install.sh not found."
        error "Make sure the ISO is correctly mounted and contains the installer."
        exit 1
    fi
}

# ------------------------------------------------------------------
# Remove any existing xen‑guest‑agent that might conflict
# ------------------------------------------------------------------
remove_conflicting_packages() {
    info "Removing any conflicting xen‑guest‑agent package…"
    run_as_root apt-get remove -y xen-guest-agent || warn "Failed to remove xen-guest-agent (may not be installed)."
}

# ------------------------------------------------------------------
# Execute the installation flow
# ------------------------------------------------------------------
mount_iso            # Mount the ISO if required
ensure_installer     # Verify the installer is present
remove_conflicting_packages  # ← **New step** before running the ISO installer

# Run the ISO’s install script
run_as_root bash /mnt/Linux/install.sh

# Unmount the ISO
run_as_root umount /mnt || warn "Failed to unmount /mnt – you may need to unmount it manually."

info "XCP‑NG Tools installation completed."

# --------------------------------------------------------------------------- #
# 6️⃣  Topgrade – download & install
# --------------------------------------------------------------------------- #
TOPGRADE_VERSION="v16.0.4"
TOPGRADE_DEB="topgrade_${TOPGRADE_VERSION}-1_amd64.deb"
TOPGRADE_URL="https://github.com/topgrade-rs/topgrade/releases/download/${TOPGRADE_VERSION}/${TOPGRADE_DEB}"
TOPGRADE_DEST="$home/${TOPGRADE_DEB}"

download_topgrade() {
    info "Downloading Topgrade ($TOPGRADE_DEB) …"
    if [[ -f "$TOPGRADE_DEST" ]]; then
        warn "Topgrade .deb already present – skipping download"
    else
        run_as_root wget -q --show-progress -O "$TOPGRADE_DEST" "$TOPGRADE_URL" || error "Failed to download Topgrade" && exit 1
        info "Topgrade downloaded to $TOPGRADE_DEST"
    fi
}

install_topgrade() {
    local deb="$1"
    info "Installing Topgrade from $deb …"
    run_as_root apt-get update
    run_as_root apt-get install -y "./$deb"
    run_as_root apt-mark auto topgrade
    info "Topgrade installed and auto‑marked for upgrades"
}

download_topgrade
install_topgrade "$TOPGRADE_DEST"

# --------------------------------------------------------------------------- #
# 7️⃣  Docker – install & enable
# --------------------------------------------------------------------------- #
info "Installing Docker …"
run_as_root apt-get install -y \
    docker.io \
    docker-compose

run_as_root usermod -aG docker "$USER"
run_as_root systemctl enable docker

# --------------------------------------------------------------------------- #
# 8️⃣  Summary
# --------------------------------------------------------------------------- #
info "─────────────────────────────────────────────────────────────────────"
info "Bootstrap finished successfully."
info " • Timezone        : America/New_York"
info " • Dotfiles        : $DOTFILES_DIR"
info " • Shell           : zsh (current user & root)"
info " • XCP‑NG Tools    : installed"
info " • Topgrade        : installed (auto‑marked)"
info " • Docker          : installed & enabled for current user"
info "─────────────────────────────────────────────────────────────────────"

# --------------------------------------------------------------------------- #
# 9️⃣  Optional reboot
# --------------------------------------------------------------------------- #
# Uncomment the following lines if you want an automatic reboot after
# all installations finish.  Commented out by default so you can inspect
# the system before rebooting.

# warn "Rebooting in 5 seconds…"
# sleep 5
# run_as_root reboot

# EOF
