#!/bin/bash

#############################################
# SSH Login Telegram Notifier - Uninstaller
#
# This script removes the SSH login
# notification system
#############################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/ssh-login-notifier"
SCRIPT_NAME="ssh-login-notify.sh"
PAM_CONFIG="/etc/pam.d/sshd"

echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}SSH Login Telegram Notifier Uninstaller${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo ./uninstall.sh"
    exit 1
fi

read -p "Are you sure you want to uninstall SSH Login Notifier? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 1:${NC} Removing notification script..."
if [ -f "${INSTALL_DIR}/${SCRIPT_NAME}" ]; then
    rm -f "${INSTALL_DIR}/${SCRIPT_NAME}"
    echo -e "${GREEN}✓${NC} Script removed"
else
    echo -e "${YELLOW}!${NC} Script not found (already removed?)"
fi

echo ""
echo -e "${YELLOW}Step 2:${NC} Removing PAM configuration..."
if [ -f "$PAM_CONFIG" ]; then
    # Backup current config
    cp "$PAM_CONFIG" "${PAM_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"

    # Remove our lines
    sed -i '/# SSH Login Telegram Notifier/d' "$PAM_CONFIG"
    sed -i '/ssh-login-notify.sh/d' "$PAM_CONFIG"

    echo -e "${GREEN}✓${NC} PAM configuration removed"
else
    echo -e "${YELLOW}!${NC} PAM config not found"
fi

echo ""
read -p "Do you want to remove configuration files? (y/N): " REMOVE_CONFIG
if [ "$REMOVE_CONFIG" = "y" ] || [ "$REMOVE_CONFIG" = "Y" ]; then
    echo -e "${YELLOW}Step 3:${NC} Removing configuration..."
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        echo -e "${GREEN}✓${NC} Configuration removed"
    else
        echo -e "${YELLOW}!${NC} Configuration directory not found"
    fi
else
    echo -e "${YELLOW}Step 3:${NC} Keeping configuration files at ${CONFIG_DIR}"
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Uninstallation Complete!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "The SSH login notifier has been removed from your system."
echo ""
