# windows-ntfs-acls

## Concepts

To defend Windows you have to be able to answer "who can touch this file?" and "what is running on
this box?" without guessing.

**NTFS permissions.** Every file and folder on NTFS carries an **ACL** (access control list): a list of
entries (ACEs), each granting or denying a user or group a set of rights. Windows bundles the rights into
a few levels:

| Level | Allows | icacls | smbcacls |
|---|---|---|---|
| Read & Execute | Open, list, run; change nothing | `(RX)` | `READ` |
| Modify | Read, write, create, delete | `(M)` | `RWXD` |
| Full Control | Everything, including changing the ACL and taking ownership | `(F)` | `FULL` |

The difference between the last two matters: with Modify you can change the content, with Full Control
you can also change who else may.

**Inheritance.** A folder's entries can flow down to what is inside: **OI** (object inherit, to files)
and **CI** (container inherit, to subfolders). An entry that arrived this way is marked inherited
(`I`, or `(I)` in icacls). By default a folder inherits from its parent. Sensitive folders often turn
that off, so a generous parent can't loosen them: the ACL is then **protected**. You see it in the
Security tab (Advanced shows **Enable inheritance**), in SDDL as `D:P`, and in smbcacls as the `PD`
flag on the CONTROL line (`DI` means inheritance is on). Changing a folder's ACL doesn't by itself
rewrite the entries its existing files inherited; they have to be **propagated**.

**Owner.** Every object also has an owner, normally whoever created it. The owner can always change
the ACL, and for an investigator it is the first answer to "who put this file here?".

**Groups and nesting.** ACLs should name groups, not people. Groups can hold groups: when `All-Staff`
contains the department groups, a user gets its access through two hops. That's tidy, and also how
access spreads further than anyone intended.

**Reading ACLs.**

| Windows | Here (over SMB, as on any Linux admin box) |
|---|---|
| Properties > Security, Advanced | `smbcacls //dc01/Labs <path> -U Administrator` |
| `icacls C:\Labs\HR-Files` | the same; `ACL:<who>:ALLOWED/<flags>/<rights>` lines |
| `Get-Acl ... \| Format-List` (SDDL) | `samba-tool ntacl get <local path> --as-sddl --service=Labs` |
| Open the share as a user | `smbclient //dc01/Labs -U <user> -c "ls"` |

**Services, processes, the registry.** A **service** is a program Windows runs in the background,
without anyone logged on, with a startup type (Automatic, Manual, Disabled); `services.msc` lists
them. On a domain controller the important ones are **NTDS** (Active Directory Domain Services, the
directory database engine, `NTDS.dit`), **DNS Server**, **Netlogon** (secure channel and DC locator
records) and the **KDC** (Kerberos). Every running program is a **process**; the one every analyst
knows is **lsass.exe** (Local Security Authority Subsystem Service): it checks logons and keeps
credential material in memory, which makes it the classic credential-dumping target (Mimikatz,
procdump of lsass). The **registry** is Windows' configuration database, organised in hives;
machine-wide OS and service settings live in **HKEY_LOCAL_MACHINE** (HKLM), and many Group Policy
settings end up there.

**No local users on a DC.** A normal Windows machine keeps local accounts in the **SAM** (Security
Account Manager) database. Promoting a server to a domain controller removes its local SAM: from then on
every account is a domain account in `NTDS.dit`, and Computer Management has no Local Users and Groups.

**About this lab.** DC01 is a real AD domain controller (Samba 4) with a Windows file share. Samba
stores and enforces Windows ACLs (owners, inheritance, the same access masks), and Windows clients
see them in the Security tab as usual. There is no Task Manager or regedit, so those questions come
from the concepts above; the samba processes (`ps -ef`) play the roles of NTDS, KDC and Netlogon.

## Tasks

Start the lab with `./lab up windows-ntfs-acls`, open a shell with `./lab shell windows-ntfs-acls`. You are root on
**DC01** (`ridgeline.local`); its share **`//dc01/Labs`** (`/srv/labs` locally) has the folders
`HR-Files`, `Public` and `IT-Tools`. Every account's lab password is `Lab-AD-2026!`. Read the ACLs
over SMB as `Administrator`: root on the box sees every file, but the share is what users get. Write
the answers to `/root/answers.txt`, one `KEY=value` per line (case doesn't matter).

1. **Read the permissions.**

   ```
   HR_PERMISSION=<the level HR-Staff has on HR-Files>
   ADMIN_PERMISSION=<the level Domain Admins has on HR-Files>
   INHERITANCE=<enabled or disabled, on HR-Files>
   PUBLIC_PERMISSION=<the level All-Staff has on Public>
   FULL_CODE=<the icacls letter for Full Control>
   ```

2. **Read them closer.**

   ```
   PROTECTED_FLAG=<the smbcacls CONTROL flag that shows inheritance is off>
   MODIFY_LETTERS=<how smbcacls writes the Modify level>
   READ_VIA=<the group through which kfischer (Warehouse) can read Public>
   ```

3. **Windows internals.**

   ```
   AUTH_PROCESS=<the process that handles authentication and caches credentials>
   AD_SERVICE=<the short service name of Active Directory Domain Services>
   DC_REMOVED_DB=<the local account database removed when a server becomes a DC>
   REG_HIVE=<the registry hive, abbreviated, with machine-wide OS and service settings>
   ```

4. **The logon-script folder.** `IT-Tools` holds the script that maps everyone's drives at logon.

   ```
   WRITABLE_FOLDER=<the folder every domain user can change>
   WRITABLE_GROUP=<the group whose entry gives them that>
   PLANTED_FILE=<the file in it that IT didn't put there>
   PLANTED_BY=<the account that created it>
   ```

5. **Fix it.** Everybody must still be able to read the logon script, but only IT-Staff may change
   anything in `IT-Tools`: neither new files nor the existing script. Leave the planted file where it is;
   it's evidence.

Check your work from the host: `./lab check windows-ntfs-acls`

<details>
<summary>Hints</summary>

- `smbcacls //dc01/Labs HR-Files -U 'Administrator%Lab-AD-2026!'`; the same for the other folders and files
- Compare the CONTROL lines of a folder that inherits and one that doesn't
- `samba-tool group listmembers` shows direct members only; members can be groups
- A file that runs `powershell -w hidden` from a logon-script folder deserves a look at its OWNER
- `smbclient ... -U kfischer` with `put` tells you whether the fix works before the check does
- `smbcacls --help`: `-M` changes an existing entry; a separate option pushes a folder's inheritable
  entries down to what is already inside

</details>

## My notes

<!-- Screenshots: ./lab shot windows-ntfs-acls ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [ad-core-concepts](../ad-core-concepts/): the domain this share lives in
- [linux-file-permissions](../linux-file-permissions/) and [posix-acls](../posix-acls/): the Linux side of the same question
- MITRE ATT&CK T1222.001 (Windows File and Directory Permissions Modification), T1037.001 (Logon Script), T1003.001 (LSASS Memory)
