#!/usr/bin/env bash
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
printc "$HEADER" "To begin select of 1 of 3 options."
printc "$OPTION" "1.  To install without Docker."
printc "$OPTION" "2.  To install with Docker"
printc "$OPTION" "3.  To make no changes and Exit."
echo

# Prompt (in bold)
printf "%bEnter choice [1-3]: %b" "$PROMPT" "$RESET"
read -r choice

# -------------------------------------------------------------
# 6.  Execute the chosen action
# -------------------------------------------------------------
case "$choice" in
    1)
        printc "$SUCCESS" "You chose: install without Docker."
        printc "$SUCCESS" "Running setup_without_docker.sh ..."
        chmod +x ./setup_without_docker.sh
        ./setup_without_docker.sh
        ;;
    2)
        printc "$SUCCESS" "You chose: install with Docker."
        printc "$SUCCESS" "Running setup_with_docker.sh ..."
        chmod +x ./setup_with_docker.sh
        ./setup_with_docker.sh
        ;;
    3)
        printc "$PROMPT" "You chose: exit. No changes will be made."
        exit 0
        ;;
    *)
        printc "$ERROR" "❌  Invalid choice. Exiting."
        exit 1
        ;;
esac
