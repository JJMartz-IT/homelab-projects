# Automated Linux Disk Usage Monitor

## Project Overview

This project implements an automated disk usage monitoring
solution on Ubuntu Server using Bash and systemd.

The monitoring script checks filesystem utilization,
compares it against a configurable warning threshold,
and records timestamped results in a log file.

A systemd user timer schedules the script to execute
approximately every 15 minutes.

## Project Objectives

- Monitor root filesystem disk utilization.
- Detect usage exceeding a configurable threshold.
- Record PASS, WARNING, and ERROR events.
- Implement meaningful exit codes.
- Automate execution using systemd timers.
- Apply security hardening to the systemd service.
- Maintain the project using Git and GitHub.

## How the Bash Script Works

The monitoring script is located at `scripts/disk-monitor.sh`.

### 1. Configurable Warning Threshold

The script uses a default warning threshold of 80%. It also accepts a custom threshold through its first command-line argument.

Input validation ensures the threshold is a whole number between 1 and 100.

### 2. Disk Usage Collection

The script uses `df -P /` to retrieve disk utilization for the root filesystem.

The output is processed using `awk` to extract the percentage of disk space currently in use.

### 3. Conditional Monitoring

The script compares the current disk usage against the configured threshold.

- **PASS:** Disk usage is below the threshold.
- **WARNING:** Disk usage is greater than or equal to the threshold.
- **ERROR:** Invalid input, failure to determine disk usage, or logging failure.

### 4. Logging

The script records timestamped monitoring results in:

`~/security-audit/disk-monitor.log`

The `write_log()` Bash function handles writing log messages and detects logging failures.

### 5. Exit Codes

| Exit Code | Meaning |
|---|---|
| `0` | Disk usage is below the warning threshold |
| `1` | Disk usage has reached or exceeded the threshold |
| `2` | An error occurred during monitoring |

These exit codes allow systemd and other automation tools to determine the outcome of each execution.

## Systemd Automation

The disk monitoring script is automated using a systemd
user service and timer.

### Service Configuration

The service is stored at:

~/.config/systemd/user/disk-monitor.service

The service uses Type=oneshot because the monitoring script
performs a task and exits rather than running continuously.

The ExecStart directive executes the Bash monitoring script.

### Timer Configuration

The timer is stored at:

~/.config/systemd/user/disk-monitor.timer

The timer uses the following settings:

- OnBootSec=2min
- OnUnitActiveSec=15min
- Unit=disk-monitor.service

The timer automatically starts the monitoring service
at scheduled intervals.

### Security Hardening

The service uses several security controls:

- NoNewPrivileges=yes
  Prevents the process from gaining additional privileges.

- RestrictSUIDSGID=yes
  Restricts the creation of SUID and SGID files.

- UMask=0077
  Restricts permissions on newly created files.

These controls help reduce the service's attack surface
and protect monitoring logs.

## Testing and Verification

The disk monitoring solution was successfully configured
and tested on Ubuntu Server.

### Verified Functionality

- Disk usage detection returned accurate results.
- Configurable warning thresholds were implemented.
- Invalid input and logging errors were handled.
- PASS, WARNING, and ERROR exit codes were implemented.
- The systemd service executed successfully.
- The systemd timer was enabled and active.
- The timer displayed a valid upcoming execution time.
- Security hardening settings were applied and verified.
- Monitoring results were recorded in the log file.

### Project Status

Status: Operational

The monitoring script and systemd service have been tested
successfully. The recurring timer is enabled and scheduled
to execute the monitoring service automatically.

## Useful Commands

Check timer status:

    systemctl --user status disk-monitor.timer

List scheduled timers:

    systemctl --user list-timers --all

Check service logs:

    journalctl --user -u disk-monitor.service -n 20

View monitoring results:

    tail -n 10 ~/security-audit/disk-monitor.log
