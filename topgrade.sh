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
curl -sL https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get | \
sudo -E bash -s install deb-get
else
info "deb-get is already installed."
fi
}
ensure_deb_get_installed
# ────────────────────────────────────────────────────────
# 5️⃣ Dotfiles – install for the regular user
# ────────────────────────────────────────────────────────
info "Starting as regular user"
git clone https://github.com/flipsidecreations/dotfiles.git
cd dotfiles
./install.sh
chsh -s /bin/zsh
cd ..
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
info "Back to regular user."
# ────────────────────────────────────────────────────────
# 7️⃣ System pre‑upgrade (optional but handy)
# ────────────────────────────────────────────────────────
info "Running a quick apt‑update before topgrade."
run_as_root apt-get update
# ────────────────────────────────────────────────────────
# 8️⃣ System upgrade – Topgrade (idempotent)
# ────────────────────────────────────────────────────────
info "Installing topgrade"
deb-get install topgrade
if error; then
info "Updating topgrade to the newest deb-get‑supplied version …"
deb-get upgrade topgrade
else
info "Topgrade has been installed or has been updated."
fi
info "Running topgrade …"
# Run as the user; Topgrade will auto‑install missing packages
topgrade -y
# ────────────────────────────────────────────────────────
# 9️⃣ xen‑guest‑utilities – install / upgrade (root)
# ────────────────────────────────────────────────────────
# --------------------------------------------------------------
# NEW: Check / uninstall / keep `xe-guest-utilities`
# --------------------------------------------------------------
check_and_handle_xe_guest_tools() {
    # If the package is present, show its version
    if dpkg -s xe-guest-utilities > /dev/null 2>&1; then
        ver=$(dpkg-query -W -f='${Version}' xe-guest-utilities)
        info "xe-guest-utilities is installed, version $ver."
        read -rp "Would you like to uninstall existing xe-guest-utilities (v$ver) and install new one? [y/N] " ans
        case "$ans" in
            y|Y|yes|Yes)
                info "Uninstalling existing xe-guest-utilities..."
                run_as_root apt-get purge -y xe-guest-utilities || warn "Failed to remove xe-guest-utilities."
                ;;
            *)
                info "Keeping existing xe-guest-utilities; skipping installation."
                return 1    # Signal: do not install
                ;;
        esac
    else
        info "xe-guest-utilities is not installed."
    fi
    return 0        # Signal: install
}
# --------------------------------------------------------------
# NEW: Check / uninstall / keep `xen-guest-agent`
# --------------------------------------------------------------
check_and_handle_xen_guest_agent() {
    if dpkg -s xen-guest-agent > /dev/null 2>&1; then
        ver=$(dpkg-query -W -f='${Version}' xen-guest-agent)
        info "xen-guest-agent is installed, version $ver."
        read -rp "Would you like to uninstall existing xen-guest-agent (v$ver) and install new one? [y/N] " ans
        case "$ans" in
            y|Y|yes|Yes)
                info "Uninstalling existing xen-guest-agent..."
                run_as_root apt-get purge -y xen-guest-agent || warn "Failed to remove xen-guest-agent."
                ;;
            *)
                info "Keeping existing xen-guest-agent; skipping installation."
                return 1    # Signal: do not install
                ;;
        esac
    else
        info "xen-guest-agent is not installed."
    fi
    return 0        # Signal: install
}
# --------------------------------------------------------------
# 5️⃣  XCP‑NG Tools – conflict‑free install
# --------------------------------------------------------------
info "Installing XCP‑NG Tools …"
# --------------------------------------------------------------
# 1️⃣  Check / uninstall / keep xe‑guest‑tools
# --------------------------------------------------------------
if ! check_and_handle_xe_guest_tools; then
    info "Installation aborted – leaving existing xe-guest-utilities intact."
    exit 0
fi
# --------------------------------------------------------------
# 1.5️⃣ Check / uninstall / keep xen‑guest‑agent
# --------------------------------------------------------------
if ! check_and_handle_xen_guest_agent; then
    info "Installation aborted – leaving existing xen-guest-agent intact."
    exit 0
fi
# --------------------------------------------------------------
# 2️⃣  Mount the ISO if it isn’t already mounted
# --------------------------------------------------------------
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
# --------------------------------------------------------------
# 3️⃣  Make sure the installer script is present
# --------------------------------------------------------------
ensure_installer() {
    if [[ ! -f /mnt/Linux/install.sh ]]; then
        error "Installer script /mnt/Linux/install.sh not found."
        error "Make sure the ISO is correctly mounted and contains the installer."
        exit 1
    fi
}
# --------------------------------------------------------------
# 5️⃣  Run the installation
# --------------------------------------------------------------
mount_iso
ensure_installer
info "Running the XCP‑NG installer script..."
run_as_root bash /mnt/Linux/install.sh
# Unmount the ISO (best effort)
run_as_root umount /mnt || warn "Failed to unmount /mnt – you may need to unmount it manually."
# Wait a bit so the system settles
info "Pausing for 10 seconds to let services start..."
sleep 10
info "XCP‑NG Tools installation completed."
# ────────────────────────────────────────────────────────
# 10️⃣ Ask the user if they want to reboot
# ────────────────────────────────────────────────────────
read -r -p "All done! Do you want to reboot now? (y/N) " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
run_as_root reboot
else
info "You can reboot later whenever you’re ready."
fi
