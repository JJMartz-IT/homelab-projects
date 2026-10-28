# Bedrock backups and world recovery

[Back to the project](README.md)

## Incident and result

After an unexpected shutdown, buildings disappeared from the player's
area while animals remained, and a one-chunk hole appeared in the ground.
This was consistent with damaged or reverted world data, but no database
forensic analysis established the exact failure.

A backup from before October 23 was tested and restored. The player
confirmed that the buildings returned. The damaged world was retained
separately rather than deleted. Add-ons were subsequently added back.

Restoring a backup also rolls back progress made after that backup.
The presence of animals or a successful server startup is not evidence
that the terrain is intact.

## Scheduled application backup

The deployed design uses a stopped-server backup every four hours, with
in-game warnings. It is not a live snapshot of an actively written world.

| Component | Purpose |
| --- | --- |
| /usr/local/sbin/bedrock-backup | Coordinates warning, shutdown, archive and restart |
| bedrock-backup.service | Runs the backup as a systemd oneshot |
| bedrock-backup.timer | Schedules the job |
| /run/lock/bedrock-backup.lock | Prevents overlapping backup/update operations |
| /srv/backups/hourly | Historical directory name; actual interval is four hours |
| Retention | 48 successful scheduled archives, about eight days at six per day |

The recorded timer schedule is:

```ini
OnCalendar=*-*-* 00,04,08,12,16,20:00:00
Persistent=true
```

This follows the container's timezone. The uploaded timer output used UTC.
Use `timedatectl` and `systemctl list-timers` to read actual upcoming
times; do not assume they match the Windows clock. Persistent timers can
run a missed backup after being reactivated.

The implemented sequence:

1. Acquire the backup lock and check that Minecraft is running.
2. Check available disk space.
3. Warn players at five minutes, one minute and ten seconds.
4. Stop bedrock.service gracefully and ensure no Bedrock process remains.
5. Archive /srv/bedrock into a temporary archive outside that directory.
6. Test the archive with tar before publishing its final filename.
7. Wait an additional 45 seconds, then start Minecraft.
8. Retry the local /v1/join signaling endpoint and report failure if it
   does not become available.
9. Prune only the scheduled job's older archives after successful checks.

The script includes cleanup/restart handling on failure. A failed health
check retains the archive for investigation. A valid archive is not proof
that its contained world is healthy: restore testing is still necessary.

## Inspect and verify

```bash
systemctl cat bedrock-backup.service bedrock-backup.timer
systemctl is-enabled bedrock-backup.timer
systemctl list-timers bedrock-backup.timer --no-pager
journalctl -u bedrock-backup.service -n 100 --no-pager
df -h /srv
ls -lh /srv/backups/hourly
```

To request a manual run of the installed job during a planned test:

```bash
systemctl start --no-block bedrock-backup.service
journalctl -u bedrock-backup.service -f
```

This runs the warning countdown and causes downtime. Ctrl+C only stops
following logs. Verify actual player reconnection afterward.

The timer was confirmed active before the October 28 upgrade. It was
paused for that upgrade; resuming it was the final instructed step.
The player's successful update report did not include post-update timer
output, so verify it rather than assuming it resumed automatically.

## What these archives cover

The application tar archives contain the server executable, world,
server.properties, allowlist, permissions, resource packs, behavior packs
and configuration under /srv/bedrock.

They do not by themselves capture /usr/local/sbin helpers, systemd units,
Tailscale state or the rest of the container. Maintain Proxmox container
backups as well. Copies on the same physical disk cannot protect against
that disk failing; keep a separate off-host copy.

The original [project guide](README.md#backup-and-restore) describes
Proxmox stop-mode backups and isolated container restore testing.

## Recovery workflow

1. Pause the scheduled backup timer and let any running job finish.
2. Stop Minecraft cleanly. Do not continue playing in the damaged world.
3. Preserve the damaged server/world under a unique dated path.
4. List and test a candidate archive before extraction:
   `tar -tzf /path/to/backup.tar.gz`.
5. Extract into a new, empty recovery directory, not over the live server.
   Application archives created with `tar -C /srv bedrock` contain a
   top-level bedrock directory; Proxmox backups require Proxmox restore.
6. Test with the matching server version and add-on set. For a cloned
   container, use an unused CT ID and isolate its network/Tailscale
   identity before booting. CT 102 is the live container.
7. Verify the expected buildings, inventory, animals and affected chunks.
8. Stop the test process, promote the verified copy, and restore
   bedrock:bedrock ownership where required.
9. Start the service, check logs and signaling, then join.
10. Resume the backup timer and inspect its next scheduled run.

Do not mix a new world database with unrelated old database files. If a
server update modified the world, roll back the matching full server/world
copy, not just the executable.

## Lessons practiced

Graceful shutdown, systemd timers, file locking, retention, archive
verification, recovery testing and distinguishing process health from
application availability. A backup reduces data-loss exposure; it does
not prevent corruption or guarantee zero lost progress.
