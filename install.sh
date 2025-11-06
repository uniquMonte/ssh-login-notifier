#!/bin/bash

#############################################
# SSH Login Telegram Notifier - Installer
#
# This script installs and configures the
# SSH login notification system
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/ssh-login-notifier"
CONFIG_FILE="${CONFIG_DIR}/config"
SCRIPT_NAME="ssh-login-notify.sh"
PAM_CONFIG="/etc/pam.d/sshd"
GITHUB_RAW_URL="https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main"
TEMP_DIR=$(mktemp -d)

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}SSH Login Telegram Notifier Installer${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo bash <(curl -Ls ${GITHUB_RAW_URL}/install.sh)"
    echo "Or: sudo ./install.sh"
    exit 1
fi

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Check if notify.sh exists locally, otherwise download from GitHub
NOTIFY_SCRIPT=""
if [ -f "./notify.sh" ]; then
    echo -e "${GREEN}✓${NC} Found notify.sh locally"
    NOTIFY_SCRIPT="./notify.sh"
else
    echo -e "${YELLOW}Downloading notify.sh from GitHub...${NC}"

    # Check if curl or wget is available
    if command -v curl &> /dev/null; then
        curl -fsSL "${GITHUB_RAW_URL}/notify.sh" -o "${TEMP_DIR}/notify.sh"
    elif command -v wget &> /dev/null; then
        wget -q -O "${TEMP_DIR}/notify.sh" "${GITHUB_RAW_URL}/notify.sh"
    else
        echo -e "${RED}Error: Neither curl nor wget found. Cannot download notify.sh${NC}"
        exit 1
    fi

    if [ ! -f "${TEMP_DIR}/notify.sh" ]; then
        echo -e "${RED}Error: Failed to download notify.sh${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Downloaded notify.sh successfully"
    NOTIFY_SCRIPT="${TEMP_DIR}/notify.sh"
fi

echo ""
echo -e "${YELLOW}Step 1:${NC} Creating configuration directory..."
mkdir -p "$CONFIG_DIR"
chmod 755 "$CONFIG_DIR"
echo -e "${GREEN}✓${NC} Configuration directory created"

# Get Telegram Bot Token and Chat ID
echo ""
echo -e "${YELLOW}Step 2:${NC} Telegram Configuration"
echo ""

if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Configuration file already exists.${NC}"
    read -p "Do you want to reconfigure? (y/N): " RECONFIG
    if [ "$RECONFIG" != "y" ] && [ "$RECONFIG" != "Y" ]; then
        echo "Keeping existing configuration."
        SKIP_CONFIG=1
    fi
fi

if [ -z "$SKIP_CONFIG" ]; then
    echo "To get your Telegram Bot Token:"
    echo "1. Open Telegram and search for @BotFather"
    echo "2. Send /newbot and follow the instructions"
    echo "3. Copy the bot token"
    echo ""
    read -p "Enter your Telegram Bot Token: " BOT_TOKEN

    echo ""
    echo "To get your Chat ID:"
    echo "1. Search for @userinfobot in Telegram"
    echo "2. Start a chat and it will show your Chat ID"
    echo "3. Or send a message to your bot and visit:"
    echo "   https://api.telegram.org/bot<YourBOTToken>/getUpdates"
    echo ""
    read -p "Enter your Telegram Chat ID: " CHAT_ID

    # Validate inputs
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        echo -e "${RED}Error: Bot Token and Chat ID cannot be empty${NC}"
        exit 1
    fi

    # Ask for custom server name
    echo ""
    echo "Custom Server Name (Optional):"
    echo "Set a friendly name for this server (e.g., 'Production Server', 'Dev VPS')"
    echo "Leave empty to use system hostname: $(hostname)"
    echo ""
    read -p "Enter custom server name (or press Enter to skip): " SERVER_NAME

    # Ask for failed login report configuration
    echo ""
    echo "Failed Login Report (Optional):"
    echo "Receive periodic reports about failed SSH login attempts."
    echo ""
    echo "Select report frequency:"
    echo "  1) Hourly (every hour)"
    echo "  2) Every 6 hours"
    echo "  3) Every 12 hours"
    echo "  4) Daily (once per day)"
    echo "  5) Disabled (no reports)"
    echo ""
    read -p "Enter your choice [1-5] (default: 5-Disabled): " REPORT_CHOICE

    case "$REPORT_CHOICE" in
        1)
            REPORT_INTERVAL="hourly"
            CRON_SCHEDULE="0 * * * *"
            ;;
        2)
            REPORT_INTERVAL="6hours"
            CRON_SCHEDULE="0 */6 * * *"
            ;;
        3)
            REPORT_INTERVAL="12hours"
            CRON_SCHEDULE="0 */12 * * *"
            ;;
        4)
            REPORT_INTERVAL="daily"
            CRON_SCHEDULE="0 8 * * *"
            ;;
        *)
            REPORT_INTERVAL="disabled"
            CRON_SCHEDULE=""
            ;;
    esac

    # Create config file
    cat > "$CONFIG_FILE" <<EOF
# Telegram Bot Configuration for SSH Login Notifier
# Generated on $(date)

# Your Telegram Bot Token from @BotFather
TELEGRAM_BOT_TOKEN="${BOT_TOKEN}"

# Your Telegram Chat ID (can be user ID or group ID)
TELEGRAM_CHAT_ID="${CHAT_ID}"

# Custom server name (optional)
# If not set, system hostname will be used
SERVER_NAME="${SERVER_NAME}"

# Failed login report interval
# Options: hourly, 6hours, 12hours, daily, disabled
REPORT_INTERVAL="${REPORT_INTERVAL}"
EOF

    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}✓${NC} Configuration file created at ${CONFIG_FILE}"
fi

# Test Telegram connection
echo ""
echo -e "${YELLOW}Step 3:${NC} Testing Telegram connection..."
source "$CONFIG_FILE"

TEST_MESSAGE="🔔 SSH Login Notifier test message from $(hostname)"
TELEGRAM_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

if command -v curl &> /dev/null; then
    RESPONSE=$(curl -s -X POST "$TELEGRAM_URL" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${TEST_MESSAGE}" \
        -d "parse_mode=Markdown")

    if echo "$RESPONSE" | grep -q '"ok":true'; then
        echo -e "${GREEN}✓${NC} Test message sent successfully! Check your Telegram."
    else
        echo -e "${RED}✗${NC} Failed to send test message."
        echo "Response: $RESPONSE"
        exit 1
    fi
else
    echo -e "${YELLOW}Warning: curl not found. Skipping test.${NC}"
fi

# Install the script
echo ""
echo -e "${YELLOW}Step 4:${NC} Installing notification script..."
cp "$NOTIFY_SCRIPT" "${INSTALL_DIR}/${SCRIPT_NAME}"
chmod 755 "${INSTALL_DIR}/${SCRIPT_NAME}"
echo -e "${GREEN}✓${NC} Script installed to ${INSTALL_DIR}/${SCRIPT_NAME}"

# Configure PAM
echo ""
echo -e "${YELLOW}Step 5:${NC} Configuring PAM for SSH..."

# Backup PAM config
if [ -f "$PAM_CONFIG" ]; then
    cp "$PAM_CONFIG" "${PAM_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
    echo -e "${GREEN}✓${NC} PAM config backed up"
fi

# Check if our line already exists
# Use type=open_session to only trigger on login, not on logout
PAM_LINE="session optional pam_exec.so type=open_session seteuid ${INSTALL_DIR}/${SCRIPT_NAME}"

if grep -q "ssh-login-notify.sh" "$PAM_CONFIG" 2>/dev/null; then
    echo -e "${YELLOW}!${NC} PAM configuration already exists"
else
    # Add our configuration after the session block
    echo "" >> "$PAM_CONFIG"
    echo "# SSH Login Telegram Notifier" >> "$PAM_CONFIG"
    echo "$PAM_LINE" >> "$PAM_CONFIG"
    echo -e "${GREEN}✓${NC} PAM configured successfully"
fi

# Install failed login report script if enabled
if [ "$REPORT_INTERVAL" != "disabled" ] && [ ! -z "$CRON_SCHEDULE" ]; then
    echo ""
    echo -e "${YELLOW}Step 6:${NC} Setting up failed login reports..."

    # Download or copy the report script
    REPORT_SCRIPT_NAME="report-failed-logins.sh"
    if [ -f "./report-failed-logins.sh" ]; then
        cp ./report-failed-logins.sh "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}"
    else
        # Try to download from GitHub
        if command -v curl &> /dev/null; then
            curl -fsSL "${GITHUB_RAW_URL}/report-failed-logins.sh" -o "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}"
        elif command -v wget &> /dev/null; then
            wget -q -O "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}" "${GITHUB_RAW_URL}/report-failed-logins.sh"
        fi
    fi

    if [ -f "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}" ]; then
        chmod 755 "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}"
        echo -e "${GREEN}✓${NC} Report script installed"

        # Set up cron job
        CRON_LINE="${CRON_SCHEDULE} ${INSTALL_DIR}/${REPORT_SCRIPT_NAME}"

        # Check if cron job already exists
        if crontab -l 2>/dev/null | grep -q "report-failed-logins.sh"; then
            echo -e "${YELLOW}!${NC} Cron job already exists"
        else
            # Add cron job
            (crontab -l 2>/dev/null; echo "# SSH Failed Login Report"; echo "$CRON_LINE") | crontab -
            echo -e "${GREEN}✓${NC} Cron job configured (${REPORT_INTERVAL})"
        fi
    else
        echo -e "${YELLOW}!${NC} Could not install report script"
    fi
fi

# Final instructions
echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Configuration:"
echo "  - Config file: ${CONFIG_FILE}"
echo "  - Script location: ${INSTALL_DIR}/${SCRIPT_NAME}"
echo "  - PAM config: ${PAM_CONFIG}"

if [ "$REPORT_INTERVAL" != "disabled" ]; then
    echo "  - Failed login reports: Enabled (${REPORT_INTERVAL})"
else
    echo "  - Failed login reports: Disabled"
fi

echo ""
echo "The notifier is now active!"
echo "You should receive a Telegram message whenever someone logs in via SSH."

if [ "$REPORT_INTERVAL" != "disabled" ]; then
    echo "You will also receive periodic reports about failed login attempts."
fi

echo ""
echo "To test, try logging in via SSH from another terminal."
echo ""
echo "To uninstall, run:"
echo "  sudo bash <(curl -Ls ${GITHUB_RAW_URL}/uninstall.sh)"
echo ""
