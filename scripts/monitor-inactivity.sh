#!/bin/bash
# Monitor LLM Provider inactivity and shutdown server to save costs
# Checks both API calls and WebUI access (excluding automatic polling)
# If no real activity, uses boot time as reference

# Config (INACTIVITY_TIMEOUT set via systemd Environment)
THRESHOLD_SECONDS=${INACTIVITY_TIMEOUT:-3600}
LOG_DIR="/opt/llm-provider/data/caddy"
API_LOG="$LOG_DIR/api-access.log"
WEBUI_LOG="$LOG_DIR/access.log"

# Patterns to EXCLUDE (automatic polling, bots, ACME challenges)
EXCLUDE_PATTERN='version\.json|\.well-known|robots\.txt|favicon|\.git'

# Get most recent timestamp from a log file, excluding noise
get_last_ts() {
    local file="$1"
    [ -f "$file" ] && tac "$file" | grep -v -E "$EXCLUDE_PATTERN" | grep -m1 '"ts":' | sed -n 's/.*"ts":\([0-9.]*\).*/\1/p' || true
}

# Get the most recent timestamp across all logs
LAST_API_TS=$(get_last_ts "$API_LOG")
LAST_WEBUI_TS=$(get_last_ts "$WEBUI_LOG")

# Find the most recent real activity
LAST_TS=""
if [ -n "$LAST_API_TS" ] && [ -n "$LAST_WEBUI_TS" ]; then
    if [ "${LAST_API_TS%.*}" -gt "${LAST_WEBUI_TS%.*}" ]; then
        LAST_TS="$LAST_API_TS"
    else
        LAST_TS="$LAST_WEBUI_TS"
    fi
elif [ -n "$LAST_API_TS" ]; then
    LAST_TS="$LAST_API_TS"
elif [ -n "$LAST_WEBUI_TS" ]; then
    LAST_TS="$LAST_WEBUI_TS"
fi

# If no real activity in logs, use boot time as reference
if [ -z "$LAST_TS" ]; then
    BOOT_TS=$(date -d "$(uptime -s)" +%s)
    LAST_TS="$BOOT_TS"
    echo "No real activity in logs, using boot time as reference"
fi

# Calculate inactivity
NOW=$(date +%s)
LAST=${LAST_TS%.*}
INACTIVE=$((NOW - LAST))
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
