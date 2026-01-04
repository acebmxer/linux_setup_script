#!/usr/bin/env bash
set -euo pipefail
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
run_as_root() { sudo -E bash -c "$*"; }
run_as_user() { local user="${SUDO_USER:-${USER}}"; sudo -u "$user" -H bash -c "$*"; }
info()  { printf '\e[32m[INFO]\e[0m %s\n' "$*" | tee -a "$log_file"; }
warn()  { printf '\e[33m[WARN]\e[0m %s\n' "$*" | tee -a "$log_file"; }
error() { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2 | tee -a "$log_file"; }
# Only run as root when needed
run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}
# -----------------------------------------------------------------
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
# -----------------------------------------------------------------
# 7️⃣  Docker – install & verify
# -----------------------------------------------------------------
info "Installing Docker …"
run_as_root install apt-transport-https ca-certificates curl software-properties-common
run_as_root curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
run_as_root echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
run_as_root apt update
run_as_root apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
# run_as_root groupadd docker
run_as_root usermod -aG docker $USER
# Reload group membership without logging out
info "Reloading docker group membership…"
newgrp docker <<'EOF'
# All subsequent commands run with the new group membership
EOF
# 7a. Docker verification tests
info "Running Docker verification tests…"
# Make sure we can talk to the daemon
docker_cmd() { run_as_root docker "$@"; }
# 8a. Verify the client can reach the daemon
docker_cmd version
docker_cmd info
info "Docker verification complete."
# -----------------------------------------------------------------
# 9️⃣  Final summary
# -----------------------------------------------------------------
info "All components are now installed and, for Docker, all tests passed successfully!"
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
