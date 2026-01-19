#!/usr/bin/env bash
set -euo pipefail
log_dir="$(dirname "$0")/log"
mkdir -p "$log_dir" || { echo "Failed to create log directory"; exit 1; }
log_file="$log_dir/linux_setup_script_$(date +%Y-%m-%d_%H-%M-%S).log"
exec > >(tee -a "$log_file") 2>&1

#-------------------------------------------------------------
# Keep only the 5 most recent log files
#-------------------------------------------------------------
cd 'log' || { echo "Failed to change to log directory"; exit 1; }
find . -maxdepth 1 -name "linux_setup_script_*.log" -type f | sort -r | tail -n +6 | xargs -r rm
cd ..
#-------------------------------------------------------------
#   Helper Fucntions
#-------------------------------------------------------------
run_as_root() { sudo -E bash -c "$*"; }
run_as_user() { local user="${SUDO_USER:-${USER}}"; sudo -u "$user" -H bash -c "$*"; }
info()  { printf '\e[32m[INFO]\e[0m %s\n' "$*" | tee -a "$log_file"; }
warn()  { printf '\e[33m[WARN]\e[0m %s\n' "$*" | tee -a "$log_file"; }
error() { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2 | tee -a "$log_file"; }

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
SETUP_THEME=dark
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
printc "$HEADER" "A log file as has been created /log/"$log_file" the 5 most recent logs will be kept."
printc "$HEADER" "To begin select of 1 of 4 options."
printc "$OPTION" "1.  To fully upgrade the system and Install xen-guest-utilities."
printc "$OPTION" "2.  To fully upgrade the system with Topgrade and Install xen-guest-utilities."
printc "$OPTION" "3.  To install Docker"
printc "$OPTION" "4.  To install or update xen-guest-utilities."
printc "$OPTION" "5.  To update your system"
printc "$OPTION" "6.  To update your system with Topgrade."
printc "$OPTION" "7.  To make no changes and Exit."
echo

# Prompt (in bold)
printf "%bEnter choice [1-3]: %b" "$PROMPT" "$RESET"
read -r choice

# -------------------------------------------------------------
# 6.  Execute the chosen action
# -------------------------------------------------------------
case "$choice" in
    1)
        printc "$SUCCESS" "You choose: To fully upgrade the system and Install xen-guest-utilities."
        printc "$SUCCESS" "Running install_and_update.sh ..."
        chmod +x ./install_and_update.sh
        ./install_and_update.sh
        ;;
    2)
        printc "$SUCCESS" "You choose: To fully upgrade the system with Topgrade and Install xen-guest-utilities."
        printc "$SUCCESS" "Running install_and_update_topgrade.sh ..."
        chmod +x ./install_and_update_topgrade.sh
        ./install_and_update_togprade.sh
        ;;
    3)
        printc "$SUCCESS" "You choose: To fully upgrade the system and install Docker."
        printc "$SUCCESS" "Running install_docker.sh ..."
        chmod +x ./install_docker.sh
        ./install_docker.sh
        ;;
    4)
        printc "$SUCCESS" "You choose: To install or update xen-guest-utilities."
        printc "$SUCCESS" "Running install_xen_tools.sh ..."
        chmod +x ./install_xen_tools.sh
        ./install_xen_tools.sh
        ;;
    5)
        printc "$SUCCESS" "You choose: To run updates on your system."
        printc "$SUCCESS" "Running update.sh ..."
        chmod +x ./update.sh
        ./update.sh
        ;;
    6)
        printc "$SUCCESS" "You choose: To run updates on your system with Topgrade."
        printc "$SUCCESS" "Running topgrade.sh ..."
        chmod +x ./topgrade.sh
        ./topgrade.sh
        ;;
    7)
        printc "$PROMPT" "You chose: exit. No changes will be made."
        exit 0
        ;;
    *)
        printc "$ERROR" "❌  Invalid choice. Exiting."
        exit 1
        ;;
esac
