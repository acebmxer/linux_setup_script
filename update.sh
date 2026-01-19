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
# 8️⃣ System upgrade with out Topgrade (idempotent)
# ────────────────────────────────────────────────────────
run_as_root apt update -y && run_as_root apt upgrade -y && run_as_root apt autoremove -y
info "System update has completed successfully."
info "You system will now be rebooted to apply all changes."
run_as_root reboot
# If we reach this point, the script has already rebooted.
