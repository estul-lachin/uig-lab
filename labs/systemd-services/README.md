# systemd-services

## Concepts

systemd boots almost every modern Linux system and supervises its long-running programs. It starts
them, restarts them when they die, runs them as the right user and sends their output to the journal.
Anything that keeps a program alive is also exactly what an attacker wants for persistence. Unlike
most labs here, this container runs **real systemd as PID 1**, so every `systemctl` command works.

**systemctl verbs**:
- `status`, `start`, `stop`, `restart`, and `reload` (re-read the config without a restart, if the
  program supports it).
- `enable` / `disable` decide whether it starts at boot. `enable --now` also starts it.
- `is-active`, `is-enabled`, `is-failed` are one-word answers for scripts.
- `list-units --type=service`, `--failed`, and `list-unit-files --state=enabled`.
- `cat UNIT` shows the unit *and* its drop-ins; `show -p MainPID --value UNIT` shows one property.

**Unit files** live in `/lib/systemd/system/` (shipped by packages; don't edit them) and
`/etc/systemd/system/` (yours; these win). A service:

```ini
[Unit]
Description=What it is
After=network.target          # ordering only

[Service]
ExecStart=/usr/local/bin/prog # absolute path; no shell features unless you run a shell
User=prog                     # don't run as root without a reason
Restart=on-failure            # restart after a crash or kill, not after a clean exit
Environment=KEY=value

[Install]
WantedBy=multi-user.target    # what `enable` hooks it into
```

After **any** change to a unit file, run `systemctl daemon-reload`, then restart the service. A running
process keeps its old settings until it's restarted.

**enable is a symlink**: `systemctl enable x.service` creates
`/etc/systemd/system/multi-user.target.wants/x.service -> /etc/systemd/system/x.service`. That's also
why an attacker who can write files as root can make something start at every boot without ever
running `systemctl`.

**Drop-ins** change a unit without editing it. `systemctl edit x` creates
`/etc/systemd/system/x.service.d/override.conf`. It merges with the main file and survives package
upgrades.

**Troubleshooting**: `systemctl --failed`, then `systemctl status x` (exit code and last log lines), then
`journalctl -u x`. A failed `oneshot` service stays failed until it's fixed and restarted (or
`systemctl reset-failed`).

**For incident response**: list what is enabled and what it runs. Then check whether each unit file
belongs to a package (`dpkg -S file`). A unit in `/etc/systemd/system` with a system-looking name, no
package, `Restart=always` and a network connection in `ExecStart` is a classic backdoor. Removing it
means: stop and disable it, delete the file, and `daemon-reload`.

## Tasks

Start the lab with `./lab up systemd-services`, open a shell with `./lab shell systemd-services`. The
shell is `root` on `app-01`. This container needs extra rights to run systemd (a writable cgroup tree,
`SYS_ADMIN`), so it's only meant for your own machine. Write `KEY=value` answers to
`/root/answers.txt`.

1. **The program.** Write `/usr/local/bin/heartbeat.sh`: forever, print a line containing `heartbeat`,
   then sleep for `$INTERVAL` seconds (default 5).
2. **The unit.** Write `/etc/systemd/system/heartbeat.service` with a description, `ExecStart` pointing
   at the script, and an `[Install]` section for `multi-user.target`.
3. **Running, enabled, as its own user.** It runs as the system user `heartbeat` (create it, no login
   shell), is started now and enabled at boot, and its output shows up in the journal.
4. **Restart policy.** If its process is killed, systemd starts it again. The check does a `kill -9`.
5. **Drop-in override.** Set `INTERVAL=2` for the service with a drop-in, not by editing the unit
   file, and make the running process actually use it. Save `systemctl cat heartbeat` to
   `/root/unit.txt`.
6. **The failing unit.** One enabled service failed at boot. Find out why, write
   `FAILED_REASON=<the path systemd couldn't execute>`, fix the unit and get it active.
7. **The backdoor service.** One enabled service was installed by neither a package nor you. (The
   symlinks to `/dev/null` in `/etc/systemd/system` are units this lab *masked* because they make no
   sense in a container; leave them.) Write
   `BACKDOOR_UNIT=<its name>` and `BACKDOOR_TARGET=<the IP:PORT it connects to>`. Then get rid of it
   completely, so it's not running, not enabled, not on disk and not known to systemd.

Check your work from the host: `./lab check systemd-services`

<details>
<summary>Hints</summary>

- `useradd -r -s /usr/sbin/nologin heartbeat`; `systemd-analyze verify <unit file>` finds typos
- `systemctl daemon-reload`, `systemctl enable --now heartbeat`, `systemctl status heartbeat`
- `systemctl show -p MainPID --value heartbeat`, then `ps -o user= -p <pid>`
- `systemctl edit heartbeat` (or create the `.service.d/override.conf` yourself), then reload and
  restart. `cat /proc/<pid>/environ | tr '\0' '\n'` shows what the process got
- `systemctl --failed`, `journalctl -u report --no-pager`
- `systemctl list-unit-files --state=enabled`, `systemctl cat <unit>`, `dpkg -S <file>`;
  `systemctl disable --now`, then remove and `daemon-reload`

</details>

## My notes

<!-- Screenshots: ./lab shot systemd-services ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [logs-journald](../logs-journald/): reading the journal
- [linux-101-capstone](../linux-101-capstone/), [backups-rsync-cron](../backups-rsync-cron/): cron, the
  other way to run things on a schedule
- `man systemctl`, `man systemd.service`, `man systemd.unit`, `man systemd.exec`
