#!/bin/bash

THRESHOLD=${1:-80}
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || (( 10#$THRESHOLD < 1 || 10#$THRESHOLD > 100 )); then
    echo "ERROR: Threshold must be a number between 1 and 100."
    exit 2
fi
LOG_DIR="$HOME/security-audit"
LOG_FILE="$LOG_DIR/disk-monitor.log"

if ! mkdir -p "$LOG_DIR"; then
    echo "ERROR: Could not create log directory: $LOG_DIR" >&2
    exit 2
fi

write_log() {
    local message="$1"

    if ! printf '%s\n' "$message" >> "$LOG_FILE"; then
        echo "ERROR: Failed to write to $LOG_FILE" >&2
        exit 2
    fi
}

USAGE=$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')

if ! [[ "$USAGE" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Could not determine disk usage."
    write_log "$(date '+%Y-%m-%d %H:%M:%S') | ERROR | Unable to determine disk usage"
    exit 2
fi

echo "Current disk usage: ${USAGE}%"
echo "Warning threshold: ${THRESHOLD}%"


if [ "$USAGE" -ge "$THRESHOLD" ]; then
    echo "WARNING: Disk usage is too high!"
    write_log "$(date '+%Y-%m-%d %H:%M:%S') | WARNING | Usage: ${USAGE}% | Threshold: ${THRESHOLD}%"
    exit 1
else
    echo "PASS: Disk usage is within safe limits."
    write_log "$(date '+%Y-%m-%d %H:%M:%S') | PASS | Usage: ${USAGE}% | Threshold: ${THRESHOLD}%"
    exit 0
fi

