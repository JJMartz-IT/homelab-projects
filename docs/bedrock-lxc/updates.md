# Manual Bedrock updates

[Back to the project](README.md)

## Successful update on October 28, 2026

The Windows client showed 26.60 while the server log still showed
1.26.52.3. The official stable Linux archive used for the update was
bedrock-server-1.26.60.6.zip. After installation the player reported:
"Works great."

The service and launcher start the installed executable. They do not
download updates. The scheduled backup job also restarts the existing
installation; it is not an updater.

## Download failures and successful transfer

Direct curl download failed with HTTP/2 error 92. Retrying with HTTP/1.1
stalled at zero bytes and was canceled. The root cause was not established.

The successful fallback was:

1. Download the regular Ubuntu/Linux ZIP in a Windows browser from the
   [official Bedrock server page](https://www.minecraft.net/en-us/download/server/bedrock).
   The server OS determines the archive, not the downloading PC's OS.
2. Keep the ZIP compressed.
3. Transfer it to the container with SCP.
4. Test the archive before installation.

Root SCP password login failed. The observed SSH settings included:

```text
permitrootlogin without-password
passwordauthentication yes
```

The root-specific rule disallows root password login even though password
authentication is available to regular accounts. It does not mean that
root accepts an empty password.

A temporary unprivileged account, mc-transfer, was created in the
container's Proxmox console with `adduser mc-transfer`. The file was
transferred into that user's home directory, then moved by root into the
update staging directory. The account's password was locked afterward
with `passwd -l mc-transfer`; root SSH policy was not relaxed.

Example Windows command (replace CONTAINER_LAN_IP):

```powershell
scp "$env:USERPROFILE\Downloads\bedrock-server-1.26.60.6.zip" mc-transfer@CONTAINER_LAN_IP:/home/mc-transfer/server.zip
```

The archive passed Python zipfile.testzip(), and contained bedrock_server.
Before updating, the server directory occupied 452 MB and about 24 GB
was free. Those measurements are historical, not a substitute for a
fresh space check.

## Procedure used

1. Pause bedrock-backup.timer.
2. Acquire /run/lock/bedrock-backup.lock without waiting. If a backup is
   busy, let it finish and retry rather than interrupting it.
3. Warn players that maintenance starts in 60 seconds.
4. Stop bedrock.service and verify no bedrock_server process remains.
5. Create and test a full /srv/bedrock archive under /srv/backups.
6. Copy the stopped installation into a separate prepared directory.
7. Extract the new official archive over that prepared copy, excluding
   worlds, server.properties, allowlist.json, permissions.json and config.
8. Set executable permission on bedrock_server, restore bedrock:bedrock
   ownership and compare server.properties with the original.
9. Rename the old installation to a dated directory outside /srv/bedrock.
10. Move the prepared installation into /srv/bedrock.
11. Wait 45 seconds before starting, then inspect logs and service status.
12. Check signaling and join from the updated client.
13. Resume the backup timer after successful verification.

The archive and old directory used these naming patterns:

```text
/srv/backups/bedrock-before-26.60-YYYYMMDD-HHMMSS.tar.gz
/srv/bedrock-before-26.60-YYYYMMDD-HHMMSS
```

Keeping the old installation outside the live directory prevents each
scheduled application backup from recursively including the old copy.

This update method retained custom packs while replacing files supplied
by the new release. Because it overlays a copy, it may retain obsolete
distribution files. For future releases, review changed/removed vendor
files, configuration defaults and custom-pack compatibility before using
the same approach. The protected config directory also requires review
for any new upstream configuration requirements.

The /usr/local/sbin helpers and /etc/systemd/system units were outside
the replaced directory and were preserved.

## Verification commands

Run inside the container:

```bash
systemctl status bedrock --no-pager -l
journalctl -u bedrock --since "5 minutes ago" --no-pager
curl --noproxy '*' --connect-timeout 5 --max-time 10 \
  http://127.0.0.1:19132/v1/join
```

Confirm the startup version, correct world, pack loading, and client
connection. Inspect important buildings and inventory, then test add-on
features. Resume backups:

```bash
systemctl start bedrock-backup.timer
systemctl list-timers bedrock-backup.timer --no-pager
```

The update script deliberately left the timer paused for those checks.
If any step fails, inspect what completed before rerunning commands.
Do not restart an older executable against a world already upgraded by
the new release.

## Rollback

Pause the timer, let any running backup finish, and stop Minecraft.
Preserve the unsuccessful new installation separately. Restore the whole
matching old installation/world or the verified pre-update archive.
Check ownership, start the old release, inspect logs and verify the
world with a compatible client before resuming backups.

Never combine selected LevelDB files from unrelated saves. Restoring
the old world discards progress made after the recovery point.

## Maintenance lessons

- An active service is only one availability check.
- Client updates and dedicated-server updates are separate.
- Browser download plus SCP can resolve a transfer blocker without
  disabling TLS checks or allowing root password SSH access.
- Stage changes and preserve a coherent recovery copy before swapping.
- Backup schedules must be explicitly resumed and checked after work.
