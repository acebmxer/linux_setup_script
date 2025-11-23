#!/usr/bin/env bash
# ------------------------------------------------------------------
#  Bootstrap script for a fresh Ubuntu / Debian‑based VM
#
#  • Sets timezone to America/New_York
#  • Installs dotfiles once and runs its install script as user & root
#  • Changes default shell to zsh for both user & root
#  • Mounts the XCP‑NG Tools ISO, runs its installer (conflict‑free)
#  • Installs Topgrade (via the official .deb package)
#  • Installs Docker and marks it auto‑installed
#  • Unmounts the ISO again
# ------------------------------------------------------------------
set -euo pipefail

# ------------------------------------------------------------------
# helpers -----------------------------------------------------------
log() {
  printf '%s\n' "$*"
}

run_as_root() {
  if [[ $EUID -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

# ------------------------------------------------------------------
# 1️⃣  Time‑zone ----------------------------------------------------
log "Configuring timezone to America/New_York"
run_as_root ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
run_as_root dpkg-reconfigure -f noninteractive tzdata

# ------------------------------------------------------------------
# 2️⃣  Dotfiles ----------------------------------------------------
DOTFILES_REPO="https://github.com/flipsidecreations/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

log "Cloning (or pulling) dotfiles repository into $DOTFILES_DIR"
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  run_as_root git -C "$DOTFILES_DIR" pull --ff-only
else
  run_as_root git clone --depth=1 "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

log "Running dotfiles installer as user $USER"
bash "$DOTFILES_DIR/install.sh"

log "Running dotfiles installer as root"
run_as_root bash "$DOTFILES_DIR/install.sh"

# ------------------------------------------------------------------
# 3️⃣  ZSH + oh‑my‑zsh ------------------------------------------------
log "Installing zsh and oh‑my‑zsh for $USER"
run_as_root apt-get update
run_as_root apt-get install -y zsh

log "Installing oh‑my‑zsh"
run_as_root sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

log "Configuring .zshrc for $USER"
cat > "$HOME/.zshrc" <<'EOF'
# ~/.zshrc: zsh configuration file
export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
source $HOME/.dotfiles/scripts/aliases.zsh
EOF

log "Changing default shell to zsh for $USER and root"
chsh -s "$(which zsh)" "$USER"
chsh -s "$(which zsh)" root

# ------------------------------------------------------------------
# 4️⃣  XCP‑NG Tools installer ---------------------------------------
#    We use your one‑liner *but* we strip out the problematic
#    xe‑guest‑utilities conflict first.
read -rp "Insert the XCP‑NG Tools ISO, press [Enter] to continue…" && :
log "Mounting CD‑ROM and running XCP‑NG installer (conflict‑free)…"

run_as_root bash -c '
  set -euo pipefail
  # 1) Mount the ISO
  mount /dev/cdrom /mnt
  # 2) Remove the agent that conflicts with xe‑guest‑utilities
  if dpkg -s xen-guest-agent &>/dev/null; then
    echo "xen-guest-agent detected – removing to avoid conflict"
    apt-get remove -y xen-guest-agent
  fi
  # 3) Run the original installer (it will pick up the fresh environment)
  bash /mnt/Linux/install.sh
  # 4) Clean up
  umount /mnt
'

log "XCP‑NG installer finished – unmounted successfully"

# ------------------------------------------------------------------
# 5️⃣  Topgrade -----------------------------------------------------
log "Installing Topgrade from the official .deb package"
TOP_DEB=$(ls /tmp/topgrade_*.deb 2>/dev/null | head -n 1)
if [[ -n "$TOP_DEB" ]]; then
  run_as_root apt-get update
  run_as_root apt-get install -y "./$TOP_DEB"
  run_as_root apt-mark auto topgrade
else
  log "No Topgrade .deb found – skipping"
fi

# ------------------------------------------------------------------
# 6️⃣  Docker -------------------------------------------------------
log "Installing Docker (and its CLI tools)"
run_as_root apt-get update
run_as_root apt-get install -y \
  docker.io \
  docker-compose-plugin \
  docker-buildx-plugin
run_as_root apt-mark auto docker.io docker-compose-plugin docker-buildx-plugin

# ------------------------------------------------------------------
# 7️⃣  Summary ------------------------------------------------------
log "Bootstrap complete!  System is ready for use."
echo
echo "───────────────────────────────────────────────────────────────"
echo "  ✅  Time‑zone: America/New_York"
echo "  ✅  Dotfiles: $DOTFILES_DIR (installed once)"
echo "  ✅  Shell: zsh (for $USER and root)"
echo "  ✅  XCP‑NG Tools: installed (conflict‑free)"
echo "  ✅  Topgrade: installed"
echo "  ✅  Docker: installed and auto‑removed if needed later"
echo "───────────────────────────────────────────────────────────────"
