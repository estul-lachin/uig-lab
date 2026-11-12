# linux-file-permissions

## Concepts

A small print shop keeps its price list, order forms and invoice archive on one Linux server. The owner
wants each file readable by the right people only, and suspects the previous admin left a few things
open. Every file answers two questions: *who owns it* and *what may each class of user do with it*.

**Reading `ls -l`**: `-rwxr-x--- 1 pia printers ... price-list.txt`

- Character 1 is the type: `-` file, `d` directory, `l` symlink.
- Characters 2–4, 5–7 and 8–10 are the rights of the **owner**, the **group** and **others**.
  `r` read, `w` write, `x` execute (for a directory: may enter it). A `-` means not granted.
- Then the owner (`pia`) and the group (`printers`). A user who is neither gets the "others" rights.

**chmod, octal form**: r = 4, w = 2, x = 1, added up per class. `740` is owner `rwx` (4+2+1), group
`r--` (4), others `---` (0). The octal form **replaces** the whole mode.

**chmod, symbolic form**: `who` (`u` `g` `o` `a`), an operator (`+` add, `-` remove, `=` set exactly),
and the rights. It **only changes what I name**: `chmod g-w` removes group write and leaves every other
bit alone, which is why it's safer when I don't know the current mode.

**chown / chgrp**: `chown user file`, `chgrp group file`, or both at once with `chown user:group file`.
`-R` applies it to a whole directory tree. Giving files away needs root.

**Special bits** (a fourth octal digit in front):

| Bit | Octal | Shown as | Effect |
|---|---|---|---|
| SUID | 4000 | `s` in the owner's x slot | An executable runs as its **owner** (that's how `passwd` can edit /etc/shadow) |
| SGID | 2000 | `s` in the group's x slot | Runs as the file's group; on a directory, new files inherit its group |
| Sticky | 1000 | `t` in the others' x slot | In a directory, only a file's owner (or root) may delete or rename it, e.g. `/tmp` (`1777`) |

`find -perm /4000` matches files with *any* of those bits set (`/2000` SGID, `/1000` sticky).

**Why it matters for incident response**: a SUID copy of a shell in a writable directory is a root
backdoor; a world-writable cron file lets anyone run commands as root; a binary owned by an
unprivileged account can be swapped out by that account; a `/tmp` without the sticky bit lets users
delete each other's files.

## Tasks

Start the lab with `./lab up linux-file-permissions`, open a shell with `./lab shell linux-file-permissions`.
The shell is `root`. The users `pia` and `otto` (a member of group `printers`) and `guest` already exist.

1. **Create and inspect.** Create the empty file `/srv/print/price-list.txt` and look at it with
   `ls -l`. Write its permission string to `/root/answers.txt` as `INITIAL_PERMS=<like -rwx------>`.
2. **Octal mode.** Using numbers, give `price-list.txt` full rights for the owner, read-only for the
   group and nothing for others.
3. **Symbolic mode.** `/srv/print/order-form.txt` is currently `751`. Using the symbolic form, in one
   command: remove execute from the owner, set the group to exactly read+write, add read for others.
   Everything else must stay as it was.
4. **Ownership.** Make `price-list.txt` belong to user `pia` and group `printers` (try `chown` and
   `chgrp` separately). Then give the whole `/srv/print/archive` tree to `pia:printers` in one command.
   Afterwards `otto` should be able to read the price list and `guest` should not.
5. **Special bits.** Append three more lines to `/root/answers.txt`:

   ```
   PASSWD_SPECIAL=<suid, sgid or sticky: the special bit on /usr/bin/passwd>
   TMP_SPECIAL=<suid, sgid or sticky: the bit a normal /tmp carries>
   SGID_FILE=<the path of any file under /usr/bin that has the SGID bit>
   ```

6. **Permission audit.** Four things on this server are wrong. Find them and write
   `/root/findings.txt`:

   ```
   SUID_BACKDOOR=<a SUID file that shouldn't exist>
   WORLD_WRITABLE=<a world-writable file under /etc>
   BAD_OWNER=<a program in /usr/local/bin not owned by root>
   NO_STICKY=<a world-writable directory that is missing its sticky bit>
   ```

   Then fix them:
   - Remove the backdoor; the real SUID binaries must keep their bit.
   - Set the cron file to `644`.
   - Give the program to `root:root`.
   - Restore `/tmp` to `1777`.

Check your work from the host: `./lab check linux-file-permissions`

<details>
<summary>Hints</summary>

- `ls -l <file>`, `ls -ld <dir>`, `stat -c '%A %a %U:%G' <file>`
- `chmod 740 ...`, `chmod u-x,g=rw,o+r ...`
- `chown pia ...`, `chgrp printers ...`, `chown -R pia:printers ...`
- Test access as another user: `su -s /bin/sh otto -c 'cat /srv/print/price-list.txt'`
- `find / -xdev -perm /4000 -type f 2>/dev/null`, `find /etc /root -perm /002 -type f 2>/dev/null`,
  `find / -xdev -type d -perm -0002 2>/dev/null`

</details>

## My notes

<!-- Screenshots: ./lab shot linux-file-permissions ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

#### nano `⌃ + \` = Search and Replace

#### `vim` 
```bash
# Enter Insert mode
i
# Return to Normal mode
Esc
# Save
:w
# Quit
:q
# Save and quit
:wq
# Quit without saving
:q!
# Delete current line
dd
# Undo
u
# Replace all occurrences in the file
:%s/old/new/g
```

#### `cat`
```bash
# Display file contents
cat file.txt
# Create/overwrite a file
cat > file.txt
# Append to a file
cat >> file.txt
# Display with line numbers
cat -n file.txt
# Combine files into a new file
cat file1 file2 > file3
# Finish cat input
Ctrl + D
```
#### `echo` `printf`
```bash
# Write/overwrite
echo "Hello, World!" > a.txt

# Append
echo "Another line." >> a.txt

# Write two lines with TAB separation
printf "aaaaaaa\taaaaaaa\naaaaaaa\taaaaaaa\n" > a.tsv

# Write to file and display on screen
echo "aaaaaaa" | tee a.txt

# Append to file and display on screen
echo "bbbbbb" | tee -a seen.txt

# Write current date/time (overwrite)
date > a.txt

# Append another timestamp
date >> a.txt
```

## Related

- [hello-world](../hello-world/): octal permissions on a single file
- [linux-server-setup](../linux-server-setup/): users, groups and a `770` shared directory
- `man chmod`, `man chown`, `man chgrp`, `man find` (section `-perm`)
