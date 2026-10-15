# Minecraft Java Server in a Proxmox LXC

## Status

Deployment in progress. Verification results are recorded below.

## Overview

This project hosts a PaperMC Java server for 2–4 players inside
an unprivileged Ubuntu LXC container on my Proxmox homelab.

Friends connect through Tailscale. Minecraft runs as a dedicated
Linux service account and is managed by systemd.

## Related Documentation

- [Homelab overview](../../README.md)
- [Proxmox installation](../proxmox/installation.md)
- [Network overview](../networking/network-overview.md)
- [Existing disk monitoring project](../disk-monitor/README.md)
- [Existing SUID audit project](../suid-audit/suid-audit.md)
- [Minecraft systemd service](../../systemd/minecraft.service)

The disk monitor and SUID audit currently document projects on
the separate Ubuntu VM. Deployment in this container is not implied.

## Configuration

| Setting | Value |
| --- | --- |
| Proxmox host IP | 192.168.1.100 |
| CT ID | 102 |
| Container hostname | minecraft |
| Container OS | ubuntu-24.04-standard_24.04.2_amd64 |
| Container type | Unprivileged LXC |
| Bridge | vmbr0 |
| LAN address | 192.168.1.60 |
| DNS server | 8.8.8.8 |
| CPU allocation | 2 Cores |
| Container RAM | 3gb |
| Root disk | 32gb |
| Java version | Java 25] |
| Paper version/build | 26.3 |
| JAR SHA-256 | db0fd32588e732fd0de57cc95a2076624b0e73c1cb2dba87dc5f5f3340bcbb1b |
| Game port | TCP 25565 |
| Server directory | /srv/minecraft |
| Service account | minecraft |
| Service | minecraft.service |
| Remote access | Tailscale machine sharing |

## Installation Procedure

### 1. Prepare the Proxmox environment

Access the Proxmox dashboard at:

https://192.168.1.100:8006

The Minecraft server uses a dedicated Ubuntu LXC container on node `Main`. An LXC container shares the host's Linux kernel while providing a separate environment for the application.

See [Proxmox installation](../proxmox/installation.md) for the host setup.

### 2. Download the Ubuntu container template

Under **local (Main) → CT Templates → Templates**, download:

`ubuntu-24.04-standard_24.04-2_amd64.tar.zst`

Verify that the download finishes with `TASK OK`.

The template supplies the Ubuntu filesystem used to create the container.

### 3. Create the Minecraft container

Use **Create CT** with these settings:

| Setting | Value |
|---|---|
| Node | Main |
| Container ID | 101 |
| Hostname | minecraft |
| Operating system | Ubuntu 24.04 LTS |
| Unprivileged container | Enabled |
| Nesting | Enabled |
| CPU cores | 2 |
| Memory | 3072 MiB |
| Swap | 512 MiB |
| Root disk | 32 GiB |
| Disk storage | local-lvm |
| Network interface | eth0 |
| Bridge | vmbr0 |
| IPv4 configuration | DHCP |
| Network firewall flag | Enabled |
| DNS | Inherit host settings |

An unprivileged container maps container root to an unprivileged host identity, reducing the privileges available outside the container.

The memory allocation leaves capacity for Proxmox and the existing Ubuntu VM. Java's maximum heap should remain below the container's total memory limit.

### 4. Verify networking

Start the container and log in through its Proxmox console.

Run:

```bash
hostname
ip -4 -br addr
ip route
cat /etc/resolv.conf
```

The observed configuration was:

| Setting | Observed value |
|---|---|
| Hostname | minecraft |
| IPv4 address | 192.168.1.60/24 |
| Default gateway | 192.168.1.1 |
| DNS servers | 1.1.1.1 and 8.8.8.8 |
| DNS search domain | arpa |

Test each part of the connection separately:

```bash
ping -c 3 192.168.1.1
ping -c 3 1.1.1.1
getent ahostsv4 papermc.io
```

The first command tests router reachability, the second tests internet reachability by IP address, and the third tests DNS resolution.

The address was assigned through DHCP. A DHCP reservation should be configured on the router to keep the address consistent; reservation completion has not yet been recorded.

See the [network overview](../networking/network-overview.md) for the wider homelab network.

### 5. Prepare Java and Paper

The installation procedure uses:

- A Java version compatible with the selected Paper release.
- A dedicated `minecraft` service account.
- `/srv/minecraft` for the server files and world data.
- `server.jar` as the server executable.
- An initial Java heap of 1 GiB and maximum heap of 2 GiB.

Before installing or upgrading, check the selected Paper release's Java requirements:

- [Paper getting started](https://docs.papermc.io/paper/getting-started/)
- [Paper downloads](https://papermc.io/downloads/paper)

Record the installed Java and Paper versions when collecting the final verification results.

Run the server once to generate its initial files. Read the Minecraft EULA before accepting it in `eula.txt`.

Configure `server.properties` for the intended small Java Edition server. Keep account authentication enabled, use a whitelist, and leave `server-ip` blank so the server can listen on the container's available interfaces.

### 6. Manage Minecraft with systemd

Use a system service named `minecraft.service` to run the server as the dedicated `minecraft` account.

The service configuration should use:

- Working directory: `/srv/minecraft`
- Startup command: `/usr/bin/java -Xms1G -Xmx2G -jar /srv/minecraft/server.jar --nogui`
- Automatic restart on failure.
- A graceful stop signal and sufficient time to save the world.

Check service health and logs with:

```bash
systemctl status minecraft --no-pager -l
journalctl -u minecraft -b -n 100 --no-pager
```

Enable the service for container startup, and enable the container's **Start at boot** option when ready.

Service enablement and reboot persistence require separate verification; a listening Java process alone does not prove them.

### 7. Test LAN connectivity

Inside the container:

```bash
ss -lntp | grep ':25565'
```

The observed output showed a Java process listening on TCP port `25565`.

From Windows PowerShell:

```powershell
Test-NetConnection 192.168.1.60 -Port 25565
```

The observed result was:

```text
TcpTestSucceeded : True
```

Connect from a compatible Minecraft Java Edition client using:

```text
192.168.1.60:25565
```

An actual player joining the world is a separate application-level test.

### 8. Configure remote access

The planned remote-access method is Tailscale, allowing approved friends to connect without router port forwarding.

The setup includes providing `/dev/net/tun` to the unprivileged container, installing Tailscale, and restricting shared access to the Minecraft service.

A successful LAN connection does not verify remote access. Record a connection test from outside the home network before marking this complete.

### 9. Back up and test recovery

Use a Proxmox container backup to preserve the container configuration and data stored on its root disk.

The backup selected during the copy attempt was:

`vzdump-lxc-101-2026_10_15-03_16_46.tar.zst`

The recovery procedure is:

1. Stop Minecraft gracefully before taking the backup.
2. Create a Proxmox backup using Stop mode.
3. Restart the original server and check its service.
4. Copy the backup to a separate computer.
5. Restore the archive into an unused container ID, such as `102`.
6. Keep the restored container's network disconnected before starting it.
7. Disable **Start at boot** on the test container.
8. Check the restored world files and Minecraft startup logs.
9. Shut down the test container after inspection.

The restored copy may contain the original network settings and Tailscale identity. It must remain isolated during the offline recovery test.

Because the host has 8 GB RAM, temporarily shut down the original Minecraft container before booting the test copy.



## Verification

### Confirmed results

| Check | Evidence | Result |
|---|---|---|
| Ubuntu container starts and accepts console login. | Logged into CT 101 as root. | Passed |
| Container hostname is configured. | `hostname` returned `minecraft`. | Passed |
| Container has an IPv4 address. | `ip -4 -br addr` showed `192.168.1.60/24` on `eth0`. | Passed |
| Default route is present. | `ip route` showed gateway `192.168.1.1`. | Passed |
| DNS servers are configured. | `/etc/resolv.conf` listed `1.1.1.1` and `8.8.8.8`. | Passed |
| Router is reachable. | Three ping replies with 0% packet loss. | Passed |
| External IP connectivity works. | Ping to `1.1.1.1` returned three replies with 0% packet loss. | Passed |
| DNS resolution works. | `getent ahostsv4 papermc.io` returned IPv4 addresses. | Passed |
| Java is listening on the Minecraft port. | `ss` showed Java listening on TCP `25565`. | Passed |
| Windows can reach the Minecraft port. | PowerShell returned `TcpTestSucceeded : True`. | Passed |

### Results still to record

- [x] Record the installed Java version and Paper version/build.
- [x] Confirm the Minecraft process runs as the dedicated service account.
- [x] Confirm `minecraft.service` is active and enabled.
- [ ] Confirm a player can join and interact with the world over the LAN.
- [x] Confirm the whitelist allows approved players and rejects unapproved players.
- [x] Confirm a DHCP reservation keeps the container address consistent.
- [x] Confirm the Minecraft service starts after a container restart.
- [x] Confirm world changes persist after a graceful restart.
- [x] Confirm an approved friend can connect through Tailscale from outside the home network.
- [x] Record the Proxmox backup task's successful completion.
- [x] Confirm the backup copies successfully to the Windows computer.
- [x] Compare SHA-256 checksums of the source and copied backup.
- [x] Confirm an isolated restore completes successfully.
- [x] Confirm the restored world files are present and Minecraft loads them.
- [x] Confirm the test container is shut down and the original server is available afterward.


## Issues and Resolutions

| Issue | Cause | Resolution or next action | Status |
|---|---|---|---|
| `ping` reported an invalid argument. | The destination IP followed `-c` without a packet count. | Use `ping -c 3 192.168.1.1`. The corrected command received three replies. | Resolved |
| PowerShell reported `Name resolution of MC_LAN_IP failed`. | The placeholder was entered literally. | Replace it with `192.168.1.60`. The subsequent TCP test succeeded. | Resolved |
| `scp` printed its usage information. | The command did not include both a valid source and destination. | Supply the Proxmox archive path followed by a Windows destination folder. | Syntax corrected; transfer still needs confirmation |
| `scp` reported `open local ... Permission denied`. | The destination was `.`, and PowerShell was in `C:\Windows\System32`. | Use a writable folder such as `Minecraft Backup` on the user's Desktop. | Corrected command provided; successful copy not yet recorded |
| SSH reported `Permission denied, please try again`. | The password attempt was rejected. | Retry with the Proxmox host's root password and check keyboard input. | Successful retry not yet recorded |

The corrected backup-copy commands run in **Windows PowerShell**:

```powershell
$backupFolder = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Minecraft Backup'
New-Item -ItemType Directory -Force -Path $backupFolder

scp root@192.168.1.100:/var/lib/vz/dump/vzdump-lxc-101-2026_10_15-03_16_46.tar.zst "$backupFolder"

Get-ChildItem "$backupFolder"
```

The backup filename must match the archive being copied.
## Lessons Learned

- **The Proxmox host and its containers have separate identities.** The host uses `192.168.1.100`, while the Minecraft container was assigned `192.168.1.60`. Commands must be run in the correct environment.

- **Network testing works best in stages.** Testing the gateway, an external IP address, DNS resolution, and the Minecraft port separately helps identify where a connection fails.

- **A listening port is only one part of verification.** `ss` confirms that a process is listening locally. A Windows TCP test confirms network reachability. Joining the world confirms the application accepts a player.

- **Placeholders must be replaced with actual values.** `MC_LAN_IP` represents the container's address; entering it literally causes a name-resolution failure.

- **Command options require the correct arguments.** The `-c` option in `ping` expects a packet count, such as `3`, before the destination address.

- **The current directory affects file transfers.** Using `.` as the destination for `scp` saves into the current PowerShell directory. A protected folder such as `C:\Windows\System32` can prevent the download.

- **Host and container passwords are separate credentials.** Copying a backup from the Proxmox host requires credentials for that host.

- **Java heap memory and container memory are different limits.** The container also needs memory for Java overhead, Ubuntu processes, and other services.

- **Service management supports reliable operation.** systemd provides startup management, process supervision, and centralized logs. Boot persistence still needs to be tested.

- **A backup needs a recovery test.** Creating an archive, copying it elsewhere, and successfully restoring it are separate checks.

- **Restored systems can duplicate identities.** A test restore should remain disconnected until its network settings and any copied VPN identity are handled deliberately.

These concepts build on the service-management work in the
[disk monitor project](../disk-monitor/README.md) and the permission concepts in the
[SUID audit project](../suid-audit/suid-audit.md).

## References

- [Original Minecraft LXC article](https://medium.com/@rar1871/proxmox-minecraft-in-an-lxc-792419c93b16)
- [PhotoPrism LXC reference](https://medium.com/@rar1871/proxmox-installing-photoprism-in-lxc-5c9d71c25b43)
- [Paper setup documentation](https://docs.papermc.io/paper/getting-started/)
- [Tailscale in LXC](https://tailscale.com/kb/1130/lxc-unprivileged)
