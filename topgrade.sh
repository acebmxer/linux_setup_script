#!/bin/bash
# This script is fully self‑contained: it re‑defines the helper
# functions `log`, `info`, `warn`, `error`, `run_as_root`) that
# the original file used and then runs the Xen‑Tools installer.
#
# ---------------------------------------------------------------
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
# ────────────────────────────────────────────────────────
# 8️⃣ System upgrade – Topgrade (idempotent)
# ────────────────────────────────────────────────────────
info "Updating tograde"
# Update package lists, then ensure topgrade is updated
run_as_root deb-get update
# Run as the user; Topgrade will auto‑install missing packages
topgrade
info "Running topgrade cleanup …"
topgrade -c
# -----------------------------------------------------------------
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
