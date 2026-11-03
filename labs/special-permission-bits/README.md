# special-permission-bits

## Concepts

On top of `rwx` for owner, group and others, Linux has three special bits, the fourth octal digit in
front of the usual three. [linux-file-permissions](../linux-file-permissions/) was about recognising
them. This lab sets them and watches what they do. The most dangerous of the three, SUID, is also one of
the first things an attacker looks for after getting a foothold.

| Bit | Octal | `ls -l` | On a program | On a directory |
|---|---|---|---|---|
| SUID | `4000` | `s` in the owner's x slot | Runs with the **owner's** UID as its effective UID | (no effect) |
| SGID | `2000` | `s` in the group's x slot | Runs with the file's group | New files inherit the **directory's group** |
| Sticky | `1000` | `t` in the others' x slot | (no effect) | Only a file's owner (or root) may delete or rename it |

A capital `S` or `T` means the special bit is set but the underlying `x` isn't, which is almost always
a mistake.

**SUID**: `passwd` is SUID root so ordinary users can update `/etc/shadow`. The process keeps its *real*
UID (who ran it) but gets an *effective* UID (whose rights it has). `id` shows both. Linux ignores SUID on
**scripts** (`#!` files), because they were too easy to abuse, so only compiled programs get it.
`install -m 4755 -o root src dest` copies and sets mode and owner in one step.

**SGID directories** are the classic team folder: with `chmod 2770` and the group set to the team,
everything created inside belongs to the team group, not to the creator's own primary group. For the
team to *edit* each other's files, those files also need group write, so members work with
`umask 002`.

**Sticky directories** (`1777`, like `/tmp`): everyone may create files, but nobody can delete
someone else's. Without the `t`, a world-writable directory lets any user delete or replace others'
files.

**Auditing**:
- `find /usr -xdev -perm -4000 -type f` lists SUID files. `-perm -4000` means "at least these bits",
  and `-xdev` stays on one filesystem.
- `dpkg -S FILE` names the package that installed a file. A SUID file that *no package* owns deserves
  a close look.
- Many ordinary tools become a root shell when they run SUID: `find` (via `-exec`), `vim`, `python`,
  `cp`, `bash -p`. The GTFOBins project catalogues them. So a renamed copy of one in an odd directory is
  a classic privilege-escalation backdoor.

## Tasks

Start the lab with `./lab up special-permission-bits`, open a shell with
`./lab shell special-permission-bits`. The shell is `root`. Users: `dana` and `omar` (group `devs`),
and `guest`. Run commands as another user with `su <user> -c '...'`. Write the `KEY=value` answers to
`/root/answers.txt`.

1. **SUID.**
   - Make `/usr/local/bin/whoami-root`: a copy of `/usr/bin/id`, owned by root, mode `4755`. Run it as
     `guest` and write `WHOAMI_EUID=<the value after euid=>`.
   - Then make a small **shell script** that prints `id -u`, give it mode `4755` as well, and run it as
     guest. Write `SCRIPT_SUID_WORKS=<yes or no>`.
2. **SGID directory.** Create `/srv/projects` for the `devs` group: `root:devs`, mode `2770`. A file that
   dana creates there must belong to `devs`, so that omar can edit it, as long as dana works with
   `umask 002`. guest gets no access.
3. **Sticky directory.** Create `/srv/dropbox`, mode `1777`. Anyone can drop files in, but nobody can
   delete someone else's.
4. **SUID audit.** Do this *after* task 5. Write every SUID file under `/usr`, sorted, one per line, to
   `/root/suid_list.txt`, and their number to `/root/suid_count.txt`.
5. **The backdoor.**
   - One SUID file under `/usr` wasn't installed by any package. Write `ROGUE_SUID=<its path>` and
     `ROGUE_IS=<which standard program it really is>`.
   - Then make sure no unpackaged SUID file is left under `/usr`: remove the backdoor *and* your own
     `whoami-root`. The packaged SUID programs stay.

Check your work from the host: `./lab check special-permission-bits`

<details>
<summary>Hints</summary>

- `install -m 4755 -o root -g root <src> <dest>`, then `su guest -c <program>`
- `ls -l` on your script after `chmod 4755`: the `s` is there, but what does it print as guest?
- `chgrp`, `chmod 2770`; test with `su dana -c 'umask 002; touch /srv/projects/x'` and `ls -l`
- Test the sticky bit: create a file as dana, try `rm` as guest
- `find /usr -xdev -perm -4000 -type f`, then `dpkg -S <file>` for each one
- `cmp <file> /usr/bin/<name>` says whether two programs are identical

</details>

## My notes

<!-- Screenshots: ./lab shot special-permission-bits ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-file-permissions](../linux-file-permissions/): reading modes and spotting special bits
- [posix-acls](../posix-acls/): access for named users and groups
- `man chmod` (SETUID AND SETGID BITS), `man find` (`-perm`), `man dpkg`, GTFOBins
