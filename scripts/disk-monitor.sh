#!/bin/bash

THRESHOLD=${1:-80}
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || (( 10#$THRESHOLD < 1 || 10#$THRESHOLD > 100 )); then
    echo "ERROR: Threshold must be a number between 1 and 100."
    exit 2
fi
LOG_DIR="$HOME/security-audit"
LOG_FILE="$LOG_DIR/disk-monitor.log"

mkdir -p "$LOG_DIR"

USAGE=$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')

if ! [[ "$USAGE" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Could not determine disk usage."
    echo "$(date '+%Y-%m-%d %H:%M:%S') | ERROR | Unable to determine disk usage" >> "$LOG_FILE"
    exit 2
fi

echo "Current disk usage: ${USAGE}%"
echo "Warning threshold: ${THRESHOLD}%"


if [ "$USAGE" -ge "$THRESHOLD" ]; then
    echo "WARNING: Disk usage is too high!"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | WARNING | Usage: ${USAGE}% | Threshold: ${THRESHOLD}%" >> "$LOG_FILE"
    exit 1
else
    echo "PASS: Disk usage is within safe limits."
    echo "$(date '+%Y-%m-%d %H:%M:%S') | PASS | Usage: ${USAGE}% | Threshold: ${THRESHOLD}%" >> "$LOG_FILE"
    exit 0
fi

