# posix-acls

## Concepts

Classic permissions give me exactly three classes: one owner, one group, everyone else. Real requests
don't fit that: "the external auditor needs read access to the case folder, but must not join the
group and must not see anything else." Adding people to groups for one directory makes groups
meaningless. **POSIX ACLs** (access control lists) attach extra entries for named users and groups to a
single file or directory.

**Reading an ACL**: `ls -l` shows a `+` after the mode (`drwxr-x---+`) when a file has one. `getfacl`
prints it:

```
# file: srv/casework
# owner: root
# group: root
user::rwx                  <- the owner
user:auditor:r-x           <- a named user
group::r-x                 <- the owning group
mask::r-x                  <- the most any named entry or the group may get
other::---
default:user:auditor:r--   <- inherited by new files created inside
```

**Setting entries**:
- `setfacl -m u:NAME:rx PATH` adds or changes an entry; `g:NAME:...` does the same for a group.
- `setfacl -x u:NAME PATH` removes one entry, and `setfacl -b PATH` removes all of them.
- `-R` works recursively.
- `-d` acts on the **default ACL** of a directory: the template that new files and subdirectories
  inherit. It doesn't change anything that already exists.

**The mask** caps every named user, every named group and the owning group. The rights that apply are
the entry AND the mask, and getfacl shows them as `#effective:`. When an ACL exists, `ls -l` and
`chmod` show and change the *mask* in the group position, so `chmod g-w` quietly takes write away from
every named entry too. `setfacl -m` recalculates the mask to fit the entries unless told otherwise.

**Default ACLs and new files**: a new file gets the default entries, limited by what the creating
program asks for. Most programs create files without `x`, so a default `rwx` usually becomes `rw-`
on files.

**Why it matters for hardening and incident response**: an ACL is invisible in a quick `ls -l`, apart
from one `+`. A single `setfacl` can expose a sensitive file to an account without touching the owner,
group or mode that a review would look at. `getfacl -R -s -p /path` lists only the files that have
extended ACLs, which makes this quick to audit.

## Tasks

Start the lab with `./lab up posix-acls`, open a shell with `./lab shell posix-acls`. The shell is
`root`. The users `auditor`, `intern`, `finn` and `hana` (in group `hrteam`) exist. Write the
`KEY=value` answers to `/root/answers.txt`.

1. **Target directory.** Create `/srv/casework`, owned by `root:root` with mode `750`.
2. **Access ACL.** Without changing the owner, group or mode, give `auditor` read and enter access
   (`r-x`) to `/srv/casework`. auditor must not be able to create files there, and other users still
   get nothing.
3. **Default ACL.** Make every file created in `/srv/casework` from now on readable, but not writable,
   by `auditor`.
4. **Verify.** Save the output of `getfacl /srv/casework` to `/root/acl.txt`, after tasks 2 and 3.
5. **Reading effective rights.** `/srv/hr/budget.csv` has an ACL entry for `finn`. Write
   `FINN_EFFECTIVE=<the rights that actually apply, like r-x>` and `FINN_CAN_WRITE=<yes or no>`. Check
   the second one by trying.
6. **A quiet exposure.** Under `/srv/hr` (HR's share, group `hrteam`), one sensitive file has been
   opened up to a user who has no business there. Write `EXPOSED_FILE=<full path>` and
   `EXPOSED_TO=<user>`. Then remove that user's ACL entries under `/srv/hr`, keeping every other ACL
   and the owner, group and modes as they are.

Check your work from the host: `./lab check posix-acls`

<details>
<summary>Hints</summary>

- `ls -ld /srv/casework` shows the `+`; `getfacl /srv/casework`
- `setfacl -m u:<user>:<rights> <path>`; for the default ACL, add `-d`
- Test as the user: `su auditor -c 'ls /srv/casework'`, and `touch` a file as root, then try
  `cat` as auditor
- `getfacl /srv/hr/budget.csv`: compare the `user:finn` entry with `mask::`
- `getfacl -R -s -p /srv/hr`, then `setfacl -x u:<user> <path>` on each place it appears

</details>

## My notes

<!-- Screenshots: ./lab shot posix-acls ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-file-permissions](../linux-file-permissions/): owner, group, others and the special bits
- [linux-server-setup](../linux-server-setup/): sharing a directory through a group
- `man setfacl`, `man getfacl`, `man 5 acl`
