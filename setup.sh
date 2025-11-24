#!/usr/bin/env bash
# ------------------------------------------------------------
# setup.sh
# Prompt the user for one of three actions and run the
# appropriate script.
# ------------------------------------------------------------

# Clear the terminal for a cleaner look
clear

# Show the menu
echo "To begin select of 1 of 3 options."
echo "1.  To install without Docker."
echo
echo "2.  To install with Docker"
echo
echo "3.  To make no changes and Exit."

# Read the user’s choice
read -rp "Enter choice [1-3]: " choice

# Decide what to do
case "$choice" in
    1)
        echo "You chose: install without Docker."
        echo "Running setup_without_docker.sh ..."
        # Make sure the script is executable
        chmod +x ./setup_without_docker.sh
        ./setup_without_docker.sh
        ;;
    2)
        echo "You chose: install with Docker."
        echo "Running setup_with_docker.sh ..."
        chmod +x ./setup_with_docker.sh
        ./setup_with_docker.sh
        ;;
    3)
        echo "You chose: exit. No changes will be made."
        exit 0
        ;;
    *)
        echo "❌  Invalid choice. Exiting."
        exit 1
        ;;
esac
