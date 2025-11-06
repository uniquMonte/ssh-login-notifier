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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/ssh-login-notifier"
CONFIG_FILE="${CONFIG_DIR}/config"
SCRIPT_NAME="ssh-login-notify.sh"
REPORT_SCRIPT_NAME="report-failed-logins.sh"
PAM_CONFIG="/etc/pam.d/sshd"
GITHUB_RAW_URL="https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main"
TEMP_DIR=$(mktemp -d)

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo bash <(curl -Ls ${GITHUB_RAW_URL}/install.sh)"
    echo "Or: sudo ./install.sh"
    exit 1
fi

# Function to check if already installed
check_installation() {
    if [ -f "${INSTALL_DIR}/${SCRIPT_NAME}" ] && [ -f "${CONFIG_FILE}" ]; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

# Function to display current configuration
show_config() {
    echo ""
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}Current Configuration${NC}"
    echo -e "${BLUE}=====================================${NC}"

    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo ""
        echo -e "  Bot Token: ${GREEN}${TELEGRAM_BOT_TOKEN:0:10}...${NC}"
        echo -e "  Chat ID: ${GREEN}${TELEGRAM_CHAT_ID}${NC}"
        echo -e "  Server Name: ${GREEN}${SERVER_NAME:-$(hostname)}${NC}"
        echo -e "  Report Interval: ${GREEN}${REPORT_INTERVAL:-disabled}${NC}"
        echo ""

        # Check cron job
        if crontab -l 2>/dev/null | grep -q "report-failed-logins.sh"; then
            CRON_STATUS="${GREEN}Active${NC}"
            CRON_SCHEDULE=$(crontab -l 2>/dev/null | grep "report-failed-logins.sh" | grep -v "^#" | head -1)
        else
            CRON_STATUS="${YELLOW}Not configured${NC}"
            CRON_SCHEDULE="N/A"
        fi
        echo -e "  Cron Job: ${CRON_STATUS}"
        if [ "$CRON_SCHEDULE" != "N/A" ]; then
            echo -e "  Schedule: ${GREEN}${CRON_SCHEDULE}${NC}"
        fi
    else
        echo -e "${RED}Configuration file not found!${NC}"
    fi
    echo ""
}

# Function to test notification
test_notification() {
    echo ""
    echo -e "${YELLOW}Testing Telegram notification...${NC}"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Configuration file not found!${NC}"
        return 1
    fi

    source "$CONFIG_FILE"

    TEST_MESSAGE="🔔 Test notification from $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
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
        fi
    else
        echo -e "${RED}Error: curl not found${NC}"
    fi
}

# Function to update scripts
update_scripts() {
    echo ""
    echo -e "${YELLOW}Updating scripts to latest version...${NC}"
    echo ""

    # Update notify.sh
    if command -v curl &> /dev/null; then
        curl -fsSL "${GITHUB_RAW_URL}/notify.sh" -o "${TEMP_DIR}/notify.sh"
        curl -fsSL "${GITHUB_RAW_URL}/report-failed-logins.sh" -o "${TEMP_DIR}/report-failed-logins.sh"
    elif command -v wget &> /dev/null; then
        wget -q -O "${TEMP_DIR}/notify.sh" "${GITHUB_RAW_URL}/notify.sh"
        wget -q -O "${TEMP_DIR}/report-failed-logins.sh" "${GITHUB_RAW_URL}/report-failed-logins.sh"
    else
        echo -e "${RED}Error: Neither curl nor wget found${NC}"
        return 1
    fi

    if [ -f "${TEMP_DIR}/notify.sh" ]; then
        # Backup old script
        if [ -f "${INSTALL_DIR}/${SCRIPT_NAME}" ]; then
            cp "${INSTALL_DIR}/${SCRIPT_NAME}" "${INSTALL_DIR}/${SCRIPT_NAME}.backup.$(date +%Y%m%d%H%M%S)"
        fi
        cp "${TEMP_DIR}/notify.sh" "${INSTALL_DIR}/${SCRIPT_NAME}"
        chmod 755 "${INSTALL_DIR}/${SCRIPT_NAME}"
        echo -e "${GREEN}✓${NC} notify.sh updated"
    fi

    if [ -f "${TEMP_DIR}/report-failed-logins.sh" ]; then
        # Backup old script
        if [ -f "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}" ]; then
            cp "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}" "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}.backup.$(date +%Y%m%d%H%M%S)"
        fi
        cp "${TEMP_DIR}/report-failed-logins.sh" "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}"
        chmod 755 "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}"
        echo -e "${GREEN}✓${NC} report-failed-logins.sh updated"
    fi

    echo ""
    echo -e "${GREEN}Scripts updated successfully!${NC}"
}

# Function to reconfigure
reconfigure() {
    echo ""
    echo -e "${YELLOW}Reconfiguring SSH Login Notifier...${NC}"
    echo ""

    # Load existing config
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi

    echo "Current Bot Token: ${TELEGRAM_BOT_TOKEN:0:10}..."
    read -p "Enter new Telegram Bot Token (or press Enter to keep current): " NEW_BOT_TOKEN
    if [ -z "$NEW_BOT_TOKEN" ]; then
        NEW_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
    fi

    echo ""
    echo "Current Chat ID: ${TELEGRAM_CHAT_ID}"
    read -p "Enter new Telegram Chat ID (or press Enter to keep current): " NEW_CHAT_ID
    if [ -z "$NEW_CHAT_ID" ]; then
        NEW_CHAT_ID="$TELEGRAM_CHAT_ID"
    fi

    echo ""
    echo "Current Server Name: ${SERVER_NAME:-$(hostname)}"
    read -p "Enter new server name (or press Enter to keep current): " NEW_SERVER_NAME
    if [ -z "$NEW_SERVER_NAME" ]; then
        NEW_SERVER_NAME="$SERVER_NAME"
    fi

    echo ""
    echo "Current Report Interval: ${REPORT_INTERVAL:-disabled}"
    echo ""
    echo "Select new report frequency:"
    echo "  1) Hourly (every hour)"
    echo "  2) Every 6 hours"
    echo "  3) Every 12 hours"
    echo "  4) Daily (once per day at 8:00 AM)"
    echo "  5) Disabled (no reports)"
    echo "  6) Keep current setting"
    echo ""
    read -p "Enter your choice [1-6]: " REPORT_CHOICE

    case "$REPORT_CHOICE" in
        1)
            NEW_REPORT_INTERVAL="hourly"
            NEW_CRON_SCHEDULE="0 * * * *"
            ;;
        2)
            NEW_REPORT_INTERVAL="6hours"
            NEW_CRON_SCHEDULE="0 */6 * * *"
            ;;
        3)
            NEW_REPORT_INTERVAL="12hours"
            NEW_CRON_SCHEDULE="0 */12 * * *"
            ;;
        4)
            NEW_REPORT_INTERVAL="daily"
            NEW_CRON_SCHEDULE="0 8 * * *"
            ;;
        5)
            NEW_REPORT_INTERVAL="disabled"
            NEW_CRON_SCHEDULE=""
            ;;
        *)
            NEW_REPORT_INTERVAL="$REPORT_INTERVAL"
            NEW_CRON_SCHEDULE=""
            ;;
    esac

    # Save new configuration
    cat > "$CONFIG_FILE" <<EOF
# Telegram Bot Configuration for SSH Login Notifier
# Updated on $(date)

# Your Telegram Bot Token from @BotFather
TELEGRAM_BOT_TOKEN="${NEW_BOT_TOKEN}"

# Your Telegram Chat ID (can be user ID or group ID)
TELEGRAM_CHAT_ID="${NEW_CHAT_ID}"

# Custom server name (optional)
# If not set, system hostname will be used
SERVER_NAME="${NEW_SERVER_NAME}"

# Failed login report interval
# Options: hourly, 6hours, 12hours, daily, disabled
REPORT_INTERVAL="${NEW_REPORT_INTERVAL}"
EOF

    chmod 600 "$CONFIG_FILE"

    # Update cron job if needed
    if [ ! -z "$NEW_CRON_SCHEDULE" ] && [ "$REPORT_CHOICE" != "6" ]; then
        # Remove old cron job
        crontab -l 2>/dev/null | grep -v "report-failed-logins.sh" | crontab -

        # Add new cron job
        CRON_LINE="${NEW_CRON_SCHEDULE} ${INSTALL_DIR}/${REPORT_SCRIPT_NAME}"
        (crontab -l 2>/dev/null; echo "# SSH Failed Login Report"; echo "$CRON_LINE") | crontab -
        echo ""
        echo -e "${GREEN}✓${NC} Cron job updated"
    elif [ "$NEW_REPORT_INTERVAL" = "disabled" ] && [ "$REPORT_CHOICE" != "6" ]; then
        # Remove cron job
        crontab -l 2>/dev/null | grep -v "report-failed-logins.sh" | crontab -
        echo ""
        echo -e "${GREEN}✓${NC} Cron job removed"
    fi

    echo ""
    echo -e "${GREEN}✓${NC} Configuration updated successfully!"
}

# Function to run failed login report
run_report() {
    echo ""
    echo -e "${YELLOW}Running failed login report...${NC}"
    echo ""

    if [ -f "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}" ]; then
        "${INSTALL_DIR}/${REPORT_SCRIPT_NAME}"
        echo ""
        echo -e "${GREEN}✓${NC} Report sent!"
    else
        echo -e "${RED}Error: Report script not found!${NC}"
        echo "Please update scripts first."
    fi
}

# Function to show management menu
show_menu() {
    while true; do
        echo ""
        echo -e "${GREEN}=====================================${NC}"
        echo -e "${GREEN}SSH Login Notifier - Management Menu${NC}"
        echo -e "${GREEN}=====================================${NC}"
        echo ""
        echo "  1) View current configuration"
        echo "  2) Update configuration"
        echo "  3) Update scripts to latest version"
        echo "  4) Test notification"
        echo "  5) Run failed login report now"
        echo "  6) Uninstall"
        echo "  0) Exit"
        echo ""
        read -p "Enter your choice [0-6]: " choice

        case $choice in
            1)
                show_config
                read -p "Press Enter to continue..."
                ;;
            2)
                reconfigure
                read -p "Press Enter to continue..."
                ;;
            3)
                update_scripts
                read -p "Press Enter to continue..."
                ;;
            4)
                test_notification
                read -p "Press Enter to continue..."
                ;;
            5)
                run_report
                read -p "Press Enter to continue..."
                ;;
            6)
                echo ""
                read -p "Are you sure you want to uninstall? (y/N): " confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    if command -v curl &> /dev/null; then
                        bash <(curl -fsSL "${GITHUB_RAW_URL}/uninstall.sh")
                    else
                        echo -e "${RED}Please run uninstall manually${NC}"
                    fi
                fi
                exit 0
                ;;
            0)
                echo ""
                echo -e "${GREEN}Goodbye!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
    done
}

# Function to perform initial installation
do_install() {
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}SSH Login Telegram Notifier Installer${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo ""

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
    echo "  4) Daily (once per day at 8:00 AM)"
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
    echo "To manage settings, run this installer again:"
    echo "  sudo bash <(curl -Ls ${GITHUB_RAW_URL}/install.sh)"
    echo ""
    echo "To test, try logging in via SSH from another terminal."
    echo ""
}

# Main logic
if check_installation; then
    # Already installed, show menu
    show_menu
else
    # Not installed, perform installation
    do_install
fi
