# linux-authentication

## Concepts

I've taken over a jump host from an admin who left in a hurry. Before I trust it, I need to understand
how it decides who may log in, clean up a few accounts, set up key-based access to the backup server,
and check whether anything was left behind on purpose.

**/etc/passwd** is world-readable and has one line per account with seven colon-separated fields:

```
name:password:UID:GID:comment:home:shell
nadia:x:1742:1742:Nadia, reporting:/home/nadia:/bin/dash
```

The `x` in the password field means "the hash lives in /etc/shadow". UID `0` is root, and the kernel only
looks at the number, so any account with UID 0 *is* root, whatever its name.

**/etc/shadow** is readable by root only. Its nine fields are: name, password hash, last change, minimum
age, maximum age, warning period, inactive period, expiry date and a reserved field. Dates are counted
in days since 1970-01-01. The prefix of the hash names the algorithm:

| Prefix | Algorithm |
|---|---|
| `$1$` | MD5 (obsolete, easy to crack) |
| `$2a$` / `$2y$` | bcrypt |
| `$5$` | SHA-256 |
| `$6$` | SHA-512 |
| `$y$` | yescrypt (Ubuntu's default) |

The password field can also hold a marker instead of a hash:
- `!` followed by a hash: the account is **locked**. The hash is kept, so unlocking just removes the `!`.
  Password login stops, but SSH keys and `su` from root still work.
- `!` on its own (Ubuntu) or `!!` (RHEL): no password has been set yet.
- `*`: no password will ever work (system accounts).

**usermod** changes an existing account: `-c` comment, `-s` shell, `-d` home (`-m` also moves the
files), `-g` primary group, `-G` supplementary groups (add `-a` to keep the existing ones), `-l` rename,
`-u` UID, `-L`/`-U` lock/unlock, `-e` expiry date.

**SSH keys** are a pair: the private key stays on the client (mode `600`, ideally encrypted with a
passphrase), the public key goes into `~/.ssh/authorized_keys` on each server. `ssh-copy-id` does that
for me using the account's password one last time. When I log in, the client proves it holds the
private key by signing a challenge; the passphrase only unlocks the key locally and never crosses the
network.

**Why it matters for incident response**: the same files are where attackers hide. Things to look for
are a second UID 0 account, MD5 hashes, accounts with a login shell and a home in a temp directory,
`authorized_keys` files with keys nobody recognises, and `.ssh` files that other users can write to.

## Tasks

Start the lab with `./lab up linux-authentication`, open a shell with `./lab shell linux-authentication`.
The shell is `root` on `jumphost`; the backup server is reachable as `server`.

1. **Read the account files.** Write `/root/answers.txt` with these four lines:

   ```
   NADIA_UID=<nadia's UID>
   NADIA_SHELL=<nadia's login shell>
   NADIA_HASH=<algorithm of nadia's password hash, e.g. md5, sha256, sha512, yescrypt>
   LOCKED_USER=<the one account that is already locked>
   ```

2. **Change accounts.**
   - `lena`: set the comment to `Lena Fischer`, the shell to `/bin/bash`, and add her to the group
     `backup`. She must stay in `staff-ops`.
   - Lock `tomas`'s password; his hash must be kept.
   - Make `intern` expire on `2026-12-31`.

3. **Key login to the backup server.**
   - Create an RSA key of 4096 bits for root at the default path, with the comment `backup-key` and the
     passphrase `BackupKey2026`.
   - Install it for `ops@server` (that account's password is `ops-pass`).
   - `ssh ops@server` should then ask only for the key's passphrase. The check logs in with the key and
     password login turned off.

4. **Hunt for backdoors.** Find these and write `/root/findings.txt`:

   ```
   UID0_ACCOUNT=<the account other than root that has UID 0>
   MD5_ACCOUNT=<the account whose hash is MD5>
   ODD_HOME_ACCOUNT=<the account with a login shell and a home outside /home and /root>
   ROGUE_KEY_COMMENT=<comment of the key in lena's authorized_keys that isn't hers>
   ```

   lena's only real key has the comment `lena@laptop`. Then fix them:
   - Remove the extra UID 0 account.
   - Lock the MD5 account.
   - Set the odd account's shell to `/usr/sbin/nologin`.
   - Remove the rogue key and keep lena's own.
   - Set lena's `.ssh` to `700` and `authorized_keys` to `600`, owned by lena.

Check your work from the host: `./lab check linux-authentication`

<details>
<summary>Hints</summary>

- `getent passwd <user>`, `getent shadow <user>`, `id <user>`, `chage -l <user>`
- `awk -F: '{print $1, $3, $7}' /etc/passwd` prints chosen fields; `awk -F: '$3 == 0' /etc/passwd`
  filters on one
- `usermod -c ... -s ... <user>`, `usermod -aG <group> <user>`, `usermod -L`, `usermod -e YYYY-MM-DD`
- `ssh-keygen -t rsa -b 4096 -C ...`, `ssh-keygen -lf <key>.pub`, `ssh-copy-id ops@server`
- `userdel` refuses to delete a UID 0 account because "it" is running processes (root's). `userdel -f`
  forces it.
- `cat -A` shows hidden characters; `ls -la ~lena/.ssh` shows the permissions

</details>

## My notes

<!-- Screenshots: ./lab shot linux-authentication ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-server-setup](../linux-server-setup/): creating users, groups and the first SSH key
- `man 5 passwd`, `man 5 shadow`, `man usermod`, `man ssh-keygen`, `man ssh-copy-id`
