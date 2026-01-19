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
                    info "No timezone entered. Skipping timezone change."
                fi
                # Prefer timedatectl when available (systemd systems)
                if command -v timedatectl >/dev/null 2>&1; then
                    if timedatectl list-timezones | grep -qxF "$new_tz"; then
                        if run_as_root timedatectl set-timezone "$new_tz"; then
                            info "Timezone set to $new_tz via timedatectl"
                        else
                            warn "timedatectl failed to set timezone $new_tz"
                        fi
                    else
                        error "Timezone '$new_tz' not found in timedatectl list. Aborting timezone change."
                    fi
                else
                    # Fallback to /usr/share/zoneinfo symlink — validate first
                    if [[ -f "/usr/share/zoneinfo/$new_tz" ]]; then
                        if run_as_root ln -sf "/usr/share/zoneinfo/$new_tz" "$LOCALTIME"; then
                            info "Timezone set to $new_tz"
                        else
                            warn "Failed to set /etc/localtime to $new_tz"
                        fi
                    else
                        error "Timezone '/usr/share/zoneinfo/$new_tz' does not exist. Aborting timezone change."
                    fi
                fi
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
# 5️⃣ Dotfiles – install for the regular user
# ────────────────────────────────────────────────────────
info "Starting as regular user"
git clone https://github.com/flipsidecreations/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
chsh -s /bin/zsh
cd ..
# -----------------------------------------------------------------
#    Dotfiles - Install for root
# -----------------------------------------------------------------
sudo -s <<EOF
info "Now running as root"
git clone https://github.com/flipsidecreations/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
chsh -s /bin/zsh
EOF
info "Back to regular user."
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
# Remove known packages that commonly conflict with XCP‑NG tools
# --------------------------------------------------------------
remove_conflicting_packages() {
    info "Checking for packages that may conflict with XCP‑NG tools"
    local pkgs=(open-vm-tools open-vm-tools-desktop virtualbox-guest-utils virtualbox-guest-dkms vmware-tools-* qemu-guest-agent)
    local found=()
    for p in "${pkgs[@]}"; do
        if dpkg -s "$p" > /dev/null 2>&1; then
            found+=("$p")
        fi
    done

    if [[ ${#found[@]} -eq 0 ]]; then
        info "No known conflicting packages found."
        return 0
    fi

    info "Potentially conflicting packages detected: ${found[*]}"
    if [[ "$NONINTERACTIVE" -eq 1 ]]; then
        info "Non-interactive mode: purging ${found[*]}"
        run_as_root apt-get purge -y "${found[@]}" || warn "Failed to remove some packages."
    else
        read -rp "Remove these packages? [y/N] " ans
        case "$ans" in
            y|Y|yes|Yes)
                run_as_root apt-get purge -y "${found[@]}" || warn "Failed to remove some packages."
                ;;
            *)
                info "Skipping removal of conflicting packages."
                ;;
        esac
    fi
    return 0
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
# 7️⃣ System Update / upgrade 
# ────────────────────────────────────────────────────────
info "Running apt update / full-upgrade / auto-remove."
run_as_root apt-get update -y && run_as_root apt-get full-upgrade -y && run_as_root apt-get autoremove -y

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
