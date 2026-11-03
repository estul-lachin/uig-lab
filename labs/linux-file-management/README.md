# linux-file-management

## Concepts

I'm the analyst on a suspected intrusion, and my case folder `/root/casefiles` needs tidying before
the handover: a new reports folder, old drafts deleted, the evidence backed up, notes moved, one
directory to locate and a keyword to search for. Every other Linux skill builds on these commands.

**Create**: `touch file` makes an empty file (or updates the timestamp of an existing one),
`mkdir dir` makes a directory, `mkdir -p a/b/c` makes the whole path at once.

**Remove**: `rm file` deletes a file, `rmdir dir` deletes a directory only if it is empty, and `rm -r dir`
deletes a directory with everything below it. There is no recycle bin: `rm -i` asks before each
deletion, which is cheap insurance when evidence is involved.

**Copy, move, rename**: `cp src dest` copies, `cp -r` copies a directory tree. `mv src dest` moves, and
moving to a new name in the same directory is how Linux renames. A destination that is an *existing
directory* means "put it inside", so `cp -r evidence backup` creates `backup/evidence` when `backup`
exists but `backup` itself when it doesn't. Both `cp` and `mv` overwrite silently; `-i` makes them ask.

**Find by name**: `find <where> -name 'pattern'` walks the tree; `*` is a wildcard and the quotes stop
the shell from expanding it first. `-type f` limits to files and `-type d` to directories.

**Search contents**: `grep -r 'word' dir` prints every matching line with its file name, `-l` prints
only the file names (one per file), `-n` adds line numbers and `-i` ignores case. A file with two
matching lines prints twice without `-l`, so count files with `grep -rl ... | wc -l`.

**Why it matters for incident response**: `find / -mtime -1` lists files changed in the last day,
`find / -perm /4000` lists SUID files, and `grep -r '@reboot' /etc/cron.d` shows what starts on its own at
every boot, a common way for an attacker to keep a foothold.

## Tasks

Start the lab with `./lab up linux-file-management`, open a shell with `./lab shell linux-file-management`.
The shell is `root`; everything happens in `/root/casefiles`.

1. **Create**: a directory `reports` in `casefiles`, with an empty file `summary.txt` inside it.
2. **Remove**: delete `casefiles/old-drafts` and everything in it.
3. **Copy**: copy `casefiles/evidence` with its contents to `casefiles/backup/evidence`. The original
   stays where it is.
4. **Move and rename**: in one command, move `casefiles/notes.txt` to `casefiles/reports/timeline.txt`.
5. **Find by name**: somewhere under `casefiles` is a *directory* named `nightowl`. Write its full path
   to `/root/answers.txt` as `NIGHTOWL_PATH=<path>`.
6. **Search contents**: how many files in that `nightowl` directory contain the lower-case word
   `beacon`? Append `BEACON_FILES=<number>`.
7. **Persistence**: one file in `/etc/cron.d` runs a program at every boot. Append
   `REBOOT_JOB=<full path of that file>`.

Check your work from the host: `./lab check linux-file-management`

<details>
<summary>Hints</summary>

- `ls -l`, `ls -R` and `tree`-like `find <dir>` show what you have
- `mkdir`, `touch`, `rm -r`, `rmdir`, `cp -r`, `mv`; add `-i` while practising
- `find /root/casefiles -name 'nightowl'`, then check `-type d`
- `grep -r beacon <dir>` vs `grep -rl beacon <dir>`; pipe into `wc -l`
- `grep -r '@reboot' /etc/cron.d`

</details>

## My notes

<!-- Screenshots: ./lab shot linux-file-management ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-file-permissions](../linux-file-permissions/): `find -perm` and permission audits
- `man find`, `man grep`, `man cp`, `man mv`, `man rm`
