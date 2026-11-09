# Python Service Monitor and Incident Lab

I built a Python monitor on an Ubuntu Server VM that checks an HTTP endpoint and records failures and recovery. I tested it by removing the endpoint’s file and then stopping the web server. The two failures produced different evidence, which helped me decide where to investigate.

## Lab environment

| Component | Configuration |
|---|---|
| Virtualization | Ubuntu Server VM 100 on Proxmox VE |
| Practice service | Python’s built-in HTTP server bound to `127.0.0.1:8765` |
| Health check | GET `/health.txt`, with HTTP `200` treated as healthy |
| Monitor | Python 3 standard library, a two-second network timeout, and a 30-second pause after each check |
| Runtime | Two independent systemd services running as the `incident-lab` service account |
| Evidence | UTC timestamps in `journalctl`, HTTP responses from `curl`, and listening sockets from `ss` |

## How it works

- **`probe.py` checks once.** It returns a Boolean and a diagnostic message. It keeps HTTP error codes separate from connection errors, so a `404` and a refused connection produce different messages.
- **`monitor.py` repeats the check.** It stores the previous result and prints one timestamped line per check. The first success after a failed check is labeled `RECOVERED`.
- **systemd runs the two processes independently.** `incident-lab-site.service` serves the file. `incident-lab-monitor.service` runs the probe loop and restarts the monitor process on failure. I can stop the website while the monitor continues checking it.

## Validation

I confirmed the following results on VM 100.

| Test | Result | How I verified it |
|---|---|---|
| Request the health file with the site running | `UP` with `HTTP 200` | `curl` showed `200 OK` and the body `ok`. |
| Rename `health.txt` while the server runs | `DOWN` with `HTTP 404` | `curl` showed the HTTP error and `ss` showed that TCP port `8765` was still listening. Restoring the filename returned the probe to `UP`. |
| Stop the practice HTTP server | `DOWN` with `Connection refused` | `ss` showed no listener on `8765`. Restarting the server made the endpoint reachable again. |
| Stop and start the site’s systemd unit with the monitor running | The journal recorded `UP → DOWN → RECOVERED`. | I checked the listener during the outage and confirmed `200 OK` after starting the site. Both units reported `active` and `enabled` after the drill. |

Representative journal output for the service-stop drill, with placeholders for the UTC timestamps.

```text
<UTC timestamp> | UP | HTTP 200
<UTC timestamp> | DOWN | Connection problem ([Errno 111] Connection refused)
<UTC timestamp> | RECOVERED | HTTP 200
```

The journal shows when the monitor **observed** each change. A short outage between checks can go undetected, so the polling interval matters when interpreting the timeline.

### Proxmox setup issue

The initial `pct enter 100` attempt failed. I checked the guest type with `qm status 100`, which returned `status: running`, and `pct status 100`, which reported a missing `lxc/100.conf`. That confirmed guest 100 was a VM. The lab runs from an Ubuntu shell reached through **VM 100 → Console** or SSH. [Proxmox VM commands](https://github.com/proxmox/pve-docs/blob/master/generated/qm.1-synopsis.adoc) · [Proxmox container commands](https://github.com/proxmox/pve-docs/blob/master/pct.adoc#managing-containers-with-pct)

## IT certification connections

| Certification | Related topic | What I practiced in this lab |
|---|---|---|
| **PCEP · Certified Entry-Level Python Programmer** | Functions, control flow, tuples, imports, and exception handling | Wrote a reusable check function, returned and unpacked a pair of values, handled specific errors, and tracked the previous result in a loop. [Python Institute exam syllabus](https://pythoninstitute.org/pcep-exam-syllabus) |
| **CompTIA Linux+** | Service and account management, monitoring, and troubleshooting | Created and verified systemd units, ran them as a dedicated service account, and used `systemctl` and `journalctl` to examine behavior. [XK0-006 exam objectives (copy)](https://studylib.net/doc/28037951/comptia-linux--xk0-006-exam-objectives--5.0-) |
| **CompTIA Network+** | Network protocols, ports, and troubleshooting | Used `curl` to check the HTTP response and `ss` to verify the TCP listener. The combination helped distinguish an HTTP path issue from a connection failure. [N10-009 exam objectives](https://comptiacdn.azureedge.net/webcontent/docs/default-source/exam-objectives/comptia-network-n10-009-exam-objectives-%284-0%29-%281%29.pdf) |
| **CompTIA Security+** | Incident response and using logs to support an investigation | Simulated an availability incident, used logs and socket evidence to analyze it, and verified restoration before closing the drill. [SY0-701 exam objectives](https://comptiacdn.azureedge.net/webcontent/docs/default-source/exam-objectives/comptia-security-sy0-701-exam-objectives-%286-0%29.pdf?sfvrsn=204179cc_6) |

## How this applies in an enterprise

The same check can be used for **synthetic monitoring**, which means making a test request to see whether a service responds as a client would. For example, an operations team could check an internal ticketing API during a rollout and continue polling it afterward. A failure is a signal to investigate. The team can compare it with deployment history, application logs, and host or network metrics to find the cause. [Google SRE on monitoring and distinguishing symptoms from causes](https://sre.google/sre-book/monitoring-distributed-systems/)

| Area | Lab design | Enterprise adaptation |
|---|---|---|
| Where the check runs | Probe and website share one VM and use loopback. | Run the probe on a separate monitoring host on a network that uses the service. This can reveal problems with the application host, DNS, or load balancer along the client path. |
| What counts as healthy | The static health file returns HTTP `200`. | Use a read-only HTTPS endpoint and define what success means for the service. Check status and latency, and validate a small response when the status alone gives too little information. |
| Where results go | UTC entries in the VM’s journal. | Collect status, response time, and failure category centrally. Tag results with the service and probe location so the team can tell a service failure from a problem at one monitoring location. |
| When to alert | Every check writes a line. | Alert on a sustained failure, route it to the service owner with a runbook link, and send a recovery notification. Track probe availability separately so missing checks are visible. |

One implementation could use **Prometheus Blackbox Exporter** for HTTP probe metrics, a Prometheus alert rule that waits for a sustained failure, and **Alertmanager** to group and route the resulting alert. The runbook can tell the on-call engineer how to reproduce the failure from the affected network and verify recovery from the same location. [HTTP probe metrics](https://prometheus.io/docs/guides/multi-target-exporter/) · [Alerting rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/) · [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)

## Reproduce the lab

<details>
<summary>Python source, systemd units, and setup commands</summary>

Use an Ubuntu Server VM with Python 3, systemd, `curl`, `ss`, and a sudo-capable user. Run the lab commands from the Ubuntu guest. Check that TCP `8765` is available with `ss -ltn 'sport = :8765'`.

```bash
mkdir -p ~/incident-lab/site
cd ~/incident-lab
printf 'ok\n' > site/health.txt
```

**`probe.py`**

```python
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

URL = "http://127.0.0.1:8765/health.txt"
TIMEOUT_SECONDS = 2


def check_service():
    try:
        with urlopen(URL, timeout=TIMEOUT_SECONDS) as response:
            return response.status == 200, f"HTTP {response.status}"
    except HTTPError as error:
        with error:
            return False, f"HTTP {error.code}"
    except URLError as error:
        return False, f"Connection problem ({error.reason})"
    except OSError as error:
        return False, f"Connection problem ({error})"


if __name__ == "__main__":
    is_up, detail = check_service()
    status = "UP" if is_up else "DOWN"
    print(f"{status} | {detail}")
```

**`monitor.py`**

```python
from datetime import datetime, timezone
from time import sleep

from probe import check_service

CHECK_INTERVAL_SECONDS = 30


def main():
    was_up = None
    while True:
        is_up, detail = check_service()
        timestamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
        status = "UP" if is_up else "DOWN"
        if is_up and was_up is False:
            status = "RECOVERED"
        print(f"{timestamp} | {status} | {detail}", flush=True)
        was_up = is_up
        sleep(CHECK_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
```

Save both Python files in `~/incident-lab`. For the manual test, start the following command in that directory and leave it running in one shell.

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory site
```

In another shell, compare the probe before and after renaming the health file.

```bash
cd ~/incident-lab
python3 probe.py
mv site/health.txt site/health.off
python3 probe.py
mv site/health.off site/health.txt
```

Stop the foreground server with **Ctrl+C** in the first shell, then rerun `python3 probe.py` in the second to confirm the refused connection. This also frees the port for systemd.

Save these units in `~/incident-lab` under the filenames shown.

**`incident-lab-site.service`**

```ini
[Unit]
Description=Incident lab practice website

[Service]
User=incident-lab
ExecStart=/usr/bin/python3 -u -m http.server 8765 --bind 127.0.0.1 --directory /opt/incident-lab/site

[Install]
WantedBy=multi-user.target
```

**`incident-lab-monitor.service`**

```ini
[Unit]
Description=Incident lab Python monitor

[Service]
User=incident-lab
ExecStart=/usr/bin/python3 /opt/incident-lab/monitor.py
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

Deploy the scripts, health file, and units. The service account reads the files under `/opt/incident-lab` and runs both processes.

```bash
cd ~/incident-lab
if ! getent passwd incident-lab >/dev/null; then
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin incident-lab
fi
sudo install -d -m 0755 /opt/incident-lab/site
sudo install -m 0644 probe.py monitor.py /opt/incident-lab/
sudo install -m 0644 site/health.txt /opt/incident-lab/site/
sudo install -m 0644 incident-lab-site.service incident-lab-monitor.service /etc/systemd/system/
sudo systemd-analyze verify \
    /etc/systemd/system/incident-lab-site.service \
    /etc/systemd/system/incident-lab-monitor.service
```

Once the units pass verification, reload systemd and start the site. If the first curl request arrives during startup, retry it after a moment. Confirm `200 OK` before starting the monitor. [systemctl reference](https://manpages.ubuntu.com/manpages/noble/man1/systemctl.1.html)

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now incident-lab-site.service
curl -i --max-time 3 http://127.0.0.1:8765/health.txt
```

```bash
sudo systemctl enable --now incident-lab-monitor.service
sudo journalctl -u incident-lab-monitor.service -f -o cat
```

Wait for `UP`. In the other shell, run `sudo systemctl stop incident-lab-site.service` and `ss -ltn 'sport = :8765'`. After `DOWN` appears, run `sudo systemctl start incident-lab-site.service` and repeat the `curl` check. Look for `RECOVERED` in the live journal. [journalctl reference](https://manpages.ubuntu.com/manpages/noble/man1/journalctl.1.html)

</details>

## Related homelab work

- [Disk monitoring and systemd automation](../disk-monitor/README.md)
- [Homelab network overview](../networking/network-overview.md)
