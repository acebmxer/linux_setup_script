#!/usr/bin/env bash
set -euo pipefail

# ────────────────────────────────────────────────────────
# Helpers – colour‑coded log functions
# ────────────────────────────────────────────────────────
run_as_root() { sudo -E bash -c "$*"; }
run_as_user() { local user="${SUDO_USER:-${USER}}"; sudo -u "$user" -H bash -c "$*"; }
info()  { printf '\e[32m[INFO]\e[0m %s\n' "$*"; }
warn()  { printf '\e[33m[WARN]\e[0m %s\n' "$*"; }
error() { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; }
# ────────────────────────────────────────────────────────
# 2️⃣ Idempotency helper
# ────────────────────────────────────────────────────────
needs_update() {
    local flag_file="$1"
    [[ ! -f "$flag_file" ]]
}
# ────────────────────────────────────────────────────────
# Install prereq for timezone change and basic tools.
run_as_root apt-get update
run_as_root apt-get install -y --no-install-recommends jq tzdata git curl wget python3 python3-venv || true
# ────────────────────────────────────────────────────────
# 3️⃣ Timezone  - change the timezone
# ────────────────────────────────────────────────────────
# TARGET_TZ="/usr/share/zoneinfo/America/New_York"
LOCALTIME="/etc/localtime"
current_tz="unknown"
if [[ -e "$LOCALTIME" ]]; then
    current_tz=$(readlink -f "$LOCALTIME" | sed 's@^/usr/share/zoneinfo/@@' || true)
fi

# Non-interactive helper: set NONINTERACTIVE=1 or pass -y/--yes to skip prompts
NONINTERACTIVE=${NONINTERACTIVE:-0}
while [[ ${1:-} ]]; do
    case "$1" in
        -y|--yes) NONINTERACTIVE=1; shift ;;
        *) break ;;
    esac
done

if [[ -n "$current_tz" ]]; then
    if [[ "$NONINTERACTIVE" -eq 1 ]]; then
        info "Current timezone: $current_tz (non-interactive mode: skipping change)"
    else
        read -r -p "Your current timezone is $current_tz. Do you want to change it? (y/n): " choice
        case "$choice" in
            [yY])
                if command -v timedatectl >/dev/null 2>&1; then
                    echo "Available timezones (sample):"
                    timedatectl list-timezones | head -n 40
                else
                    if python3 -c 'import zoneinfo' >/dev/null 2>&1; then
                        python3 - <<'PY'
import zoneinfo, json
print('\n'.join(sorted(zoneinfo.available_timezones())))
PY
                    else
                        warn "Cannot list timezones (no timedatectl and python3 zoneinfo)."
                    fi
                fi
                read -r -p "Enter the timezone you want to set (e.g., America/Los_Angeles): " new_tz
                if [[ -z "$new_tz" ]]; then
                    error "No timezone entered. Aborting."
                    exit 1
                fi
                run_as_root ln -sf "/usr/share/zoneinfo/$new_tz" "$LOCALTIME"
                info "Timezone set to $new_tz"
                ;;
            [nN])
                info "Timezone change skipped."
                ;;
            *)
                error "Invalid choice. Please answer 'y' or 'n'."
                exit 1
                ;;
        esac
    fi
fi
# ────────────────────────────────────────────────────────
# 4️⃣ Ensure deb-get is installed
# ────────────────────────────────────────────────────────
ensure_deb_get_installed() {
    if ! command -v deb-get >/dev/null 2>&1; then
        info "deb-get not found – installing prerequisites."
        run_as_root apt-get update
        run_as_root apt-get install -y --no-install-recommends curl lsb-release wget || true
        info "Downloading deb-get installer to /tmp/deb-get.sh"
        tmp_script="/tmp/deb-get.sh"
        curl -fsSL -o "$tmp_script" https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get || { warn "Failed to download deb-get installer"; return 1; }
        run_as_root bash "$tmp_script" install deb-get || { warn "deb-get installer failed"; rm -f "$tmp_script"; return 1; }
        rm -f "$tmp_script"
    else
        info "deb-get is already installed."
    fi
}
ensure_deb_get_installed || warn "deb-get installation had issues"
# ────────────────────────────────────────────────────────
# 5️⃣ Dotfiles – install for the regular user
# ────────────────────────────────────────────────────────
info "Installing user dotfiles for invoking user"
INVOKING_USER="${SUDO_USER:-${USER}}"
USER_HOME=$(eval echo "~$INVOKING_USER")
if ! command -v git >/dev/null 2>&1; then
    run_as_root apt-get update
    run_as_root apt-get install -y git || warn "git install failed"
fi
if [[ -d "$USER_HOME/dotfiles" ]]; then
    info "Updating existing dotfiles in $USER_HOME/dotfiles"
    run_as_user "git -C $USER_HOME/dotfiles pull --ff-only || true"
else
    info "Cloning dotfiles into $USER_HOME/dotfiles"
    run_as_user "git clone https://github.com/flipsidecreations/dotfiles.git $USER_HOME/dotfiles"
fi
run_as_user "cd $USER_HOME/dotfiles && ./install.sh || true"

info "Installing root dotfiles (if desired)"
if [[ -d /root/dotfiles ]]; then
    info "Updating /root/dotfiles"
    run_as_root "git -C /root/dotfiles pull --ff-only || true"
else
    run_as_root "git clone https://github.com/flipsidecreations/dotfiles.git /root/dotfiles || true"
fi
run_as_root "cd /root/dotfiles && ./install.sh || true"
info "Dotfiles setup attempted for user and root."
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
# info "Installing XCP‑NG Tools …"
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
remove_conflicting_packages
info "Running the XCP‑NG installer script..."
run_as_root bash /mnt/Linux/install.sh
# Unmount the ISO (best effort)
run_as_root umount /mnt || warn "Failed to unmount /mnt – you may need to unmount it manually."
# Wait a bit so the system settles
info "Pausing for 10 seconds to let services start..."
sleep 10
info "XCP‑NG Tools installation completed."
# ────────────────────────────────────────────────────────
# 7️⃣ System pre‑upgrade (optional but handy)
# ────────────────────────────────────────────────────────
info "Running a quick apt‑update before topgrade."
run_as_root apt-get update

# System upgrade – Topgrade (idempotent)
info "Installing/updating topgrade via deb-get"
if run_as_root deb-get install -y topgrade; then
    info "Topgrade installed/updated via deb-get."
else
    warn "deb-get failed to install topgrade; attempting deb-get upgrade topgrade"
    run_as_root deb-get upgrade topgrade || warn "Failed to upgrade topgrade via deb-get"
fi

info "Running topgrade as invoking user (it may request credentials for some actions)"
run_as_user "topgrade -y" || warn "topgrade encountered issues or some steps failed"
warn "The system is fully updated and may need a reboot to apply changes."
# ────────────────────────────────────────────────────────
# 10️⃣ Ask the user if they want to reboot
# ────────────────────────────────────────────────────────
if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    info "Non-interactive mode: skipping reboot prompt (no reboot)."
else
    read -r -p "All done! Do you want to reboot now? (y/N) " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        run_as_root reboot
    else
        info "You can reboot later whenever you’re ready."
    fi
fi
