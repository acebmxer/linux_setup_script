#!/usr/bin/env bash
# ==========================================================
# install_xen_tools.sh   (extracted from flipsidebootstrap)
# ==========================================================
#
# 5️⃣  XCP‑NG Tools – conflict‑free install
#
# This script is fully self‑contained: it re‑defines the helper
# functions `log`, `info`, `warn`, `error`, `run_as_root`) that
# the original file used and then runs the Xen‑Tools installer.
#
# -------------------------------------...

# Helper functions (copied from your main script – do **not** modify)
log()   { echo "[LOG]   $*"; }
info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; }
# Only run as root when needed
run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# ------------------------------------------------------------------
# NEW: Check / uninstall / keep `xe-guest-tools`
# ------------------------------------------------------------------
check_and_handle_xe_guest_tools() {
    # If the package is present, show its version
    if dpkg -s xe-guest-tools > /dev/null 2>&1; then
        ver=$(dpkg-query -W -f='${Version}' xe-guest-tools)
        info "xe-guest-tools is installed, version $ver."
        read -rp "Would you like to uninstall existing xe-guest-tools (v$ver) and install new one? [y/N] " ans
        case "$ans" in
            y|Y|yes|Yes)
                info "Uninstalling existing xe-guest-tools..."
                run_as_root apt-get remove -y xe-guest-tools || warn "Failed to remove xe-guest-tools."
                ;;
            *)
                info "Keeping existing xe-guest-tools; skipping installation."
                return 1    # Signal: do not install
                ;;
        esac
    else
        info "xe-guest-tools is not installed."
    fi
    return 0        # Signal: install
}

# ------------------------------------------------------------------
# 5️⃣  XCP‑NG Tools – conflict‑free install
# ------------------------------------------------------------------
info "Installing XCP‑NG Tools …"

# ------------------------------------------------------------------
# 1️⃣  Check / uninstall / keep xe‑guest‑tools
# ------------------------------------------------------------------
if ! check_and_handle_xe_guest_tools; then
    info "Installation aborted – leaving existing xe-guest-tools intact."
    exit 0
fi

# ------------------------------------------------------------------
# 2️⃣  Mount the ISO if it isn’t already mounted
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
# 3️⃣  Make sure the installer script is present
# ------------------------------------------------------------------
ensure_installer() {
    if [[ ! -f /mnt/Linux/install.sh ]]; then
        error "Installer script /mnt/Linux/install.sh not found."
        error "Make sure the ISO is correctly mounted and contains the installer."
        exit 1
    fi
}
# ------------------------------------------------------------------
# 4️⃣  Remove any conflicting xen‑guest‑agent package
# ------------------------------------------------------------------
remove_conflicting_packages() {
    info "Removing any conflicting xen‑guest‑agent package…"
    run_as_root apt-get remove -y xen-guest-agent || warn "Failed to remove xen-guest-agent (may not be installed)."
}

# ------------------------------------------------------------------
# 5️⃣  Run the installation
# ------------------------------------------------------------------
mount_iso
ensure_installer
remove_conflicting_packages
info "Running the XCP‑NG installer script..."
run_as_root bash /mnt/Linux/install.sh
# Unmount the ISO (best effort)
run_as_root umount /mnt || warn "Failed to unmount /mnt – you may need to unmount it manually."
# Wait a bit so the system settles
info "Pausing for 10 seconds to let services start..."
sleep 10
info "XCP‑NG Tools installation completed."
