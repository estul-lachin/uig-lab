# linux-101-capstone

## Concepts

This lab pulls the Linux basics together into one realistic ticket. Harbor Food Bank is moving its
small website to this host. The ticket asks for:

- a workspace
- the start page
- a private scripts folder
- the old deploy settings found and copied
- a nightly backup
- an account for the web admin
- the host's address written down for the DNS team

While I'm on the box, I also check that nobody has left a scheduled surprise behind.

New on top of the earlier labs:

**Brace expansion**: `mkdir -p site/{public,logs}` expands to `mkdir -p site/public site/logs`.

**Shell scripts**: a text file of commands. It needs two things to run as `./script.sh`: a **shebang** on
line 1 (`#!/bin/bash`, the interpreter to use) and the execute bit (`chmod +x`). `printf '...\n...\n' >
file` writes a short multi-line script in one go.

**tar**: `tar czf archive.tar.gz -C /base dir` creates (`c`) a gzip-compressed (`z`) archive file (`f`)
of `dir`, as seen from `/base`. `tar tzf archive.tar.gz` lists what's inside.

**Groups and users**: `groupadd -f` creates a group only if it doesn't exist yet. `useradd -m` creates
the home directory. `usermod -aG` adds a supplementary group; without `-a` it *replaces* the user's
other groups. `id user` shows the result.

**cron** runs commands on a schedule. Each user has their own crontab: `crontab -l` lists it, `-e`
edits it, `-r` deletes it, and `-u user` (as root) works on someone else's. A line is five time fields
and a command:

```
30  1  *  *  *   /root/site/scripts/backup.sh
min hr dom mon dow
```

`*/15` means every 15 units, and `@reboot` means once at every boot. `crontab -` replaces the whole
crontab with what it reads, so adding a line safely means feeding it the old crontab plus the new line:
`(crontab -l; echo 'line') | crontab -`.

**Why it matters for incident response**: cron is one of the most common ways to keep a foothold on
Linux. A responder lists every user's crontab (`/var/spool/cron/crontabs/`) and the system ones
(`/etc/crontab`, `/etc/cron.d/`). An `@reboot` line that connects to an outside address is a classic
reverse shell.

## Tasks

Start the lab with `./lab up linux-101-capstone`, open a shell with `./lab shell linux-101-capstone`.
The shell is `root`.

1. **Directory layout.** Create `/root/site` with four subdirectories: `public`, `scripts`, `backups`
   and `logs`. Use one command.
2. **index.html.** Create `/root/site/public/index.html` containing the single line
   `Welcome to Harbor Food Bank`.
3. **Permissions.** Make `/root/site/scripts` mode `750`.
4. **Hidden file.** The old deploy settings are in a hidden file somewhere on the system. Its name
   contains `deploy`. Find it and copy it to `/root/site/deploy.conf`.
5. **Backup script.** Write `/root/site/scripts/backup.sh`. When run, it must create
   `/root/site/backups/site.tar.gz` containing the `public` directory. Make it executable and run it once.
6. **User webadmin.** Create the user `webadmin` with a home directory and add them to the group
   `webteam`, which may not exist yet.
7. **IP address.** Write this host's IPv4 address to `/root/site/ip.txt`.
8. **Cron job.** Schedule `backup.sh` in root's crontab for every day at 01:30. Root already has a cron
   job; it must stay.
9. **Cron persistence.** One account has a cron job that connects to an outside host at every boot.
   Write `/root/findings.txt`:

   ```
   CRON_USER=<the account>
   CRON_TARGET=<IP:PORT it connects to>
   ```

   Then remove only that line, keeping the account's other job.

Check your work from the host: `./lab check linux-101-capstone`

<details>
<summary>Hints</summary>

- `mkdir -p /root/site/{public,scripts,backups,logs}`
- `find / -xdev -type f -name '*deploy*' 2>/dev/null`; a name that starts with `.` is hidden from `ls`
- `printf '#!/bin/bash\ntar czf ... -C /root/site public\n' > ...`, `chmod +x`, then
  `tar tzf /root/site/backups/site.tar.gz`
- `groupadd -f <group>`, `useradd -m <user>`, `usermod -aG <group> <user>`, `id <user>`
- `hostname -I`
- `crontab -l`, then `(crontab -l; echo '30 1 * * * /root/site/scripts/backup.sh') | crontab -`
- `ls /var/spool/cron/crontabs`, `crontab -l -u <user>`, then
  `crontab -l -u <user> | grep -v '<pattern>' | crontab -u <user> -`

</details>

## My notes

<!-- Screenshots: ./lab shot linux-101-capstone ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- The labs this one builds on: [linux-cli-intro](../linux-cli-intro/),
  [linux-file-management](../linux-file-management/), [linux-file-editing](../linux-file-editing/),
  [linux-file-permissions](../linux-file-permissions/), [linux-authentication](../linux-authentication/)
- `man 5 crontab`, `man tar`, `man find`
