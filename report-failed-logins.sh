#!/bin/bash

#############################################
# SSH Failed Login Report Generator
#
# This script analyzes SSH login failures
# and sends a summary report to Telegram
#############################################

# Configuration file location
CONFIG_FILE="/etc/ssh-login-notifier/config"
STATE_FILE="/var/tmp/ssh-failed-logins-last-check"

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

# Determine server name
if [ ! -z "$SERVER_NAME" ]; then
    DISPLAY_SERVER="$SERVER_NAME"
else
    DISPLAY_SERVER=$(hostname)
fi

# Determine report period from config (default to hourly)
REPORT_INTERVAL="${REPORT_INTERVAL:-hourly}"

# Calculate time range based on report interval
case "$REPORT_INTERVAL" in
    "hourly")
        PERIOD_TEXT="Past Hour"
        HOURS_AGO=1
        ;;
    "6hours")
        PERIOD_TEXT="Past 6 Hours"
        HOURS_AGO=6
        ;;
    "12hours")
        PERIOD_TEXT="Past 12 Hours"
        HOURS_AGO=12
        ;;
    "daily")
        PERIOD_TEXT="Past 24 Hours"
        HOURS_AGO=24
        ;;
    *)
        PERIOD_TEXT="Past Hour"
        HOURS_AGO=1
        ;;
esac

# Get timestamp for the start of the period
if command -v date &> /dev/null; then
    if date --version &> /dev/null 2>&1; then
        # GNU date
        START_TIME=$(date -d "$HOURS_AGO hours ago" '+%b %_d %H:%M')
    else
        # BSD date (macOS)
        START_TIME=$(date -v-${HOURS_AGO}H '+%b %_d %H:%M')
    fi
else
    echo "date command not found"
    exit 1
fi

# Detect log file location
# Priority: journalctl (has native time filtering) > traditional log files
LOG_FILE=""
USING_JOURNALCTL=0

# Try journalctl first (systemd systems with native --since time filtering)
if command -v journalctl &> /dev/null; then
    # Create a temporary file for journalctl output
    JOURNAL_TEMP=$(mktemp)

    # Try multiple approaches to get SSH logs from journalctl
    # Method 1: Using _COMM field (most reliable for sshd)
    journalctl _COMM=sshd --since "$HOURS_AGO hours ago" 2>/dev/null > "$JOURNAL_TEMP"

    # Method 2: If empty, try with -u sshd
    if [ ! -s "$JOURNAL_TEMP" ] || grep -q "^-- No entries --$" "$JOURNAL_TEMP"; then
        journalctl -u sshd --since "$HOURS_AGO hours ago" 2>/dev/null | grep -v "^-- No entries --$" > "$JOURNAL_TEMP"
    fi

    # Method 3: If still empty, try with -u ssh
    if [ ! -s "$JOURNAL_TEMP" ] || grep -q "^-- No entries --$" "$JOURNAL_TEMP"; then
        journalctl -u ssh --since "$HOURS_AGO hours ago" 2>/dev/null | grep -v "^-- No entries --$" > "$JOURNAL_TEMP"
    fi

    # Method 4: Last resort - search all logs for sshd
    if [ ! -s "$JOURNAL_TEMP" ] || grep -q "^-- No entries --$" "$JOURNAL_TEMP"; then
        journalctl --since "$HOURS_AGO hours ago" 2>/dev/null | grep -i sshd > "$JOURNAL_TEMP"
    fi

    # Verify we have actual log entries (not just "No entries")
    if [ -s "$JOURNAL_TEMP" ] && ! grep -q "^-- No entries --$" "$JOURNAL_TEMP"; then
        LOG_FILE="$JOURNAL_TEMP"
        USING_JOURNALCTL=1
    else
        rm -f "$JOURNAL_TEMP"
    fi
fi

# Fallback to traditional log files only if journalctl failed
if [ -z "$LOG_FILE" ]; then
    POSSIBLE_LOGS=(
        "/var/log/auth.log"
        "/var/log/secure"
        "/var/log/syslog"
        "/var/log/messages"
    )

    for log in "${POSSIBLE_LOGS[@]}"; do
        if [ -f "$log" ]; then
            # Check if the log contains SSH-related entries
            if grep -q "sshd\|ssh" "$log" 2>/dev/null; then
                LOG_FILE="$log"
                USING_JOURNALCTL=0
                break
            fi
        fi
    done
fi

if [ -z "$LOG_FILE" ]; then
    echo "SSH log file not found. Tried:"
    echo "  - /var/log/auth.log"
    echo "  - /var/log/secure"
    echo "  - /var/log/syslog"
    echo "  - /var/log/messages"
    echo "  - journalctl -u sshd"
    exit 1
fi

# Extract failed login attempts from the log
# Look for various failure patterns
FAILED_TEMP=$(mktemp)

# Comprehensive failure patterns
FAILURE_PATTERNS="(Failed password|Invalid user|authentication failure|Failed publickey|Connection closed by authenticating user|Disconnected from authenticating user|maximum authentication attempts|Connection reset by|Did not receive identification string)"

# If using journalctl, logs are already time-filtered by --since
# If using log files, we need to filter by time
if [ "$USING_JOURNALCTL" = "1" ]; then
    # Journalctl already filtered by time, just extract failed attempts
    grep -E "$FAILURE_PATTERNS" "$LOG_FILE" > "$FAILED_TEMP"
else
    # For log files, filter by time using awk
    grep -E "$FAILURE_PATTERNS" "$LOG_FILE" | \
        awk -v start="$START_TIME" '
        $0 ~ start {flag=1}
        flag {print}
        ' > "$FAILED_TEMP"
fi

# Count total failed attempts
TOTAL_FAILURES=$(wc -l < "$FAILED_TEMP")

# If no failures, send a simple message
if [ "$TOTAL_FAILURES" -eq 0 ]; then
    MESSAGE="✅ *SSH Security Report*

*Server:* \`${DISPLAY_SERVER}\`
*Period:* ${PERIOD_TEXT}
*Status:* No failed login attempts

Your server is secure! 🛡️"
else
    # Extract and count unique IPs
    IP_STATS=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$FAILED_TEMP" | \
        sort | uniq -c | sort -rn)

    UNIQUE_IPS=$(echo "$IP_STATS" | wc -l)

    # Extract usernames
    USER_STATS=$(grep -oE "(Failed password for (invalid user )?|Invalid user )([a-zA-Z0-9_-]+)" "$FAILED_TEMP" | \
        awk '{print $NF}' | sort | uniq -c | sort -rn)

    # Build Top 5 Attackers list
    TOP_ATTACKERS=""
    COUNT=0
    while IFS= read -r line; do
        if [ $COUNT -ge 5 ]; then
            break
        fi

        ATTEMPTS=$(echo "$line" | awk '{print $1}')
        IP=$(echo "$line" | awk '{print $2}')

        # Get geographic location for the IP
        LOCATION="Unknown"
        if command -v curl &> /dev/null; then
            GEO_INFO=$(curl -s --max-time 2 "http://ip-api.com/json/${IP}?fields=country" 2>/dev/null)
            if [ $? -eq 0 ] && [ ! -z "$GEO_INFO" ]; then
                COUNTRY=$(echo "$GEO_INFO" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
                if [ ! -z "$COUNTRY" ]; then
                    LOCATION="$COUNTRY"
                fi
            fi
        fi

        COUNT=$((COUNT + 1))
        TOP_ATTACKERS="${TOP_ATTACKERS}${COUNT}. \`${IP}\` (${ATTEMPTS} attempts) - ${LOCATION}
"
    done <<< "$IP_STATS"

    # Build Top Users list
    TOP_USERS=""
    COUNT=0
    while IFS= read -r line; do
        if [ $COUNT -ge 5 ]; then
            break
        fi

        ATTEMPTS=$(echo "$line" | awk '{print $1}')
        USERNAME=$(echo "$line" | awk '{print $2}')

        COUNT=$((COUNT + 1))
        TOP_USERS="${TOP_USERS}- \`${USERNAME}\`: ${ATTEMPTS} attempts
"
    done <<< "$USER_STATS"

    # Construct the report message
    MESSAGE="📊 *SSH Failed Login Report*

*Server:* \`${DISPLAY_SERVER}\`
*Period:* ${PERIOD_TEXT}

*Total Failed Attempts:* ${TOTAL_FAILURES}
*Unique IPs:* ${UNIQUE_IPS}

*Top Attackers:*
${TOP_ATTACKERS}
*Most Targeted Users:*
${TOP_USERS}
⚠️ Consider blocking persistent attackers!"
fi

# Clean up temp files
rm -f "$FAILED_TEMP"

# Clean up journalctl temp file if used
if [ "$USING_JOURNALCTL" = "1" ] && [ -f "$LOG_FILE" ]; then
    rm -f "$LOG_FILE"
fi

# URL encode the message
MESSAGE_ENCODED=$(echo -n "$MESSAGE" | jq -sRr @uri 2>/dev/null || python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()))" 2>/dev/null || perl -MURI::Escape -e 'print uri_escape(<STDIN>)' 2>/dev/null)

if [ -z "$MESSAGE_ENCODED" ]; then
    MESSAGE_ENCODED="$MESSAGE"
fi

# Send to Telegram
TELEGRAM_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

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
