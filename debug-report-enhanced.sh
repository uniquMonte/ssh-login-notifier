#!/bin/bash

echo "=== SSH 失败登录检测调试工具 ==="
echo ""

# 配置
HOURS_AGO=6
CONFIG_FILE="/etc/ssh-login-notifier/config"

# 加载配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "✓ 配置文件已加载"
    echo "  SERVER_NAME: ${SERVER_NAME:-未设置}"
    echo "  REPORT_INTERVAL: ${REPORT_INTERVAL:-未设置}"
else
    echo "✗ 配置文件不存在: $CONFIG_FILE"
fi

echo ""
echo "=== 系统信息 ==="
echo "  操作系统: $(uname -s)"
echo "  发行版: $(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME" | cut -d'"' -f2 || echo "未知")"
echo "  是否有 journalctl: $(command -v journalctl &> /dev/null && echo "是" || echo "否")"

echo ""
echo "=== 步骤1: 检查传统日志文件 ==="
POSSIBLE_LOGS=(
    "/var/log/auth.log"
    "/var/log/secure"
    "/var/log/syslog"
    "/var/log/messages"
)

for log in "${POSSIBLE_LOGS[@]}"; do
    if [ -f "$log" ]; then
        HAS_SSH=$(grep -c "sshd\|ssh" "$log" 2>/dev/null || echo 0)
        echo "  ✓ $log 存在 (SSH相关行数: $HAS_SSH)"
        if [ "$HAS_SSH" -gt 0 ]; then
            TRADITIONAL_LOG="$log"
        fi
    else
        echo "  ✗ $log 不存在"
    fi
done

echo ""
echo "=== 步骤2: 测试 journalctl 方法 ==="

if command -v journalctl &> /dev/null; then
    # 测试多种 journalctl 方法
    echo ""
    echo "方法1: journalctl -u sshd --since '$HOURS_AGO hours ago'"
    TEMP1=$(mktemp)
    journalctl -u sshd --since "$HOURS_AGO hours ago" 2>/dev/null > "$TEMP1"
    LINES1=$(wc -l < "$TEMP1")
    echo "  总行数: $LINES1"
    if [ "$LINES1" -gt 0 ]; then
        echo "  前3行:"
        head -3 "$TEMP1" | sed 's/^/    /'
    fi

    echo ""
    echo "方法2: journalctl -u ssh --since '$HOURS_AGO hours ago'"
    TEMP2=$(mktemp)
    journalctl -u ssh --since "$HOURS_AGO hours ago" 2>/dev/null > "$TEMP2"
    LINES2=$(wc -l < "$TEMP2")
    echo "  总行数: $LINES2"
    if [ "$LINES2" -gt 0 ]; then
        echo "  前3行:"
        head -3 "$TEMP2" | sed 's/^/    /'
    fi

    echo ""
    echo "方法3: journalctl --since '$HOURS_AGO hours ago' | grep sshd"
    TEMP3=$(mktemp)
    journalctl --since "$HOURS_AGO hours ago" 2>/dev/null | grep -i sshd > "$TEMP3"
    LINES3=$(wc -l < "$TEMP3")
    echo "  总行数: $LINES3"
    if [ "$LINES3" -gt 0 ]; then
        echo "  前3行:"
        head -3 "$TEMP3" | sed 's/^/    /'
    fi

    echo ""
    echo "方法4: journalctl _COMM=sshd --since '$HOURS_AGO hours ago'"
    TEMP4=$(mktemp)
    journalctl _COMM=sshd --since "$HOURS_AGO hours ago" 2>/dev/null > "$TEMP4"
    LINES4=$(wc -l < "$TEMP4")
    echo "  总行数: $LINES4"
    if [ "$LINES4" -gt 0 ]; then
        echo "  前3行:"
        head -3 "$TEMP4" | sed 's/^/    /'
    fi

    # 选择最好的方法
    if [ "$LINES4" -gt 0 ]; then
        JOURNAL_LOG="$TEMP4"
        JOURNAL_METHOD="方法4 (_COMM=sshd)"
    elif [ "$LINES1" -gt 0 ]; then
        JOURNAL_LOG="$TEMP1"
        JOURNAL_METHOD="方法1 (-u sshd)"
    elif [ "$LINES2" -gt 0 ]; then
        JOURNAL_LOG="$TEMP2"
        JOURNAL_METHOD="方法2 (-u ssh)"
    elif [ "$LINES3" -gt 0 ]; then
        JOURNAL_LOG="$TEMP3"
        JOURNAL_METHOD="方法3 (grep sshd)"
    fi

    if [ ! -z "$JOURNAL_LOG" ]; then
        echo ""
        echo "  → 选择: $JOURNAL_METHOD"
    fi
else
    echo "  journalctl 不可用"
fi

echo ""
echo "=== 步骤3: 选择最佳日志源 ==="
if [ ! -z "$JOURNAL_LOG" ]; then
    LOG_FILE="$JOURNAL_LOG"
    LOG_SOURCE="journalctl ($JOURNAL_METHOD)"
    USING_JOURNALCTL=1
elif [ ! -z "$TRADITIONAL_LOG" ]; then
    LOG_FILE="$TRADITIONAL_LOG"
    LOG_SOURCE="传统日志文件 ($TRADITIONAL_LOG)"
    USING_JOURNALCTL=0
else
    echo "  ✗ 无法找到任何有效的日志源"
    exit 1
fi

echo "  使用日志源: $LOG_SOURCE"
echo "  日志总行数: $(wc -l < "$LOG_FILE")"

echo ""
echo "=== 步骤4: 测试失败登录匹配模式 ==="

# 测试多种匹配模式
declare -A PATTERNS=(
    ["Failed password"]="Failed password"
    ["Invalid user"]="Invalid user"
    ["authentication failure"]="authentication failure"
    ["Connection closed by authenticating user"]="Connection closed by authenticating user"
    ["Disconnected from authenticating user"]="Disconnected from authenticating user"
    ["Failed publickey"]="Failed publickey"
    ["Connection reset by"]="Connection reset by"
)

FAILED_TEMP=$(mktemp)
> "$FAILED_TEMP"  # 清空文件

for name in "${!PATTERNS[@]}"; do
    pattern="${PATTERNS[$name]}"
    count=$(grep -c "$pattern" "$LOG_FILE" 2>/dev/null || echo 0)
    echo "  模式 '$name': $count 次"

    if [ "$count" -gt 0 ]; then
        grep "$pattern" "$LOG_FILE" >> "$FAILED_TEMP"
    fi
done

# 去重
sort -u "$FAILED_TEMP" > "${FAILED_TEMP}.uniq"
mv "${FAILED_TEMP}.uniq" "$FAILED_TEMP"

TOTAL=$(wc -l < "$FAILED_TEMP")
echo ""
echo "  失败登录总数（去重后）: $TOTAL"

if [ "$TOTAL" -gt 0 ]; then
    echo ""
    echo "=== 失败登录详情 ==="
    echo ""
    echo "前10条失败记录:"
    head -10 "$FAILED_TEMP" | sed 's/^/  /'

    echo ""
    echo "=== IP 地址统计（Top 5）==="
    grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$FAILED_TEMP" | sort | uniq -c | sort -rn | head -5 | sed 's/^/  /'

    echo ""
    echo "=== 用户名统计（Top 5）==="
    # 改进的用户名提取
    grep -oE "(Failed password for (invalid user )?|Invalid user |authentication failure.*user=)([a-zA-Z0-9_-]+)" "$FAILED_TEMP" | \
        awk '{print $NF}' | sort | uniq -c | sort -rn | head -5 | sed 's/^/  /'
else
    echo ""
    echo "  ✗ 没有找到失败记录"

    echo ""
    echo "=== 原始日志示例（最后20行）==="
    tail -20 "$LOG_FILE" | sed 's/^/  /'
fi

# 清理
rm -f "$TEMP1" "$TEMP2" "$TEMP3" "$TEMP4" "$FAILED_TEMP"
[ "$USING_JOURNALCTL" = "1" ] && rm -f "$JOURNAL_LOG"

echo ""
echo "=== 调试完成 ==="
