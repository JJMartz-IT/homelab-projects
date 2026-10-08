#!/bin/bash

OUTPUT="$HOME/security-audit/suid-current.txt"
BASELINE="$HOME/security-audit/suid-baseline-v2.txt"
LOG="$HOME/security-audit/suid-audit.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

print_header() {
    echo "===== SUID Security Audit ======"
    echo "Searching for SUID executables..."
}

run_scan() {
    if ! find /usr/bin /usr/sbin -perm -4000 -type f -exec stat -c "%a %A %U %G %n" {} \; 2>/dev/null > "$OUTPUT"
    then
        echo "ERROR: SUID scan failed."
        echo "$TIMESTAMP ERROR: SUID scan failed." >> "$LOG"
	exit 1
    fi
}

print_header

run_scan

SUID_COUNT=$(wc -l < "$OUTPUT")

echo "Audit Complete"
echo "Found $SUID_COUNT Suid executables"
echo "Results saved to: $OUTPUT"

compare_baseline() {
    diff -q "$BASELINE" "$OUTPUT" > /dev/null
    DIFF_STATUS=$?

    if [ "$DIFF_STATUS" -eq 0 ]
    then
        echo "PASS: No SUID changes detected."
        echo "$TIMESTAMP PASS: No SUID changes detected." >> "$LOG"
	return 0
    elif [ "$DIFF_STATUS" -eq 1 ]
    then
        echo "ALERT: SUID changes detected!"
        echo "$TIMESTAMP Alert: SUID changes detected!" >> "$LOG"
        echo "=====Changes====="
        diff "$BASELINE" "$OUTPUT"
	return 1
    else
        echo "ERROR: Unable to compare audit files."
        echo "$TIMESTAMP ERROR: Unable to compare audit files." >> "$LOG"
	return 2
    fi
}

compare_baseline 
exit $?
