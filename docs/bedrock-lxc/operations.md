# Bedrock operations and connectivity

[Back to the project](README.md)

Recorded through October 28, 2026. Commands run as root in the Minecraft
container's Proxmox console unless another environment is named.

## Current deployment

| Item | Recorded value |
| --- | --- |
| Live container | CT 102, minecraft-bedrock |
| Server root | /srv/bedrock |
| Active world | /srv/bedrock/worlds/ImportedWorld |
| Runtime user/group | bedrock:bedrock |
| Service | bedrock.service |
| Server release after update | 1.26.60.6 |
| Windows client release | 26.60 |
| Startup wrapper | /usr/local/sbin/bedrock-launch |
| Command helper | /usr/local/sbin/bedrock-command |
| Backup script | /usr/local/sbin/bedrock-backup |
| Updates | Manual; restarting does not download a new release |

The separate Docker-based Bedrock project was started in an Ubuntu VM:
Docker was installed, a docker-compose.yml was present, and world import
was requested. Its completed deployment/import has not been verified in
this record. Commands here target the original LXC, not that VM.

## Logs versus console commands

```bash
systemctl status bedrock --no-pager -l
journalctl -u bedrock -b -n 100 --no-pager
journalctl -u bedrock -f
```

Ctrl+C exits journal following without stopping Minecraft. The journal is
output only; typing a game command there does not send it to the server.

The installed wrapper opens a named pipe at
/run/bedrock-console/input and connects it to the server's standard input.
A systemd override selects the wrapper while retaining the dedicated
bedrock account and the original service's shutdown settings.

```bash
bedrock-command say "Server maintenance will begin shortly."
bedrock-command list
bedrock-command allowlist add "Exact Xbox Gamertag"
```

Run these as root. The helper was configured to send one command to the
pipe without opening another server process. Inspect its installed source
with `cat /usr/local/sbin/bedrock-command` before changing it.
Never run two Bedrock processes against the same world.

The exact observed wrapper and override are stored in
[bedrock-launch](../../scripts/bedrock-launch) and
[console.conf](../../systemd/bedrock.service.d/console.conf).
These files alone are not a fresh-install console kit: the separate
command helper must also be installed.

## NetherNet and Tailscale

The original guide assumed RakNet with UDP 19132. During later iPad
troubleshooting, RakNet was reported unsupported; the working deployment
used NetherNet. The friend subsequently joined successfully.

Observed settings for this deployment:

```properties
transport=nethernet
server-port=19132
level-name=ImportedWorld
texturepack-required=true
```

The configured UDP range was 19140–19155, advertised using the container's
Tailscale IPv4 address. A portable example of the setting is:

```text
server-udp-ports=TAILSCALE_IPV4:19140-19155:19140-19155
```

TAILSCALE_IPV4 is a placeholder, not a value to paste unchanged. Preserve
the live working value during updates. These are recorded deployment
settings, not universal defaults for every Bedrock release or topology.

For this setup, permit TCP 19132 for signaling and UDP 19140–19155 for
game traffic through applicable host/container firewalls and the tailnet
policy, scoped to approved clients. Tailscale connectivity and Minecraft
allowlist membership are separate requirements.

```bash
tailscale status
tailscale ip -4
ss -lntup
curl --noproxy '*' --connect-timeout 5 --max-time 10 \
  http://127.0.0.1:19132/v1/join
```

The local HTTP endpoint returned JSON describing the server, version and
player count when healthy. This checks signaling, not a completed remote
game connection. Finish verification by joining from a real client.

A successful Tailscale ping, a Safari HTTP response, or an active systemd
service alone did not prove that the iPad could join. Likewise, checking
only UDP 19132 missed this deployment's actual transport.

## Connection failure after backups

After an earlier backup restart, the service reported active but clients
could not connect. A later stop, wait and start restored access. The
backup procedure was changed to wait an additional 45 seconds before
starting and check the signaling endpoint afterward.

This is an observed workaround; the underlying cause was not proven.

For manual maintenance, coordinate with the backup timer first:

```bash
systemctl stop bedrock-backup.timer
systemctl show bedrock-backup.service --property=ActiveState --value
```

If the backup is active or activating, let it finish before stopping the
game. Then, during agreed downtime:

```bash
systemctl stop bedrock
sleep 45
systemctl start bedrock
journalctl -u bedrock --since "2 minutes ago" --no-pager
```

Check the endpoint and join. Resume the timer after successful checks:

```bash
systemctl start bedrock-backup.timer
systemctl list-timers bedrock-backup.timer --no-pager
```

See [backup and recovery](backup-recovery.md) and
[manual updates](updates.md).
