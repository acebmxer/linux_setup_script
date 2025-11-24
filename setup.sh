#!/usr/bin/env bash
# --------------------------------------------------------
# setup.sh  –  colourised interactive installer
# --------------------------------------------------------

# --- Colour / style definitions ------------------------------------
# 1. ANSI colour codes (foreground)
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

# 2. Styles
BOLD="\033[1m"
UNDERLINE="\033[4m"

# 3. Reset
NC="\033[0m"   # No Colour – reset everything

# Helper: print a line in a single colour
printc() {
    local colour="$1"
    shift
    printf "%b%s%b\n" "$colour" "$*" "$NC"
}

# --------------------------------------------------------
# 1️⃣  Show the menu (colourised)
clear
printc "$CYAN" "To begin select of 1 of 3 options."
printc "$YELLOW" "1.  To install without Docker."
printc "$YELLOW" "2.  To install with Docker"
printc "$YELLOW" "3.  To make no changes and Exit."
echo  # blank line

# Prompt (in bold)
printf "%bEnter choice [1-3]: %b" "$BOLD" "$NC"
read -r choice

# --------------------------------------------------------
# 2️⃣  Execute the chosen action
case "$choice" in
    1)
        printc "$GREEN" "You chose: install without Docker."
        printc "$GREEN" "Running setup_without_docker.sh ..."
        chmod +x ./setup_without_docker.sh
        ./setup_without_docker.sh
        ;;
    2)
        printc "$GREEN" "You chose: install with Docker."
        printc "$GREEN" "Running setup_with_docker.sh ..."
        chmod +x ./setup_with_docker.sh
        ./setup_with_docker.sh
        ;;
    3)
        printc "$MAGENTA" "You chose: exit. No changes will be made."
        exit 0
        ;;
    *)
        printc "$RED" "❌  Invalid choice. Exiting."
        exit 1
        ;;
esac
