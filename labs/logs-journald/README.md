# logs-journald

## Concepts

Every incident leaves traces in the logs. The questions are always the same: what happened, when, from
where, and as whom. Modern Linux keeps two kinds of logs: the **systemd journal** (binary and
structured, read with `journalctl`) and plain-text files under `/var/log` that **logrotate** keeps from
growing forever. This lab's journal holds two real boots of a web server, `web-01`, including one bad
night. No systemd runs in the container; `journalctl` reads the journal files directly.

**journalctl filters** can be combined freely:

| Filter | Shows |
|---|---|
| `--list-boots`, `-b ID` | The recorded boots; one boot by its ID (`-b -1` is the one before the last) |
| `-k` | Kernel messages only (what `dmesg` shows on a live system) |
| `-u ssh.service` | One systemd unit |
| `-p err` | Priority err *and worse*: emerg, alert, crit, err. The numbers are 0 to 7 |
| `--since "2026-10-30 02:14:00" --until "..."` | A time window; also `"1 hour ago"`, `today`, `yesterday` |
| `-g PATTERN` | Messages matching a regular expression (journalctl's own grep) |
| `_UID=1001`, `_PID=955` | Any journal field |
| `-n 50`, `-e`, `-f` | Last 50 lines, jump to the end, follow live |
| `--no-pager`, `-q`, `-o short-iso` | Plain output for files and pipes, no `-- Boot ... --` banners, ISO timestamps |

`-b 0` (or plain `-b`) means "the boot this machine is running now". In a container, or when you
analyse a journal copied from another host, that boot isn't in the files, so look the ID up with
`--list-boots`.

**Plain-text logs**: `/var/log/auth.log` (logins, sudo; `secure` on RHEL) and `/var/log/syslog`
(`messages` on RHEL). Older days live in rotated files: `auth.log.1`, then compressed `auth.log.2.gz`,
and so on, where the highest number is the oldest. `zgrep`, `zcat` and `zless` read plain and gzipped
files alike, so one `zgrep pattern /var/log/auth.log*` covers every rotation.

**logrotate** runs daily from cron or a systemd timer. Each file in `/etc/logrotate.d/` describes some
logs:

```
/var/log/myapp/*.log {
    weekly          # or daily, monthly, or size 100M
    rotate 4        # keep 4 old logs
    compress        # gzip the rotated ones (delaycompress: not the newest)
    copytruncate    # copy, then empty the live file in place
    missingok
    notifempty
}
```

`copytruncate` is for programs that keep their log file open and can't be told to reopen it. The
alternative is `create` plus a `postrotate` script that signals the program. `logrotate -d FILE` is a
dry run that reports what would happen, **on stderr**, and changes nothing. `logrotate -f` forces a
rotation; `-s FILE` uses a separate state file, which is handy for tests.

## Tasks

Start the lab with `./lab up logs-journald`, open a shell with `./lab shell logs-journald`. The shell
is `root`. Use `--no-pager` whenever you redirect journalctl into a file. Write `KEY=value` answers to
`/root/answers.txt`.

1. **Boots.** Save the list of recorded boots to `/root/boots.txt`, and write
   `INCIDENT_BOOT=<the boot ID of 2026-10-30>`.
2. **Kernel messages.** Save the kernel messages of that boot to `/root/boot.log`, and write
   `KILLED_PROCESS=<the process the kernel killed>`.
3. **One unit, one time window.** Save the `ssh.service` entries from 02:14:00 to 02:16:00 on 2026-10-30
   to `/root/unit.log`. From them, write:
   - `ATTACKER_IP=<the address the failed logins come from>`
   - `FAILED_COUNT=<number of failed password attempts in that window>`
   - `BREACHED_USER=<the account that address then logged in as>`
   - `LOGIN_TIME=<the time of that login, HH:MM:SS>`
4. **Priority and grep.** Write `ERR_ENTRIES=<the number of journal entries of priority err or worse>`
   and `ROOT_COMMAND=<the command the intruder ran as root through sudo>`.
5. **Rotated plain-text logs.** Across `/var/log/auth.log` and all its rotations, compressed ones
   included, write `AUTH_FAILED_ALL=<the number of failed password lines>` and
   `AUTH_OLDEST_ATTACKER=<the source address in the oldest rotation>`.
6. **logrotate config.** Create `/etc/logrotate.d/orders` for `/var/log/orders/*.log`: rotate weekly,
   keep 4, compress, and use `copytruncate`. The check runs forced rotations on a copy of the config.
7. **Dry run.** Save the dry-run report for that config to `/root/lr.log`. The real log must not be
   rotated.

Check your work from the host: `./lab check logs-journald`

<details>
<summary>Hints</summary>

- `journalctl --list-boots --no-pager`, then `-b <id> -k`
- Put `-u`, `--since` and `--until` in one command; quote the timestamps
- `grep -c`, `grep -o 'from [0-9.]*'`, `sort | uniq -c`
- `journalctl -p err --no-pager -q | wc -l`; `journalctl -g 'COMMAND='`
- `ls -l /var/log/auth.log*`, `zgrep -h 'Failed password' /var/log/auth.log* | wc -l`
- `logrotate -d /etc/logrotate.d/orders`: where does the text go if `>` captures nothing?

</details>

## My notes

<!-- Screenshots: ./lab shot logs-journald ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-cli-intro](../linux-cli-intro/): grep, head and tail on plain logs
- [backups-rsync-cron](../backups-rsync-cron/): logging a cron job
- `man journalctl`, `man systemd.journal-fields`, `man logrotate`, `man zgrep`
