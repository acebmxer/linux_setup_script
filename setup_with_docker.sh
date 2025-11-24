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
# 3️⃣  Dotfiles – install once
# -----------------------------------------------------------------
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
# 4️⃣  Shell – zsh for user and root
# -----------------------------------------------------------------
info "Setting shell to zsh for the current user …"
chsh -s "$(command -v zsh)" "$USER"
info "Setting shell to zsh for root …"
run_as_root usermod -s "$(command -v zsh)" root
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
TOPGRADE_VERSION="v16.4.2"
TOPGRADE_DEB="topgrade_${TOPGRADE_VERSION}-1_amd64.deb"
TOPGRADE_URL="https://github.com/topgrade-rs/topgrade/releases/download/v16.4.2/topgrade_16.4.2-1_amd64.deb"
TOPGRADE_DEST="$HOME"
download_topgrade() {
    info "Downloading Topgrade ($TOPGRADE_VERSION) …"
    run_as_root wget -q --show-progress "$TOPGRADE_DEST" "$TOPGRADE_URL"
}
install_topgrade() {
    local deb="$1"
    info "Installing Topgrade from $deb …"
    run_as_root apt-get update
    run_as_root apt-get install -y "./$deb"
    run_as_root apt-mark auto topgrade
}
download_topgrade
install_topgrade "$TOPGRADE_DEST"

# -----------------------------------------------------------------
# 👉  **Run Topgrade immediately after installation**
# -----------------------------------------------------------------
info "Running Topgrade to upgrade the system …"
# `--yes` (or `-y`) skips the interactive confirmation
topgrade --yes
# -----------------------------------------------------------------
# 7️⃣  Docker – install & verify
# -----------------------------------------------------------------
info "Installing Docker …"
run_as_root apt-get install -y docker.io
run_as_root systemctl enable --now docker
# 7a. Docker verification tests
info "Running Docker verification tests…"
# Make sure we can talk to the daemon
docker_cmd() { run_as_root docker "$@"; }
# 8a. Verify the client can reach the daemon
docker_cmd version
docker_cmd info
# 8b. Pull & run the hello‑world image
HELLO_IMG="hello:latest"
info "Pulling ${HELLO_IMG} image …"
run_as_root docker pull "$HELLO_IMG"
info "Running ${HELLO_IMG} container to confirm the image works …"
run_as_root docker run --rm "$HELLO_IMG"
# 8c. Quick compose test
info "Running a quick docker‑compose test …"
COMPOSE_DIR="$(mktemp -d)"
cat > "${COMPOSE_DIR}/docker-compose.yml" <<'EOF'
version: "3.8"
services:
  hello:
    image: hello:latest
    container_name: hello_test
EOF
run_as_root docker compose -f "${COMPOSE_DIR}/docker-compose.yml" up -d
sleep 2
run_as_root docker compose -f "${COMPOSE_DIR}/docker-compose.yml" ps
run_as_root docker compose -f "${COMPOSE_DIR}/docker-compose.yml" down
rm -rf "${COMPOSE_DIR}"
info "Docker verification complete."
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
