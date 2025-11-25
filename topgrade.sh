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
# Ensure dependencies are installed
run_as_root apt install -y curl lsb-release wget
run_as_root curl -sL https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get | run_as_root -E bash -s install deb-get

# Redefine info() and error() *after* deb-get is installed
info() {
  echo "INFO: $1"
}
error() {
  echo "ERROR: $1"
  exit 1
}

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
topgrade --yes --cleanup
exit 0
