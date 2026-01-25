#!/usr/bin/env bash
set -euo pipefail
# ────────────────────────────────────────────────────────
# Helpers – colour‑coded log functions
# ────────────────────────────────────────────────────────
run_as_root() { sudo -E bash -c "$*"; }
run_as_user() { local user="${SUDO_USER:-${USER}}"; sudo -u "$user" -H bash -c "$*"; }
info()  { printf '\e[32m[INFO]\e[0m %s\n' "$*" | tee -a "$log_file"; }
warn()  { printf '\e[33m[WARN]\e[0m %s\n' "$*" | tee -a "$log_file"; }
error() { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2 | tee -a "$log_file"; }
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
