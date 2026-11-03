# backups-rsync-cron

## Concepts

A backup that has never been restored is a hope, not a backup. And a scheduled job nobody documented
is a future mystery, or a place for an attacker to hide. This lab backs up a small web application the
way it's done on real servers: rsync to a local copy and to a separate backup machine over SSH, a
script that cron runs every night, and a restore drill to prove it works.

**rsync** copies only what changed, locally or over SSH:

| Option | Meaning |
|---|---|
| `-a` | Archive: recursive, and keep permissions, owners, times and symlinks (`-rlptgoD`) |
| `--delete` | Remove files from the destination that no longer exist in the source (a mirror) |
| `--exclude=cache/` | Skip a path, relative to the source |
| `-n`, `-v`, `-P` | Dry run, verbose, progress (with resumable partial files) |
| `-e "ssh ..."` | The remote shell to use, e.g. with extra SSH options |
| `--mkpath` | Create missing parent directories of the destination (rsync 3.2.3+) |

The trailing slash on the **source** matters: `rsync -a src/ dst/` copies the *contents* of src into
dst, while `rsync -a src dst/` creates `dst/src/`. `--delete` deletes for real, so try it with `-n`
first.

**Over SSH**, `rsync -a src/ user@host:/path/` runs rsync on both ends through an SSH connection. A
job that cron starts can't type a password or a passphrase, so it needs a key with **no passphrase**,
used for nothing else. On a real server I'd also restrict it in `authorized_keys`.

**cron**: a line is `minute hour day-of-month month day-of-week command`.
- In **root's crontab** (`crontab -e`), that's the whole line.
- In **/etc/cron.d/NAME** (preferred for system jobs, because it's a file you can see and manage),
  a **user field** comes before the command: `15 2 * * * root /usr/local/bin/backup.sh`.
- cron runs with a tiny `PATH` and no terminal, so use absolute paths and send output to a log, e.g.
  `>> /var/log/backup.log 2>&1`.

**Restore drills**: delete something, restore it, and check the content, owner and mode. That's the
only way to know the backup covers what you think it covers.

**For incident response**: "is this host backed up?" is answered by `ls /etc/cron.d` and
`tail /var/log/backup.log`. Persistence hunting starts at the same place:
`grep -r '/tmp/\|@reboot' /etc/cron* /var/spool/cron`.

## Tasks

Start the lab with `./lab up backups-rsync-cron`, open a shell with `./lab shell backups-rsync-cron`.
You are `root` on `web-01`; the backup server is reachable as `backup`. The application lives in
`/srv/app`. Write `KEY=value` answers to `/root/answers.txt`.

1. **Local mirror.** Make `/srv/backup/app` an exact mirror of `/srv/app`, keeping modes, owners and
   times, but without `cache/`. Files in the old backup that no longer exist in the source must go.
2. **Key login.** Set up key-based SSH from root to `vault@backup`, with a key that cron can use
   unattended. vault's password, for the one-time setup, is `vault-pass`.
3. **backup.sh.** Write `/usr/local/bin/backup.sh`:
   - A shebang and `set -euo pipefail`, executable.
   - It updates the local mirror *and* a mirror on the server in `/backups/<this host's name>/app/`,
     both with the same rules as task 1.
   - It appends a line starting with an ISO date (like `2026-11-03T02:15:00+00:00`) to
     `/var/log/backup.log`.
   - The check runs it.
4. **Schedule.** Run `backup.sh` every day at 02:15 as root, with its output going to
   `/var/log/backup.log`.
5. **Verify.** Write every file in the local backup to `/root/backup_list.txt`, as paths relative to
   `/srv/backup/app`, one per line.
6. **Restore drill.** Delete `/srv/app/config/app.conf`, restore it from the local backup with its
   content, owner (`app`) and mode (`640`) intact, then write `RESTORE_TESTED=yes`.
7. **The other cron job.** A cron job on this machine runs something from a temp directory. Write
   `SUSPICIOUS_CRON=<the cron file>`, then remove the cron file and the script it runs.

Check your work from the host: `./lab check backups-rsync-cron`

<details>
<summary>Hints</summary>

- Try every rsync with `-n -v` first. Mind the trailing slash on `/srv/app/`
- `ssh-keygen -t ed25519 -N ''`, `ssh-copy-id vault@backup`, then `ssh vault@backup true` should not ask
  anything
- `hostname`; `"$(hostname)"` works inside the script, and so does `--mkpath` for the first run
- `date -Is` (ISO 8601, seconds)
- `ls /etc/cron.d`; the cron.d format has a user field
- `cd /srv/backup/app && find . -type f`, then strip the leading `./`
- `rsync -a` or `cp -a` keeps owner and mode on restore; check with `ls -l`
- `grep -r /tmp /etc/cron.d /etc/crontab /var/spool/cron`

</details>

## My notes

<!-- Screenshots: ./lab shot backups-rsync-cron ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-101-capstone](../linux-101-capstone/): a first tar backup and crontab
- [linux-authentication](../linux-authentication/): SSH keys and ssh-copy-id
- [bash-traps-signals](../bash-traps-signals/): strict mode for scripts
- `man rsync`, `man 5 crontab`
