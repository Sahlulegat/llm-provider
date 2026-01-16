#!/bin/bash
# Monitor Ollama API inactivity and shutdown server to save costs

# Config
THRESHOLD_SECONDS=3600  # 1 hour
LOG_FILE="/opt/llm-provider/data/caddy/api-access.log"

# Check log exists
if [ ! -f "$LOG_FILE" ]; then
    echo "No log file yet, skipping"
    exit 0
fi

# Find last Ollama API request timestamp (|| true prevents grep exit 1 when no match)
LAST_TS=$(tac "$LOG_FILE" | grep -E '"/api/(generate|chat|embeddings|pull)"' | head -1 | sed -n 's/.*"ts":\([0-9.]*\).*/\1/p' || true)

# No requests found
if [ -z "$LAST_TS" ]; then
    echo "No API requests found in logs, skipping shutdown"
    exit 0
fi

# Calculate inactivity
NOW=$(date +%s)
LAST=${LAST_TS%.*}  # Remove decimals
INACTIVE=$((NOW - LAST))
INACTIVE_MIN=$((INACTIVE / 60))

echo "[$(date '+%H:%M:%S')] Last request: ${INACTIVE_MIN}m ago (threshold: $((THRESHOLD_SECONDS/60))m)"

# Shutdown if exceeded
if [ "$INACTIVE" -gt "$THRESHOLD_SECONDS" ]; then
    echo "SHUTDOWN: ${INACTIVE_MIN}m inactivity exceeds threshold"
    logger -t llm-shutdown "Auto-shutdown after ${INACTIVE_MIN}m idle"
    shutdown -h now
else
    REMAINING=$(( (THRESHOLD_SECONDS - INACTIVE) / 60 ))
    echo "Active. Shutdown in ${REMAINING}m if no activity"
fi
