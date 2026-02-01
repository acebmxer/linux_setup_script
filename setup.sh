#!/bin/bash
SETUP_THEME="${SETUP_THEME:-light}"
# ────────────────────────────────────────────────────────
# Helpers – colour‑coded log functions
# ────────────────────────────────────────────────────────
run_as_root() { sudo -E sh -c "$*"; }
run_as_user() { local user="${SUDO_USER:-${USER}}"; sudo -u "$user" -H sh -c "$*"; }
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
# -------------------------------------------------------------
# setup.sh  –  adaptive colour menu
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1.  Detect terminal colour capability
# -------------------------------------------------------------
COLS=$(tput colors)
if [[ "$COLS" -lt 16 ]]; then
    echo "Your terminal does not support 16 colours. Exiting."
    exit 1
fi

# -------------------------------------------------------------
# 2.  Guess theme (dark or light)
# -------------------------------------------------------------
#  * If $COLORTERM contains "truecolor" or "24bit" we assume a modern
#    terminal that is likely dark (most terminals default to dark).
#  * Otherwise we try to see if the default background is black or
#    white using `xrdb` (X‑resources) – this works on X11 systems.
#  * If nothing works, we fall back to a *dark* theme.
#
#  The user can force a theme with SETUP_THEME=light|dark
# -------------------------------------------------------------
theme="dark"            # default
if [[ -n "${SETUP_THEME}" ]]; then
    case "${SETUP_THEME,,}" in
        light) theme="light" ;;
        dark)  theme="dark"  ;;
    esac
else
    # Heuristic – works on most GNOME/Unity/KDE terminals
    if command -v xrdb >/dev/null 2>&1; then
        bg=$(xrdb -query | grep -i "background" | awk '{print $2}')
        if [[ "$bg" == "#ffffff" || "$bg" == "#fffff" ]]; then
            theme="light"
        fi
    fi
fi

# -------------------------------------------------------------
# 3.  Define colour codes based on the theme
# -------------------------------------------------------------
case "$theme" in
    light)
        HEADER="\033[30;1m"   # black bold
        OPTION="\033[34m"     # blue
        SUCCESS="\033[32m"    # green
        ERROR="\033[31m"      # red
        PROMPT="\033[33m"     # yellow
        ;;
    dark)
        HEADER="\033[37;1m"   # white bold
        OPTION="\033[96m"     # bright cyan
        SUCCESS="\033[92m"    # bright green
        ERROR="\033[91m"      # bright red
        PROMPT="\033[93m"     # bright yellow
        ;;
esac
RESET="\033[0m"

# -------------------------------------------------------------
# 4.  Helper: print a line in a single colour
# -------------------------------------------------------------
printc() {
    local colour="$1"
    shift
    printf "%b%s%b\n" "$colour" "$*" "$RESET"
}

# -------------------------------------------------------------
# 5.  Show the menu (colourised)
# -------------------------------------------------------------
clear
printc "$HEADER" "To begin select 1 of 6 options."
printc "$OPTION" "1.  To fully update and upgrade bare metal."
printc "$OPTION" "2.  To fully update and upgrade xcp-ng vm."
printc "$OPTION" "3.  To install or update xen-guest-utilities."
printc "$OPTION" "4.  To update your system"
printc "$OPTION" "5.  To install docker."
printc "$OPTION" "6.  To make no changes and Exit."
echo

# Prompt (in bold)
printf "%bEnter choice [1-6]: %b" "$PROMPT" "$RESET"
read -r choice

# -------------------------------------------------------------
# 6.  Execute the chosen action
# -------------------------------------------------------------
case "$choice" in
    1)
        printc "$SUCCESS" "You choose: To fully update and upgrade bare metal."
        # ────────────────────────────────────────────────────────
        # Install prereqs and basic tools.
        run_as_root apt-get update
        run_as_root apt-get install -y --no-install-recommends jq tzdata git curl wget || true
        # ────────────────────────────────────────────────────────
        # 5️⃣ Dotfiles – install for the regular user
        # ────────────────────────────────────────────────────────
        info "Starting as regular user"
        # ────────────────────────────────────────────────────────
        # Remove dotfiles folder from previous install
        # ────────────────────────────────────────────────────────
        rm -rf ~/dotfiles
        info "Previous dotfiles folder was removed."
        git clone https://github.com/flipsidecreations/dotfiles.git ~/dotfiles
        cd ~/dotfiles
        ./install.sh
        chsh -s /bin/zsh
        cd ..
        # -----------------------------------------------------------------
        #    Dotfiles - Install for root
        # -----------------------------------------------------------------
        sudo -s <<'EOF'
info() { printf '\e[32m[INFO]\e[0m %s\n' "$*"; }
info "Now running as root"
# ────────────────────────────────────────────────────────
# Remove dotfiles folder from previous install
# ────────────────────────────────────────────────────────
rm -rf ~/dotfiles
git clone https://github.com/flipsidecreations/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
chsh -s /bin/zsh
EOF
        info "Back to regular user."
        run_as_root "apt-get update -y && apt-get full-upgrade -y && apt-get autoremove -y && apt-get clean -y && apt-get autoclean -y"
        info "the system has been fully updated and upgraded to the latest versions.  Please reboot your system asap."
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
        ;;
    2)
        printc "$SUCCESS" "You choose: To fully update and upgrade xcp-ng vm."
        # ────────────────────────────────────────────────────────
        # Install prereqs and basic tools.
        run_as_root apt-get update
        run_as_root apt-get install -y --no-install-recommends jq tzdata git curl wget || true
        # ────────────────────────────────────────────────────────
        #   Dotfiles – install for the regular user
        # ────────────────────────────────────────────────────────
        info "Starting as regular user"
        # ────────────────────────────────────────────────────────
        # Remove dotfiles folder from previous install
        # ────────────────────────────────────────────────────────
        rm -rf ~/dotfiles
        info "Previous dotfiles folder was removed."
        git clone https://github.com/flipsidecreations/dotfiles.git ~/dotfiles
        cd ~/dotfiles
        ./install.sh
        chsh -s /bin/zsh
        cd ..
        # -----------------------------------------------------------------
        #    Dotfiles - Install for root
        # -----------------------------------------------------------------
        sudo -s <<'EOF'
info() { printf '\e[32m[INFO]\e[0m %s\n' "$*"; }
info "Now running as root"
# ────────────────────────────────────────────────────────
# Remove dotfiles folder from previous install
# ────────────────────────────────────────────────────────
rm -rf ~/dotfiles
git clone https://github.com/flipsidecreations/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
chsh -s /bin/zsh
EOF
        info "Back to regular user."
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
                    run_as_root "apt-get purge -y xe-guest-utilities" || warn "Failed to remove xe-guest-utilities."
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
                        run_as_root "apt-get purge -y xen-guest-agent" || warn "Failed to remove xen-guest-agent."
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
        # 2️⃣  Mount the ISO if it isn't already mounted
        # --------------------------------------------------------------
        mount_iso() {
            if mountpoint -q /mnt; then
                info "ISO already mounted at /mnt."
            else
                warn "ISO not mounted. Please insert the XCP‑NG ISO and press Enter to continue…"
                read -r
                run_as_root "mount /dev/cdrom /mnt" || { error "Failed to mount /dev/cdrom"; exit 1; }
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
            read -rp "Remove these packages? [y/N] " ans
            case "$ans" in
                y|Y|yes|Yes)
                    run_as_root "apt-get purge -y ${found[*]}" || warn "Failed to remove some packages."
                    ;;
                *)
                    info "Skipping removal of conflicting packages."
                    ;;
            esac
            return 0
        }
        # --------------------------------------------------------------
        # 5️⃣  Run the installation
        # --------------------------------------------------------------
        mount_iso
        ensure_installer
        remove_conflicting_packages
        info "Running the XCP‑NG installer script..."
        run_as_root "bash /mnt/Linux/install.sh"
        # Unmount the ISO (best effort)
        run_as_root "umount /mnt" || warn "Failed to unmount /mnt – you may need to unmount it manually."
        # Wait a bit so the system settles
        info "Pausing for 10 seconds to let services start..."
        sleep 10
        info "XCP‑NG Tools installation completed."
        run_as_root "apt-get update -y && apt-get full-upgrade -y && apt-get autoremove -y && apt-get clean -y && apt-get autoclean -y"
        info "the system has been fully updated and upgraded to the latest versions.  Please reboot your system asap."
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
        ;;
    3)
        printc "$SUCCESS" "You choose: To install or update xen-guest-utilities."
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
                    run_as_root "apt-get purge -y xe-guest-utilities" || warn "Failed to remove xe-guest-utilities."
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
                        run_as_root "apt-get purge -y xen-guest-agent" || warn "Failed to remove xen-guest-agent."
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
        # 2️⃣  Mount the ISO if it isn't already mounted
        # --------------------------------------------------------------
        mount_iso() {
            if mountpoint -q /mnt; then
                info "ISO already mounted at /mnt."
            else
                warn "ISO not mounted. Please insert the XCP‑NG ISO and press Enter to continue…"
                read -r
                run_as_root "mount /dev/cdrom /mnt" || { error "Failed to mount /dev/cdrom"; exit 1; }
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
            read -rp "Remove these packages? [y/N] " ans
            case "$ans" in
                y|Y|yes|Yes)
                    run_as_root "apt-get purge -y ${found[*]}" || warn "Failed to remove some packages."
                    ;;
                *)
                    info "Skipping removal of conflicting packages."
                    ;;
            esac
            return 0
        }
        # --------------------------------------------------------------
        # 5️⃣  Run the installation
        # --------------------------------------------------------------
        mount_iso
        ensure_installer
        remove_conflicting_packages
        info "Running the XCP‑NG installer script..."
        run_as_root "bash /mnt/Linux/install.sh"
        # Unmount the ISO (best effort)
        run_as_root "umount /mnt" || warn "Failed to unmount /mnt – you may need to unmount it manually."
        # Wait a bit so the system settles
        info "Pausing for 10 seconds to let services start..."
        sleep 10
        info "XCP‑NG Tools installation completed."
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
        ;;
    4)
        printc "$SUCCESS" "You choose: To run updates on your system."
        run_as_root "apt-get update -y && apt-get full-upgrade -y && apt-get autoremove -y && apt-get clean -y && apt-get autoclean -y"
        info "the system has been fully updated and upgraded to the latest versions.  Please reboot your system asap."
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
        ;;
    5)
        printc "$PROMPT" "You chose: To install docker."
        # -----------------------------------------------------------------
        # 7️⃣  Docker – install & verify
        # -----------------------------------------------------------------
        info "Installing Docker …"
        run_as_root apt install apt-transport-https ca-certificates curl software-properties-common -y
        run_as_root "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
        run_as_root "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' | tee /etc/apt/sources.list.d/docker.list > /dev/null"
        run_as_root apt update
        run_as_root apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
        # run_as_root groupadd docker
        run_as_root "usermod -aG docker ${SUDO_USER:-${USER}}"
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
        ;;
    
    6)
        printc "$PROMPT" "You chose: exit. No changes will be made."
        exit 0
        ;;
    *)
        printc "$ERROR" "❌  Invalid choice. Exiting."
        exit 1
        ;;
esac