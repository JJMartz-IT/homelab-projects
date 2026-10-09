#!/bin/bash

OUTPUT="$HOME/security-audit/suid-current.txt"
BASELINE="$HOME/security-audit/suid-baseline-v2.txt"
LOG="$HOME/security-audit/suid-audit.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

check_dependencies() {
    local cmd

    for cmd in find stat sort diff mktemp mv rm wc date
    do
	if ! command -v "$cmd" > /dev/null 2>&1
	then
	    echo "ERROR: Required command '$cmd' is missing."
	    echo "$TIMESTAMP ERROR: Missing dependency: $cmd" >> "$LOG"
	    exit 2
	fi
    done

    echo "Dependency checks passed."
}

print_header() {
    echo "===== SUID Security Audit ======"
    echo "Searching for SUID executables..."
}

run_scan() {
    local TEMP_FILE

    TEMP_FILE=$(mktemp "${OUTPUT}.XXXXXX") || {
	echo "ERROR: Could not create temporary file."
	echo "$TIMESTAMP ERROR: Could not create temporary file." >> "$LOG"
	exit 2
    }

    if ! find /usr/bin /usr/sbin -perm -4000 -type f \
	-exec stat -c "%a %A %U %G %n" {} + \
	> "$TEMP_FILE"
    then
        echo "ERROR: SUID scan failed."
        echo "$TIMESTAMP ERROR: SUID scan failed." >> "$LOG"
	rm -f -- "$TEMP_FILE"
	exit 2
    fi
    if ! LC_ALL=C sort -o "$TEMP_FILE" "$TEMP_FILE"
    then
	echo "ERROR: Could not sort audit results."
	echo "$TIMESTAMP ERROR: Could not sort audit results." >> "$LOG"
	rm -f -- "$TEMP_FILE"
	exit 2
    fi

    if ! mv -- "$TEMP_FILE" "$OUTPUT"
    then
	echo "ERROR: Could not save audit report."
	echo "$TIMESTAMP ERROR: Could not save audit report." >> "$LOG"
	rm -f -- "$TEMP_FILE"
	exit 2
    fi
}

check_dependencies

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
