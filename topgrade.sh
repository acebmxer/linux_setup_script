#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------------------------
# 1️⃣  helpers – keep the same color‑coded log functions
# --------------------------------------------------------------------
run_as_root() { sudo -E "$@"; }
info()        { printf '\e[32m[INFO]\e[0m %s\n' "$*"; }
warn()        { printf '\e[33m[WARN]\e[0m %s\n' "$*"; }
error()       { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; }

# --------------------------------------------------------------------
# 2️⃣  Helper to make the script fully idempotent
# --------------------------------------------------------------------
#   (returns 0 if the action is needed, 1 if nothing to do)
needs_update() {
    local flag_file="$1"
    if [ ! -f "$flag_file" ]; then
        return 0                      # flag missing → we need to do it
    fi
    # flag exists → already done
    return 1
}

# --------------------------------------------------------------------
# 3️⃣  1️⃣  Timezone – only set if not already America/New_York
# --------------------------------------------------------------------
TARGET_TZ="/usr/share/zoneinfo/America/New_York"
LOCALTIME="/etc/localtime"
if [[ "$(readlink -f "$LOCALTIME")" != "$TARGET_TZ" ]]; then
    info "Setting timezone to America/New_York …"
    run_as_root ln -fs "$TARGET_TZ" "$LOCALTIME"
    run_as_root dpkg-reconfigure -f noninteractive tzdata
else
    info "Timezone already set to America/New_York – skipping."
fi

# --------------------------------------------------------------------
# 4️⃣  2️⃣  Ensure deb-get is installed
# --------------------------------------------------------------------
ensure_deb_get_installed() {
    if ! command -v deb-get >/dev/null 2>&1; then
        info "deb-get not found – installing prerequisites."
        run_as_root apt-get update
        run_as_root apt-get install -y curl lsb-release wget
        info "Installing deb-get."
        curl -sL https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get | sudo -E bash -s install deb-get
    else
        info "deb-get is already installed."
    fi
}
ensure_deb_get_installed

# --------------------------------------------------------------------
# 5️⃣  3️⃣  Dotfiles – install for the regular user
# --------------------------------------------------------------------
DOTFILES_DIR="$HOME/dotfiles"
DOTFILES_FLAG="$DOTFILES_DIR/.installed"

info "Installing dotfiles for regular user…"
if [ -d "$DOTFILES_DIR" ]; then
    info "dotfiles directory already exists – pulling latest changes."
    git -C "$DOTFILES_DIR" pull --rebase
else
    git clone https://github.com/flipsidecreations/dotfiles.git "$DOTFILES_DIR"
fi

# Run the install script only if we haven’t run it before
if needs_update "$DOTFILES_FLAG"; then
    (cd "$DOTFILES_DIR" && ./install.sh)
    touch "$DOTFILES_FLAG"
    chsh -s /bin/zsh
else
    info "Dotfiles already installed – skipping install.sh."
fi

# --------------------------------------------------------------------
# 6️⃣  4️⃣  Dotfiles – install for root (using the same logic)
# --------------------------------------------------------------------
sudo -s <<'EOF'
DOTFILES_DIR="/root/dotfiles"
DOTFILES_FLAG="/root/.dotfiles_installed"

info "Installing dotfiles for root…"
if [ -d "$DOTFILES_DIR" ]; then
    info "dotfiles directory already exists – pulling latest changes."
    git -C "$DOTFILES_DIR" pull --rebase
else
    git clone https://github.com/flipsidecreations/dotfiles.git "$DOTFILES_DIR"
fi

if [ ! -f "$DOTFILES_FLAG" ]; then
    (cd "$DOTFILES_DIR" && ./install.sh)
    touch "$DOTFILES_FLAG"
    chsh -s /bin/zsh
else
    info "Root dotfiles already installed – skipping install.sh."
fi
EOF

# --------------------------------------------------------------------
# 7️⃣  5️⃣  Ensure Topgrade is at the correct version
# --------------------------------------------------------------------
REQUIRED_TOPGRADE_VERSION="v1.3.2"   # change as you wish

needs_topgrade_update() {
    if ! command -v topgrade >/dev/null 2>&1; then
        return 0
    fi
    local current
    current=$(topgrade --version | awk '{print $2}')
    if [[ "$current" != "$REQUIRED_TOPGRADE_VERSION" ]]; then
        return 0
    fi
    return 1
}

if needs_topgrade_update; then
    info "Installing/upgrading Topgrade to $REQUIRED_TOPGRADE_VERSION …"
    deb‑get install topgrade="$REQUIRED_TOPGRADE_VERSION"  # deb‑get is idempotent
else
    info "Topgrade already at $REQUIRED_TOPGRADE_VERSION – skipping."
fi

# --------------------------------------------------------------------
# 8️⃣  5️⃣  Run Topgrade – it is idempotent on its own
# --------------------------------------------------------------------
info "Running Topgrade…"
topgrade

# --------------------------------------------------------------------
# 9️⃣  Optional: reboot prompt (you can keep it or drop it)
# --------------------------------------------------------------------
read -rp "Do you want to reboot now? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] && run_as_root reboot
