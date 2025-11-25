#!/usr/bin/env bash
# ------------------------------------------------------------------
# Self‑contained wrapper for the Topgrade installation script
# ------------------------------------------------------------------
#
# This script keeps *exactly* the code you supplied, adding only the
# minimal scaffolding required for it to run as a stand‑alone
# executable.  All functions are defined *before* the snippet so that
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
run_as_root() {
    # Execute the given command with elevated privileges.
    # The '-E' flag preserves the environment (useful for
    # passing variables like DEBIAN_FRONTEND to apt).
    sudo -E "$@"
}

info() {
    # Simple info printer – can be extended with colors if desired.
    printf '\e[32m[INFO]\e[0m %s\n' "$*"
}

warn() {
    printf '\e[33m[WARN]\e[0m %s\n' "$*"
}

error() {
    printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2
}

# ------------------------------------------------------------------
# ---------------------------------------------------------------------------------
# 6️⃣  Topgrade – download & install
# -------------------------------------------------------------------------------------------------
run_as_root apt install curl lsb-release wget
curl -sL https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get | sudo -E bash -s install deb-get
deb-get install topgrade
# -------------------------------------------------------------------------------------------------
# 👉  **Run Topgrade immediately after installation**
# -------------------------------------------------------------------------------------------------
info "Running Topgrade to upgrade the system …"
# `--yes` (or `-y`) skips the interactive confirmation
topgrade --yes
# -------------------------------------------------------------------------------------------------
# 9️⃣  Final summary
# -------------------------------------------------------------------------------------------------
info "All components are now installed and, all tests passed successfully!"
#  🔄  Reboot prompt – now or later?
# -------------------------------------------------------------------------------------------------
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
