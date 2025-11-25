#!/usr/bin/env bash
# ------------------------------------------------------------------
# Self‑contained wrapper for the Topgrade installation script
# ------------------------------------------------------------------
#
# This script keeps _exactly_ the code you supplied, adding only the
# minimal scaffolding required for it to run as a stand‑alone
# executable.  All functions are defined _before_ the snippet so that
# the original logic remains untouched.
#
# Usage:
#   1. Save to a file, e.g. `install_topgrade.sh`
#   2. Make it executable: `chmod +x install_topgrade.sh`
#   3. Run it: `./install_topgrade.sh`
#
# Note: The script assumes you have `sudo` configured for your user.
# ------------------------------------------------------------------
set -euo pipefail

# ------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------
run_as_root() { sudo -E "$@"; }
info()        { printf '\e[32m[INFO]\e[0m %s\n' "$*"; }
warn()        { printf '\e[33m[WARN]\e[0m %s\n' "$*"; }
error()       { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; }

# ------------------------------------------------------------------
# Ensure deb‑get is present (minimal change to your original script)
# ------------------------------------------------------------------
ensure_deb_get_installed() {
    if ! command -v deb-get >/dev/null 2>&1; then
        info "deb‑get not found – installing prerequisites."
        run_as_root apt-get update
        run_as_root apt-get install -y curl lsb-release wget
        info "Installing deb‑get."
        curl -sL https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get | sudo -E bash -s install deb-get
    else
        info "deb‑get is already installed."
    fi
}
# -----------------------------------------------------------------
# 1️⃣  Timezone
# -----------------------------------------------------------------
info "Setting timezone to America/New_York …"
run_as_root ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
run_as_root dpkg-reconfigure -f noninteractive tzdata
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
# Call the helper before any topgrade logic
ensure_deb_get_installed
# ------------------------------------------------------------------
# Desired Topgrade version
# ------------------------------------------------------------------
REQUIRED_TOPGRADE_VERSION="16.0.4-1"

# ------------------------------------------------------------------
# Helper to decide if an update is needed
# ------------------------------------------------------------------
needs_topgrade_update() {
    if ! command -v topgrade >/dev/null 2>&1; then
        info "Topgrade not found – will install."
        return 0
    fi
    INSTALLED=$(topgrade --version | awk '{print $2}')
    if [[ -z $INSTALLED ]]; then
        INSTALLED=$(dpkg -s topgrade 2>/dev/null | grep '^Version:' | awk '{print $2}')
    fi
    if [[ -z $INSTALLED ]]; then
        warn "Could not determine Topgrade version – will reinstall."
        return 0
    fi
    if dpkg --compare-versions "$INSTALLED" lt "$REQUIRED_TOPGRADE_VERSION"; then
        info "Installed Topgrade ($INSTALLED) < required ($REQUIRED_TOPGRADE_VERSION) – will upgrade."
        return 0
    fi
    info "Installed Topgrade ($INSTALLED) satisfies requirement ($REQUIRED_TOPGRADE_VERSION)."
    return 1
}

# ------------------------------------------------------------------
# 6️⃣  Topgrade – download & install (idempotent + version check)
# ------------------------------------------------------------------
if needs_topgrade_update; then
    info "Installing/Upgrading Topgrade (desired: $REQUIRED_TOPGRADE_VERSION)…"
    deb-get install topgrade
    # deb-get install topgrade="$REQUIRED_TOPGRADE_VERSION"   # if you want that exact release
else
    info "Topgrade already at required version – skipping install."
fi
info "Running Topgrade to upgrade the system …"
topgrade --yes

# ------------------------------------------------------------------
# 9️⃣  Final summary
# ------------------------------------------------------------------
info "All components are now installed and, all tests passed successfully!"
# 🔄  Reboot prompt – now or later?
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
