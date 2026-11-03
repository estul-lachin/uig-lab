# ownership-groups

## Concepts

Groups are how Linux shares files without making them public. A team gets a group, the members join it,
and shared files belong to that group. This lab manages a small team end to end. It also covers two
ways ownership goes quietly wrong in practice: a `chown` that follows a symlink out of the directory,
and files whose owner no longer exists.

**Groups**: `/etc/group` has one line per group, `name:x:GID:member,member`.
- Every user has one **primary** group (in `/etc/passwd`, used for files they create) and any number of
  **supplementary** groups (listed in `/etc/group`). `id user` shows both.
- `groupadd -g 3000 devs` creates a group with a fixed GID. Fixed GIDs keep ownership consistent across
  servers and NFS shares.
- `usermod -aG devs alice` or `gpasswd -a alice devs` adds a member. `gpasswd -d bob devs` removes one,
  and leaves bob's other groups alone. (`usermod -G` without `-a` would replace all of them.)
- Group changes apply at the next login. An already-open shell keeps its old groups until it logs in
  again, or uses `newgrp`.

**chown and chgrp**: `chown user:group file`, `chown :group file` or `chgrp group file`. Only root can
give a file away.

**Symlinks and chown**: by default `chown` on a symlink changes the file the link **points to**. `chown
-h` changes the link itself.
- `chown -R` doesn't follow symlinks it meets *inside* the tree (`-P` is the default). It changes the
  links themselves, which is safe.
- `chown root:devs /srv/shared/*/*`, or `chown -R -L`, follows them.
- So if someone has planted `latest -> /etc/shadow` in a shared folder, the wrong command makes the
  password hashes group-readable by the whole team. Look for links before re-owning a tree that other
  people can write to.

**Orphaned files**: deleting an account doesn't delete its files. They keep the old numeric UID, which
`ls -l` shows as a bare number. A new account that later gets the same UID silently owns them.
`find / -xdev -nouser -o -nogroup` lists them; after a review, hand them to a real owner.

## Tasks

Start the lab with `./lab up ownership-groups`, open a shell with `./lab shell ownership-groups`. The
shell is `root`. `bob` (also in group `ops`) and `carol` already exist. Test access with
`su <user> -c '...'`. Write `KEY=value` answers to `/root/answers.txt`.

1. **Group.** Create the group `devs` with GID `3000`.
2. **Members.**
   - Create the user `alice` with a home directory and her own primary group, and add her to `devs`.
   - Add `bob` to `devs` as well.
   - Then bob leaves the team: remove him from `devs` only. He stays in `ops`.
3. **Shared file.** Create `/srv/shared/notes.txt` with group `devs` and mode `660`. alice can write to
   it; carol can't even read it.
4. **Recursive chown, safely.**
   - Someone left a symlink inside `/srv/shared`. Find it, and write `PLANTED_LINK=<its path>`.
   - Look at where it points before you do anything else, then remove it.
   - Make everything under `/srv/shared` owned by `root:devs` in one command.
   - `/etc/shadow` must still be `root:shadow` at the end.
5. **Orphaned files.**
   - Find every file on the root filesystem whose owner or group no longer exists. Write their paths,
     sorted, to `/root/orphans.txt`.
   - Then give them to `root:root`; don't delete them.

Check your work from the host: `./lab check ownership-groups`

<details>
<summary>Hints</summary>

- `groupadd -g`, `getent group devs`
- `useradd -m`, `usermod -aG`, `gpasswd -d`, `id <user>`
- `chgrp`, `chmod 660`; `su carol -c 'cat /srv/shared/notes.txt'`
- `find /srv/shared -type l -ls`; `readlink <link>`; `chown -R` (not `-L`)
- `ls -l /etc/shadow` before and after
- `find / -xdev \( -nouser -o -nogroup \) 2>/dev/null`; `ls -ln` shows the numbers

</details>

## My notes

<!-- Screenshots: ./lab shot ownership-groups ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-server-setup](../linux-server-setup/), [linux-file-permissions](../linux-file-permissions/)
- [special-permission-bits](../special-permission-bits/): SGID team directories
- `man chown` (`-h`, `-R`, `-L`, `-P`), `man gpasswd`, `man 5 group`
