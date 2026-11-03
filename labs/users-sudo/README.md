# users-sudo

## Concepts

**sudo** is how ordinary accounts get root rights, so it's also where privilege escalation hides.
Accounts, groups and locking were covered in [linux-authentication](../linux-authentication/) and
[ownership-groups](../ownership-groups/). This lab is about sudo: granting exactly one command,
proving that nothing else works, and auditing every route to root on a machine.

**Accounts first**:
- `useradd -m -s /bin/bash NAME` creates the account, and `chpasswd` or `passwd` sets its password.
  An account created without a password already shows `!` in `/etc/shadow`, so locking it changes
  nothing.
- `passwd -l` (or `usermod -L`) locks the password by prefixing the hash with `!`. `passwd -S` shows
  `P` (usable), `L` (locked) or `NP` (no password).
- **Locking only stops password logins.** SSH keys still work, and so does sudo for any `NOPASSWD`
  rule. To really shut an account, also expire it (`chage -E 0`) or remove its shell.
- `chage -M 90 -W 14` sets the password lifetime and the warning period; `chage -l` lists them.

**Where sudo rights come from**: `/etc/sudoers`, every file in `/etc/sudoers.d/` (mode `0440`, and no
`.` or `~` in the name, or it's ignored), and group rules such as Ubuntu's `%sudo ALL=(ALL:ALL) ALL`.
Membership of the `sudo` group (`wheel` on RHEL) is therefore full root.

**Rule syntax**: `WHO HOST=(AS_USER[:AS_GROUP]) [NOPASSWD:] COMMANDS`

```
admin    ALL=(ALL:ALL) ALL                                  # anything, after a password
%ops     ALL=(root) NOPASSWD: /usr/local/bin/reload-web     # a group, one command, no password
```

Commands need their full path. Arguments written after the command must match exactly; with none
given, any arguments are allowed. When several rules match, the **last** one wins.

**Writing sudoers safely**:
- Always validate: `visudo -f file` edits with a check, and `visudo -c` checks everything. A broken
  sudoers file can lock everyone out of sudo.
- `sudo echo x > /etc/sudoers.d/f` fails, because your own shell opens the file before sudo runs. Use
  `... | sudo tee file`, or write a temp file, `visudo -cf` it, then `install -m 0440` it into place.

**Dangerous rules that look harmless**:
- *Shell escapes.* Many programs can run other commands: `less` and `vim` (`!sh`), `find -exec`,
  `awk`, `tar`, `git`, `python`. Allowing one of them as root is allowing everything. GTFOBins lists
  them.
- *Wildcards.* `* ` in sudoers arguments matches *any* characters, including `/` and spaces. So
  `/usr/bin/tail /var/log/*` also permits `/var/log/../../etc/shadow`. Name exact files.

**Auditing**: `sudo -l -U USER` (as root) lists what any user may run. For a whole machine, check every
human account, read every drop-in (`grep -r '' /etc/sudoers.d/`), and list the `sudo` group
(`getent group sudo`).

## Tasks

Start the lab with `./lab up users-sudo`, open a shell with `./lab shell users-sudo`. The shell is
`root`. Test as another user with `su <user> -c '...'`. Write `KEY=value` answers to
`/root/answers.txt`.

1. **The account.** Create `deployer` with a home directory and bash, and give it a password.
2. **Locked.** Lock deployer's password, keeping the hash.
3. **One command through sudo.** In `/etc/sudoers.d/deployer` (mode `0440`, valid for `visudo -c`), let
   deployer run `/usr/local/bin/reload-web` as root without a password, and nothing else. Then try it
   as deployer: does it work while the account is locked?
4. **Password aging.** Maximum password age 90 days, warning 14 days.
5. **Audit one account.** Save what `sudo -l -U deployer` reports to `/root/deployer_sudo.txt`.
6. **Every route to root.** Before you change anything else:
   - Write `FULL_ROOT=<every account that can run anything as root through sudo>`, comma-separated.
   - Write `SHELL_ESCAPE=<the account whose one allowed program can still start a root shell>`.

   Then close the routes that shouldn't exist:
   - `admin` keeps full sudo, with its password.
   - `intern`'s temporary migration rule goes.
   - `svc-backup` (a service account) doesn't belong in the `sudo` group.
   - `webdev` may only run `/usr/bin/tail -n 200 /var/log/web/access.log`.

Check your work from the host: `./lab check users-sudo`

<details>
<summary>Hints</summary>

- `echo 'deployer:<password>' | chpasswd`, `passwd -l`, `passwd -S`
- Write the rule to a temp file, `visudo -cf /tmp/file`, then
  `install -m 0440 -o root -g root /tmp/file /etc/sudoers.d/deployer`
- `su deployer -c 'sudo -n /usr/local/bin/reload-web'` and `su deployer -c 'sudo -n id'`
- `chage -M ... -W ...`, `chage -l deployer`
- `for u in admin svc-backup intern webdev; do sudo -l -U "$u"; done`,
  `grep -r '' /etc/sudoers.d/`, `getent group sudo`
- `gpasswd -d <user> <group>`; `visudo -c` after every change

</details>

## My notes

<!-- Screenshots: ./lab shot users-sudo ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-authentication](../linux-authentication/): passwd, shadow, locking and backdoor accounts
- [special-permission-bits](../special-permission-bits/): SUID, the other way to run as root
- `man sudoers`, `man visudo`, `man sudo` (`-l`, `-U`, `-n`), `man chage`, GTFOBins
