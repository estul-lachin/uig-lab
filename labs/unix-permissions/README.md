# unix-permissions

## Concepts

The basics of `chmod` were covered in [hello-world](../hello-world/) and
[linux-file-permissions](../linux-file-permissions/). This lab is about the parts that cause real
mistakes:
- what the symbolic form leaves alone
- how to fix a whole tree without making every file executable
- where new files get their modes from
- what `r`, `w` and `x` actually allow on a *directory*

Everything is checked by acting as other users, because a mode that looks right isn't necessarily
right.

**Octal vs symbolic**:
- `chmod 750 f` sets everything at once.
- `chmod u+x,g+x f` changes only what it names. From `644` it gives `754`, while a plain `chmod +x`
  would also give others `x` (`755`).
- `o=` means "others: nothing", and `go-w` removes write from group and others.

**Capital X**: in symbolic mode, `X` adds execute *only* to directories, and to files that already have
an `x` somewhere. `chmod -R g+rX dir` lets the group into every subdirectory and read every file,
without turning documents into "programs". A lower-case `x` with `-R` hits every file.

**umask** is the set of bits taken *away* from new files and directories. Programs ask for `666` for
files and `777` for directories, then the umask is removed:
- umask `022` gives files 644 and directories 755.
- umask `027` gives 640 and 750: the group can read, others get nothing.

`umask` shows or sets the value for the current shell; put it in `~/.profile` to make it last for
login shells. A file created with a loose umask and then `chmod`ed is briefly readable, so files that
must be private from the start are better created private: `install -m 600 /dev/null file`, or
`(umask 077; ...)`.

**Directory bits** mean something different from file bits:

| Bit | On a directory |
|---|---|
| `r` | Read the *names* in it (`ls`) |
| `w` | Create, delete and rename entries in it. Needs `x` too |
| `x` | Enter it and reach the files inside by name (`cd`, `cat dir/file`) |

So `r` without `x` lists names but can't open anything inside, and `wx` without `r` is a blind drop
box. Because deleting a file changes the *directory*, not the file, `w` on a directory lets someone
delete files they can't even read, unless the directory has the sticky bit (see
[special-permission-bits](../special-permission-bits/)).

## Tasks

Start the lab with `./lab up unix-permissions`, open a shell with `./lab shell unix-permissions`. The
shell is `root`; you work on kai's files in `/home/kai`. Users: `kai`, `lee` (group `crew`) and `zoe`.
Test with `su <user> -c '...'`. Write the answers for task 6 to `/root/answers.txt` as `KEY=yes` or
`KEY=no`.

1. **Secret file.** `/home/kai/secret.txt`, owned by kai, mode `600`. Only kai can read or write it.
2. **Team directory.** `/home/kai/team`, owned by `kai:crew`, mode `750`. lee can list it but not create
   files in it; zoe can't list it.
3. **Script, symbolically.** Create `/home/kai/bin/hello.sh` (shebang, then `echo hi`) as mode `644`,
   group `crew`. Then add execute for the owner and the group with *symbolic* chmod, so it ends up `754`.
   lee can run it; zoe can't.
4. **The project tree.** `/home/kai/project` is far too open. In as few commands as possible:
   - Remove every permission for *others*, recursively.
   - Let the crew enter every subdirectory and read every file.
   - Make sure no file becomes executable. The files' owner and group bits must otherwise stay as
     they are.
5. **umask.** Make kai's login shells use umask `027`, so that new files are `640` and new
   directories `750`.
6. **What a directory's bits mean.** `/srv/listonly` is `744` and `/srv/dropbox` is `733`, both owned by
   root. Work out the answers, then check each one by trying it as zoe:

   ```
   LISTONLY_LS=<can zoe list the names in /srv/listonly?>
   LISTONLY_CAT=<can zoe read /srv/listonly/report.txt?>
   DROPBOX_LS=<can zoe list /srv/dropbox?>
   DROPBOX_CREATE=<can zoe create a file in /srv/dropbox?>
   DROPBOX_DELETE=<can zoe delete /srv/dropbox/existing.txt (root's, mode 644)?>
   ```

   If you delete `existing.txt` while testing, recreate it as root.

Check your work from the host: `./lab check unix-permissions`

<details>
<summary>Hints</summary>

- `install -m <mode> -o <user> -g <group> /dev/null <file>` creates a file with its final mode at once
- `stat -c '%a %A %U:%G' <path>`, `ls -ld <dir>`
- `chmod u+x,g+x`; compare with what `chmod +x` would do
- `chmod -R` accepts several clauses at once, separated by commas: `o-rwx,g+rX`
- `su kai -c 'bash -lc umask'`
- `su zoe -c 'ls /srv/listonly'`, `su zoe -c 'cat /srv/listonly/report.txt'`, `su zoe -c 'touch /srv/dropbox/zoe.txt'`

</details>

## My notes

<!-- Screenshots: ./lab shot unix-permissions ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-file-permissions](../linux-file-permissions/), [special-permission-bits](../special-permission-bits/),
  [posix-acls](../posix-acls/), [ownership-groups](../ownership-groups/)
- `man chmod` (SYMBOLIC MODES), `help umask`
