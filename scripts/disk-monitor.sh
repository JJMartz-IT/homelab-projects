#!/bin/bash

THRESHOLD=80
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

