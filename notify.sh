#!/bin/bash

#############################################
# SSH Login Telegram Notifier
#
# This script sends a Telegram notification
# when someone logs in via SSH
#############################################

# Configuration file location
CONFIG_FILE="/etc/ssh-login-notifier/config"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Load configuration
source "$CONFIG_FILE"

# Check if required variables are set
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set in config file"
    exit 1
fi

# Gather login information
LOGIN_USER="${PAM_USER:-$USER}"
LOGIN_IP="${PAM_RHOST:-Unknown}"
LOGIN_TIME=$(date '+%Y-%m-%d %H:%M:%S %Z')
LOGIN_SERVICE="${PAM_SERVICE:-ssh}"

# Use custom server name from config, or fallback to hostname
if [ ! -z "$SERVER_NAME" ]; then
    DISPLAY_SERVER="$SERVER_NAME"
else
    DISPLAY_SERVER=$(hostname)
fi

# Get geographic location info for the IP (optional, requires internet)
if command -v curl &> /dev/null && [ "$LOGIN_IP" != "Unknown" ] && [ "$LOGIN_IP" != "" ]; then
    GEO_INFO=$(curl -s "http://ip-api.com/json/${LOGIN_IP}?fields=country,regionName,city,isp" 2>/dev/null)
    if [ $? -eq 0 ] && [ ! -z "$GEO_INFO" ]; then
        COUNTRY=$(echo "$GEO_INFO" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        REGION=$(echo "$GEO_INFO" | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
        CITY=$(echo "$GEO_INFO" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
        ISP=$(echo "$GEO_INFO" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)

        if [ ! -z "$COUNTRY" ]; then
            LOCATION="${CITY}, ${REGION}, ${COUNTRY}"
            ISP_INFO="${ISP}"
        fi
    fi
fi

# Construct the message with enhanced header
MESSAGE="🚨 *SSH LOGIN DETECTED* 🚨

*Server:* \`${DISPLAY_SERVER}\`
*User:* \`${LOGIN_USER}\`
*IP Address:* \`${LOGIN_IP}\`"

if [ ! -z "$LOCATION" ]; then
    MESSAGE="${MESSAGE}
*Location:* ${LOCATION}"
fi

if [ ! -z "$ISP_INFO" ]; then
    MESSAGE="${MESSAGE}
*ISP:* ${ISP_INFO}"
fi

MESSAGE="${MESSAGE}
*Time:* \`${LOGIN_TIME}\`

✅ *Status:* Login Successful"

# URL encode the message for Telegram API
# Use printf and sed for encoding
MESSAGE_ENCODED=$(echo -n "$MESSAGE" | jq -sRr @uri 2>/dev/null || python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()))" 2>/dev/null || perl -MURI::Escape -e 'print uri_escape(<STDIN>)' 2>/dev/null)

# If all encoding methods fail, use the message as-is (may have issues with special characters)
if [ -z "$MESSAGE_ENCODED" ]; then
    MESSAGE_ENCODED="$MESSAGE"
fi

# Send to Telegram
TELEGRAM_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

# Try using curl first, then wget
if command -v curl &> /dev/null; then
    curl -s -X POST "$TELEGRAM_URL" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${MESSAGE_ENCODED}" \
        -d "parse_mode=Markdown" \
        -d "disable_web_page_preview=true" > /dev/null 2>&1
elif command -v wget &> /dev/null; then
    wget -q -O- --post-data "chat_id=${TELEGRAM_CHAT_ID}&text=${MESSAGE_ENCODED}&parse_mode=Markdown&disable_web_page_preview=true" \
        "$TELEGRAM_URL" > /dev/null 2>&1
else
    echo "Neither curl nor wget found. Cannot send notification."
    exit 1
fi

exit 0
