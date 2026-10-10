# Automated SUID Security Audit

## Project Overview

This project implements an automated security auditing solution on an Ubuntu Linux server.

The solution uses a Bash script to identify SUID executables, compare the results against an established security baseline, and report unexpected changes.

A systemd user service and timer automate the audit on a daily schedule.

## Project Objectives

- Identify SUID executables on the system.
- Establish and maintain a security baseline.
- Detect changes in priviledged executables.
- Record audit results and errors in logs.
- Prevent overlapping audit executables using file locking
- Automate security checks using systemd.
- Track scripts and configuration files using Git.

## Technologies Used

- Ubuntu Linux
- Bash scripting
- GNU coreutils
- systemd services and timers
- Git and Github

## How the Audit Works

The SUID security audit follos these steps:

1. **Dependency validation:** Checks that required Linux commands are available before running the audit.

2. **File locking:** Uses 'flock' to prevent multiple audit processes from running at the same time.

3. **SUID discovery:** Searches the configured system directories for files with the SUID permission bit enables.

4. **Metadata collection:** Records file permissions, ownership, and paths using 'stat'.

5. **Result sorting:** Sorts audit results to ensure that differences in file discovery order do not trigger false alerts.

6. **Baseline comparison:** Compares the current audit results against a previously established baseline using 'diff'.

7. **Status reporting:** Reports whether the audit passed, detected changes, or encountered an error.

8. **Logging:** Records audit outcomes in a timestamped log file.

9. **Automation:** A systemd user timer schedules the audit to run daily.

## Exit Codes

| Exit Code | Meaning |
|-----------|---------|
| 0 | Audit completed successfully; no changes detected |
| 1 | Differences detected between the baseline and current scan |
| 2 | Audit encountered an error |

These exit codes allow administrators and automation tools to distinguish between normal resilts, security alerts, and execution failures.


## Testing and Validation

The SUID audit was tested under normal and simulated failure conditions.


### Test 1: Successful Audit

**Objective:** Verify that the script correctly identifies SUID executables and compares them against the baseline.

**Procedure:**
- Execute the audit script.
- Confirm that the current results match the baseline.
- Check the exit status using 'echo $?'.

**Results:** PASS. The audit identifies SUID executables and returned exit code 0.


### Test 2: Simulated Security Change

**Objective:** Verify that the script detects unexpected changes.

**Procedure:** 
- Add a fictional SUID entry to a test baseline.
- Execute the audit.
- Inspect the differences reported by 'diff'.
- Restore the original baseline.

**Results:** PASS. The script detected the difference and returned the exit code 1.


### Test 3: Missing Dependency 

**Objective:** Verify that required command checks work.

**Procedure:**
- Create a temporary copy of the script.
- Add a nonexistent command to the dependency checks.
- Execute the temporary script.
- Inspect the error message and audit log.

**Result:** PASS. The script reported the missing dependency.


### Test 4: Scan Failure

**Objective:** Verify that scan failures are handled correctly.

**Procedure:**
- Create a temporary copy of the script.
- Configure an invalid scan directory.
- Execute the temporary script.
- Check the exit status.


### Test 5: Report Preservation

**Objective:** Verify that a failed scan does not overwrite the previous valid report.

**Procedure:**
- Generate a successful audit report.
- Simulate a scan failure using a temporary script.
- Inspect the original report afterward.

**Result:** PASS. The previous report remained intact.


### Test 6: systemd Automation

**Objective:** Verify that the audit can execute through systemd.

**Procedure:** 
- Create a systemd user service and timer.
- Validate the unit files.
- Start the service manually.
- Inspect execution logs using 'journalctl'.
- Enable the daily timer.

**Result:** PASS. The service executed successfully, and the timer was enabled and active.

## Running the Audit

Run the audit manually:

```bash
bash scripts/suid-audit.sh
```

Check the exit code immediately afterward:

```bash
echo $?
```

View the latest audit results:

```bash
cat ~/security-audit/suid-current.txt
```

View recent audit log entries:

```bash
tail -n 20 ~/security-audit/suid-audit.log
```

## Managing the Automation

Start an audit manually through systemd:

```bash
systemctl --user start suid-audit.service
```

Check the daily timer:

```bash
systemctl --user list-timers --all
```

View service execution logs:

```bash
journalctl --user -u suid-audit.service -n 20 --no-pager
```

## Limitations and Security Considerations

- The audit detects changes against an established baseline; it does not determine whether an executable is malicious.
- Baseline changes should be reviewed before being accepted.
- The audit scans configured directories, not necessarily every filesystem.
- The systemd user service runs with the permissions of the account that owns it.
- The configured paths are specific to this homelab and must be adjusted on another server.
- A scheduled audit does not replace operating system updates or other security monitoring tools.

## Skills Demonstrated

- Linux file permission and SUID auditing
- Bash scripting and error handling
- Security baseline monitoring
- File locking and process coordination
- systemd service and timer configuration
- Log analysis and troubleshooting
- Git version control
- Technical documentation
