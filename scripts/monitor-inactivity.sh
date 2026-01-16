#!/bin/bash
# Monitor LLM Provider inactivity and shutdown server to save costs
# Checks both API calls and WebUI access (excluding automatic polling)
# Uses boot time as minimum reference to avoid instant shutdown after reboot

# Config (INACTIVITY_TIMEOUT set via systemd Environment)
THRESHOLD_SECONDS=${INACTIVITY_TIMEOUT:-3600}
LOG_DIR="/opt/llm-provider/data/caddy"
API_LOG="$LOG_DIR/api-access.log"
WEBUI_LOG="$LOG_DIR/access.log"

# Patterns to EXCLUDE (automatic polling, bots, ACME challenges)
EXCLUDE_PATTERN='version\.json|\.well-known|robots\.txt|favicon|\.git'

# Get boot timestamp (minimum reference point)
BOOT_TS=$(date -d "$(uptime -s)" +%s)

# Get most recent timestamp from a log file, excluding noise
get_last_ts() {
    local file="$1"
    [ -f "$file" ] && tac "$file" | grep -v -E "$EXCLUDE_PATTERN" | grep -m1 '"ts":' | sed -n 's/.*"ts":\([0-9.]*\).*/\1/p' || true
}

# Get the most recent timestamp across all logs
LAST_API_TS=$(get_last_ts "$API_LOG")
LAST_WEBUI_TS=$(get_last_ts "$WEBUI_LOG")

# Find the most recent real activity
LOG_TS=""
if [ -n "$LAST_API_TS" ] && [ -n "$LAST_WEBUI_TS" ]; then
    if [ "${LAST_API_TS%.*}" -gt "${LAST_WEBUI_TS%.*}" ]; then
        LOG_TS="${LAST_API_TS%.*}"
    else
        LOG_TS="${LAST_WEBUI_TS%.*}"
    fi
elif [ -n "$LAST_API_TS" ]; then
    LOG_TS="${LAST_API_TS%.*}"
elif [ -n "$LAST_WEBUI_TS" ]; then
    LOG_TS="${LAST_WEBUI_TS%.*}"
fi

# Use the MORE RECENT of: boot time or last log activity
# This prevents instant shutdown after reboot (old logs would trigger shutdown)
if [ -n "$LOG_TS" ] && [ "$LOG_TS" -gt "$BOOT_TS" ]; then
    LAST_TS="$LOG_TS"
    echo "Reference: last activity in logs"
else
    LAST_TS="$BOOT_TS"
    echo "Reference: boot time (no recent activity or fresh boot)"
fi

# Calculate inactivity
NOW=$(date +%s)
INACTIVE=$((NOW - LAST_TS))
INACTIVE_MIN=$((INACTIVE / 60))
THRESHOLD_MIN=$((THRESHOLD_SECONDS / 60))

echo "[$(date '+%H:%M:%S')] Last activity: ${INACTIVE_MIN}m ago (threshold: ${THRESHOLD_MIN}m)"

# Shutdown if exceeded
if [ "$INACTIVE" -gt "$THRESHOLD_SECONDS" ]; then
    echo "SHUTDOWN: ${INACTIVE_MIN}m inactivity exceeds threshold"
    logger -t llm-shutdown "Auto-shutdown after ${INACTIVE_MIN}m idle"
    shutdown -h now
else
    REMAINING=$(( (THRESHOLD_SECONDS - INACTIVE) / 60 ))
    echo "Active. Shutdown in ${REMAINING}m if no activity"
fi
