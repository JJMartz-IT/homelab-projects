# Minecraft Bedrock Server in a Proxmox LXC

## Status

Deployment complete.

Installation, connectivity, service operation, world persistence,
remote access, backups, and isolated recovery were verified during
the lab. Verification was confirmed on October 16, 2026.

## Overview

This project hosts the official Minecraft Bedrock Dedicated Server
inside an unprivileged Ubuntu 24.04 LXC container on my Proxmox homelab.

The server runs as a dedicated Linux service account and is managed
by systemd. Approved friends connect through Tailscale, and an
in-game allowlist controls which players can join.

This server has a separate world from my Minecraft Java server.
Bedrock uses a native Linux executable rather than Java or Paper.

## Related Documentation

- [Homelab overview](../../README.md)
- [Proxmox installation](../proxmox/installation.md)
- [Network overview](../networking/network-overview.md)
- [Java Minecraft server](../minecraft-lxc/MINECRAFT_README.md)
- [Bedrock systemd service](../../systemd/bedrock.service)
- [Disk monitoring project](../disk-monitor/README.md)
- [SUID audit project](../suid-audit/suid-audit.md)

The disk monitor and SUID audit are separate projects. Linking them
here does not imply they are installed in this container.

## Configuration

| Setting | Value |
| --- | --- |
| Host hardware | Dell OptiPlex 7040 SFF |
| Host CPU | Intel i5-6500 |
| Host memory | 8 GB |
| Proxmox node | Main |
| Proxmox management address | https://192.168.1.100:8006 |
| Bedrock container ID | 102 |
| Container hostname | minecraft-bedrock |
| Operating system | Ubuntu 24.04 LTS |
| Architecture | x86_64 |
| Container type | Unprivileged LXC |
| CPU allocation | 2 cores |
| Container memory | 4096 MiB |
| Swap | 512 MiB |
| Root disk | 32 GiB |
| Disk storage | local-lvm |
| Network interface | eth0 |
| Network bridge | vmbr0 |
| IPv4 configuration | DHCP with router reservation |
| Default gateway | 192.168.1.1 |
| DNS configuration | Inherit Proxmox host settings |
| IPv4 game port | UDP 19132 |
| IPv6 game port | UDP 19133, when IPv6 is configured |
| Server directory | /srv/bedrock |
| Service account | bedrock |
| Service name | bedrock.service |
| Remote access | Tailscale machine sharing |

Retrieve the container's current LAN address with:

```bash
ip -4 -br addr
```

Retrieve its Tailscale address with:

```bash
tailscale ip -4
```

Use the actual Bedrock address when connecting. Do not reuse the
Java container's address, 192.168.1.60.

The attempted download during setup was named
`bedrock-server-1.26.52.3.zip`. The successful browser download was
renamed `bedrock-server.zip`. The server startup log is the authority
for the installed version.

### Resource planning

The host has 8 GB RAM. The Java server and restore-test containers
should remain stopped while running Bedrock to avoid excessive
memory pressure.

Leave the Bedrock container's Proxmox **Start at boot** setting
disabled while alternating between game servers.

The systemd service is enabled inside Ubuntu, so Bedrock starts
when the container is started manually.

### Container ID warning

CT 102 is the live Bedrock server.

Restore tests must use another unused container ID. Earlier lab
examples that used CT 102 as a restore target no longer apply.

## Installation Procedure

### 1. Create the Ubuntu container

**Why:**

A separate container provides its own filesystem, processes,
network configuration, and backup boundary. An unprivileged
container limits the privileges available on the Proxmox host.

**How:**

1. Open the Proxmox dashboard.
2. Select **Create CT**.
3. Use container ID `102` and hostname `minecraft-bedrock`.
4. Select the Ubuntu 24.04 standard amd64 template.
5. Keep **Unprivileged container** enabled.
6. Allocate the resources listed in the configuration table.
7. Configure `eth0` on `vmbr0`.
8. Select IPv4 DHCP and inherit the host's DNS settings.
9. Finish creation and start the container.
10. Open its console and log in as root.

Verify the environment:

```bash
hostname
cat /etc/os-release
uname -m
```

Expected information:

- Hostname: `minecraft-bedrock`
- Operating system: Ubuntu 24.04
- Architecture: `x86_64`

Unless otherwise stated, Linux commands below run inside
**CT 102**, not in the Proxmox host shell.

### 2. Verify networking

**Why:**

Testing the gateway, internet connectivity, and DNS separately
helps identify where a network problem occurs.

**How:**

```bash
ip -4 -br addr
ip route
cat /etc/resolv.conf
```

Test connectivity:

```bash
ping -c 3 192.168.1.1
ping -c 3 1.1.1.1
getent ahostsv4 www.minecraft.net
```

Get the container's MAC address:

```bash
cat /sys/class/net/eth0/address
```

Reserve the assigned IPv4 address for this MAC address in the
router's DHCP settings. Keep DHCP enabled in the container.

See the [network overview](../networking/network-overview.md)
for the surrounding network configuration.

### 3. Install supporting packages

**Why:**

Bedrock uses a native executable. Supporting libraries are needed
to run it, while curl and unzip support downloading and extracting
the installation archive.

**How:**

```bash
apt update
apt upgrade
```

```bash
apt install ca-certificates curl unzip nano file libcurl4t64 libstdc++6 libgcc-s1
```

Let package installation finish before continuing.

### 4. Create the service account

**Why:**

The game should run as a dedicated account instead of root.
This limits the permissions available to the server process.

**How:**

```bash
useradd --system --user-group \
  --home-dir /srv/bedrock --create-home \
  --shell /usr/sbin/nologin bedrock
```

```bash
chmod 750 /srv/bedrock
```

Verify:

```bash
id bedrock
ls -ld /srv/bedrock
```

The directory should belong to `bedrock:bedrock`.

Do not repeat the account-creation command if the account already
exists.

### 5. Download and transfer the server archive

**Why:**

Direct curl downloads failed during this installation. Downloading
the official archive through a Windows browser and transferring it
through Proxmox resolved the installation blocker.

TLS certificate verification was not disabled.

**How — Windows browser:**

1. Open the official download page:
   https://www.minecraft.net/en-us/download/server/bedrock
2. Read the displayed terms and proceed only if you agree.
3. Download the stable Ubuntu/Linux ZIP.
4. Save it in Downloads.
5. Rename it `bedrock-server.zip`.
6. Keep the archive compressed.

Enable file extensions in File Explorer to avoid accidentally
naming it `bedrock-server.zip.zip`.

**How — Windows PowerShell:**

```powershell
scp "$env:USERPROFILE\Downloads\bedrock-server.zip" root@192.168.1.100:/var/lib/vz/template/cache/bedrock-server.zip
```

Enter the Proxmox host's root password when prompted.

If the browser saved the file elsewhere, use its actual local path.

**How — Proxmox Main → Shell:**

```bash
pct push 102 /var/lib/vz/template/cache/bedrock-server.zip /tmp/bedrock-server.zip
```

This copies the archive from the host into the running container.

The ZIP in the host's template cache is a temporary staging file,
not an LXC operating-system template.

### 6. Test and extract the archive

**Why:**

A successful archive test helps detect an incomplete or damaged
download before installation.

**How — CT 102 console:**

```bash
unzip -t /tmp/bedrock-server.zip
```

Proceed only if the test reports no archive errors.

For the initial installation:

```bash
unzip /tmp/bedrock-server.zip -d /srv/bedrock
chown -R bedrock:bedrock /srv/bedrock
chmod 750 /srv/bedrock/bedrock_server
```

Check the executable and libraries:

```bash
file /srv/bedrock/bedrock_server
cd /srv/bedrock
LD_LIBRARY_PATH=/srv/bedrock ldd ./bedrock_server
```

Expect an x86-64 Linux executable and no missing library entries.

Do not blindly repeat extraction over an existing configured server.
Use a backup and a separate staging directory for upgrades.

### 7. Configure the game

**Why:**

The configuration limits the server to a small group, requires
authenticated accounts, and controls world-processing workload.

**How:**

```bash
nano /srv/bedrock/server.properties
```

Edit the existing matching entries:

```properties
server-name=Joseph's Bedrock Homelab
gamemode=survival
difficulty=normal
allow-cheats=false
max-players=4
online-mode=true
allow-list=true
server-port=19132
server-portv6=19133
enable-lan-visibility=true
view-distance=8
tick-distance=4
level-name=BedrockHomelab
default-player-permission-level=member
```

Leave other settings at their supplied defaults.

Save with **Ctrl+O**, press **Enter**, then exit with **Ctrl+X**.

Do not create duplicate entries for settings already in the file.

Setting an IPv6 game port does not itself configure IPv6 routing
or firewall access.

### 8. Start the server and configure the allowlist

**Why:**

A foreground launch displays startup errors directly and provides
a game console for adding approved players.

**How:**

```bash
cd /srv/bedrock
runuser -u bedrock -- env LD_LIBRARY_PATH=/srv/bedrock ./bedrock_server
```

Wait for successful startup and note the server version.

At this point, enter game commands into the running server console.

Replace the example name with the actual Xbox gamertag:

```text
allowlist add "Your Exact Gamertag"
```

Repeat for approved friends, then check:

```text
allowlist list
```

Stop the foreground server:

```text
stop
```

Wait for the Linux prompt before continuing.

### 9. Install the systemd service

**Why:**

systemd runs the server independently of an open console, restarts
it after failures, and collects its output in the journal.

**How:**

Create the installed unit:

```bash
nano /etc/systemd/system/bedrock.service
```

Copy the contents of the repository's
[bedrock.service](../../systemd/bedrock.service) into this file.

Validate and enable it:

```bash
systemd-analyze verify /etc/systemd/system/bedrock.service
systemctl daemon-reload
systemctl enable --now bedrock
```

Check operation:

```bash
systemctl status bedrock --no-pager -l
journalctl -u bedrock -b -n 80 --no-pager
```

The service should report `active (running)`.

The service configuration:

- Runs as the `bedrock` account.
- Uses `/srv/bedrock` as its working directory.
- Sets the library path needed by the executable.
- Restarts after failures.
- Limits repeated startup failures.
- Requests SIGINT during shutdown.
- Allows 180 seconds for shutdown.
- Prevents gaining new privileges through executable transitions.
- Restricts default permissions on newly created files.

Set the Proxmox container shutdown timeout to at least 240 seconds
so the service has time to stop.

### 10. Verify LAN access

**Why:**

Bedrock uses UDP 19132 for this IPv4 setup. A TCP test does not
verify the Bedrock game connection.

**How — inside the container:**

```bash
ss -lunp | grep ':19132'
```

Expect a UDP socket associated with `bedrock_server`.

`UNCONN` is normal output for this UDP socket.

If the Proxmox firewall filters incoming connections, add an
enabled rule under **CT 102 → Firewall**:

| Field | Value |
| --- | --- |
| Direction | in |
| Action | ACCEPT |
| Protocol | udp |
| Source | 192.168.1.0/24 |
| Destination port | 19132 |

Place the rule before an applicable drop rule. Any additional active
firewall must permit the same traffic.

In Minecraft for Windows, Android, or iOS, add the server using:

- Address: the Bedrock container's actual LAN address.
- Port: `19132`.

Use a compatible stable Bedrock client release.

Join the world, place a distinctive block, disconnect, and reconnect.

Do not use PowerShell's `Test-NetConnection -Port` as proof of
Bedrock connectivity; that command tests TCP.

### 11. Verify shutdown and persistence

**Why:**

A successful startup does not prove that world changes are saved
or that the service returns after a reboot.

**How:**

Disconnect players, then run:

```bash
systemctl stop bedrock
journalctl -u bedrock -b -n 80 --no-pager
```

Check for a normal shutdown without a timeout or forced kill.

Start the service again:

```bash
systemctl start bedrock
```

Reconnect and verify that the previously placed block remains.

Reboot CT 102 through Proxmox, then check:

```bash
systemctl is-enabled bedrock
systemctl is-active bedrock
```

Expected results:

```text
enabled
active
```

Reconnect and verify the world again.

### 12. Configure Tailscale

**Why:**

Tailscale provides private remote access without forwarding a
Minecraft port on the home router.

The network access policy and the Minecraft allowlist serve
different purposes: one controls connectivity and the other
controls game admission.

**How — Proxmox:**

1. Stop the Bedrock service.
2. Shut down CT 102.
3. Open **Resources → Add → Device Passthrough**.
4. Add `/dev/net/tun`.
5. Start CT 102.

Verify inside the container:

```bash
ls -l /dev/net/tun
```

Install Tailscale using its Ubuntu 24.04 package source:

```bash
curl -fsSLo /usr/share/keyrings/tailscale-archive-keyring.gpg \
  https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg
```

```bash
curl -fsSLo /etc/apt/sources.list.d/tailscale.list \
  https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list
```

```bash
apt update
apt install tailscale
systemctl enable --now tailscaled
tailscale up --accept-dns=false
```

Authenticate using the displayed link, then check:

```bash
tailscale status
tailscale ip -4
```

Share the `minecraft-bedrock` machine with approved friends.
Friends install Tailscale, sign into their own accounts, and
accept the share.

Adapt the existing tailnet policy to permit approved shared users
to reach this device on `udp:19132`. Check broader matching rules
because access permissions are additive.

If Proxmox filters the traffic, permit UDP 19132 from the friends'
actual Tailscale source addresses as well.

Remote players connect using the address shown to them in
Tailscale and port `19132`.

Verify with a player connecting from outside the home network.

These direct-client instructions cover Windows and mobile clients.
Console editions have different custom-server connection options.

## Operation and Maintenance

Run these commands inside CT 102.

| Task | Command |
| --- | --- |
| Start | `systemctl start bedrock` |
| Stop gracefully | `systemctl stop bedrock` |
| Restart | `systemctl restart bedrock` |
| Check status | `systemctl status bedrock --no-pager -l` |
| Recent logs | `journalctl -u bedrock -b -n 100 --no-pager` |
| Follow logs | `journalctl -u bedrock -f` |
| Check boot enablement | `systemctl is-enabled bedrock` |
| Memory usage | `free -h` |
| Disk usage | `df -h /srv/bedrock` |

Press **Ctrl+C** to exit log-following. This does not stop the server.

### Changing the allowlist later

The systemd service does not provide an attached interactive
game console.

To use the game-console commands:

1. Arrange downtime.
2. Stop the systemd service.
3. Start the foreground server using the command in Step 8.
4. Add or remove players.
5. Enter `stop`.
6. Start the systemd service again.

Never run two server processes against the same world directory.

### Updates

1. Stop the server cleanly.
2. Take a full backup.
3. Download the new official Linux release.
4. Extract into a separate staging directory.
5. Preserve worlds, configuration, allowlist, permissions,
   and custom resource or behavior packs.
6. Review changed defaults before deploying the new release.
7. Verify startup and client compatibility.
8. Test that existing world changes remain intact.

If rollback is required after a world upgrade, restore the
matching full backup rather than only replacing the executable.

## Backup and Restore

### Backup procedure

**Why:**

A backup preserves the container configuration and data stored on
its root disk. An off-host copy remains available if the Proxmox
host's storage fails.

**How:**

1. Notify players and disconnect them.
2. Run `systemctl stop bedrock`.
3. Check the journal for a normal shutdown.
4. Open **CT 102 → Backup → Backup now**.
5. Select backup-capable storage.
6. Use **Stop** mode.
7. Wait for `TASK OK`.
8. Ensure CT 102 is running.
9. Start Bedrock and verify its service.
10. Copy the archive to a separate computer.

The following data is stored on the container root disk:

```text
/srv/bedrock/worlds/
/srv/bedrock/server.properties
/srv/bedrock/allowlist.json
/srv/bedrock/permissions.json
/srv/bedrock/behavior_packs/
/srv/bedrock/resource_packs/
/etc/systemd/system/bedrock.service
```

If additional bind mounts are introduced, review their backup
coverage separately.

### Copy the backup to Windows

Run in Windows PowerShell:

```powershell
$backupFolder = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Bedrock Backup'
New-Item -ItemType Directory -Force -Path $backupFolder
$archivePath = Read-Host 'Paste the full Proxmox path of the CT 102 backup archive'
scp "root@192.168.1.100:$archivePath" "$backupFolder"
Get-ChildItem "$backupFolder"
```

At the prompt, paste the actual archive path from the Proxmox
backup task. Do not reuse a Java-server backup filename.

### Isolated restore test

**Why:**

A restore test checks whether the backup can recreate the server.
Isolation prevents conflicts with the live container's network
configuration or copied Tailscale identity.

**How:**

1. Select the archive under the backup storage's **Backups** view.
2. Restore into a different, unused container ID.
3. Select `local-lvm` for the restored disk.
4. Leave automatic startup disabled.
5. Set **Start at boot** to **No**.
6. Disconnect or remove the test container's network interface
   before its first boot.
7. Shut down the original Bedrock container to free memory.
8. Start the restored copy.
9. Inspect the world files, service status, and startup logs.
10. Shut down the test copy.
11. Restart the original container and verify availability.

Never use CT 102 as the destination for this test.

Offline authentication or network errors should be distinguished
from damaged archives or world-loading failures.

An offline restore test does not itself verify a player connection
to the restored copy.

## Verification

The following checks were confirmed complete by the lab owner:

- [x] Container starts with the intended resources.
- [x] LAN addressing and DHCP reservation work.
- [x] DNS and internet connectivity work.
- [x] Official Linux archive transfers and extracts successfully.
- [x] Bedrock starts under the dedicated service account.
- [x] The systemd service is active and enabled.
- [x] The server binds UDP 19132.
- [x] An approved player joins over the LAN.
- [x] The allowlist rejects unapproved players.
- [x] A graceful restart preserves world changes.
- [x] The service starts after a container reboot.
- [x] An approved friend connects externally through Tailscale.
- [x] A Proxmox backup completes successfully.
- [x] The backup is copied off the Proxmox host.
- [x] An isolated restore is tested.
- [x] The test copy is shut down afterward.
- [x] The original server returns to service.

Repeat the service checks with:

```bash
systemctl is-enabled bedrock
systemctl is-active bedrock
ps -eo user,pid,args | grep '[b]edrock_server'
ss -lunp | grep ':19132'
journalctl -u bedrock -b -n 100 --no-pager
```

Then perform an actual client connection and a world-save test.

Service status, network connectivity, and successful gameplay
are separate verification steps.

## Issues and Resolutions

| Issue | Cause or observation | Resolution |
| --- | --- | --- |
| `read: ... not a valid identifier` | A download URL was supplied where Bash expected a variable name. | Keep `BEDROCK_URL` in the command, press Enter, then paste the URL at the prompt. |
| `curl: (92) HTTP/2 stream ... INTERNAL_ERROR` | The HTTP/2 transfer failed before delivering the archive. The underlying cause was not established. | Tried HTTP/1.1, then used the browser-download transfer method. |
| HTTP/1.1 download remained at zero bytes | No payload arrived during the observed 45 seconds; the command was canceled with Ctrl+C. | Downloaded in Windows and transferred using `scp` and `pct push`. |
| `unzip: cannot find or open ...` | The archive did not exist because the previous download failed. | Complete the transfer and run `unzip -t` before extraction. |
| Initial guide used CT 103 | The actual deployment used CT 102. | Updated documentation and commands to CT 102. Restore tests require another unused ID. |

The browser-transfer method resolved the installation blocker.
It did not establish the root cause of the curl failures.

## Lessons Learned

- **Commands depend on their execution environment.**
  PowerShell commands run on Windows, `pct push` runs on the
  Proxmox host, and service commands run inside the container.

- **Variable names and values are different.**
  `read` stores entered text in `BEDROCK_URL`;
  `$BEDROCK_URL` retrieves that text later.

- **A connection can succeed while a transfer stalls.**
  A connection timeout does not limit the entire download.

- **Validate each stage before continuing.**
  Failed downloads lead to missing files. Archive testing should
  precede extraction.

- **UDP and TCP require different tests.**
  Bedrock uses UDP 19132 for this setup. The Java server uses
  TCP 25565.

- **Least privilege works through multiple layers.**
  An unprivileged container, dedicated account, restricted file
  permissions, and service settings each contribute.

- **Connectivity and authorization are separate.**
  Tailscale controls network access; the allowlist controls
  admission to the game.

- **Service startup and container startup are separate.**
  Enabling a systemd service does not automatically enable
  Proxmox container startup.

- **Memory planning includes every running guest.**
  Unused game servers and test containers should be stopped
  on the 8 GB host.

- **Backups require recovery testing.**
  An off-host copy and a successful isolated restore address
  different failure scenarios.

- **Document the actual deployment.**
  Bedrock occupies CT 102, regardless of the initial suggested ID.

## Certification Skills Practiced

| Certification area | Skills practiced |
| --- | --- |
| Linux Essentials | Files, users, groups, permissions, environment variables, package management, and process inspection |
| CCST Networking | DHCP, addressing, routing, DNS, UDP versus TCP, firewall rules, and troubleshooting |
| Security+ | Least privilege, authentication, access control, encrypted remote access, backups, and recovery |
| AZ-900 concepts | Virtualization, resource allocation, availability, and recovery concepts |

This project runs locally in Proxmox, not in Azure.


## References

- [Official Bedrock server download](https://www.minecraft.net/en-us/download/server/bedrock)
- [Microsoft Bedrock setup guide](https://learn.microsoft.com/en-us/minecraft/creator/documents/bedrockserver/getting-started)
- [Bedrock server properties](https://learn.microsoft.com/en-us/minecraft/creator/documents/bedrockserver/server-properties)
- [Proxmox container administration](https://pve.proxmox.com/pve-docs/chapter-pct.html)
- [Tailscale in LXC](https://tailscale.com/kb/1130/lxc-unprivileged)
- [Tailscale machine sharing](https://tailscale.com/kb/1084/sharing)
- [Tailscale Ubuntu packages](https://pkgs.tailscale.com/stable/#ubuntu-noble)
