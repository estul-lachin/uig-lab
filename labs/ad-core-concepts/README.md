# ad-core-concepts

## Concepts

Active Directory (AD) is where a company keeps its identities: who exists, what they belong to, which
machines are trusted. That makes it the first thing an attacker wants to own, and you can't read an AD
attack without a map of what is in there.

**The hierarchy, outside in.**

| Level | What it is |
|---|---|
| **Forest** | The outermost container: one schema, one configuration, one Global Catalog. It is the real **security boundary**: domains inside the same forest trust each other automatically, so an admin of any one of them can reach the rest |
| **Tree** | Domains that share a contiguous DNS name (`corp.example`, `eu.corp.example`) |
| **Domain** | A boundary for administration and replication, with its own users, groups and computers, and a short **NetBIOS** name for the old `DOMAIN\user` form |
| **OU** (organizational unit) | A folder inside a domain for organising objects, delegating admin rights and linking **Group Policy** |
| **Object** | A user, computer, group, ... the leaves |

Not every folder is an OU. `CN=Users` and `CN=Computers` are plain **containers**, where new
accounts land when nobody picks an OU. Group Policy can't be linked to them, so a machine left there
gets only the domain-wide policies: often not the hardening its OU would have applied.

**Functional level.** The oldest Windows Server version a DC in the domain (or forest) may run, and so
the features it can use. Windows shows it as a name (`Windows2016Domain`); in the directory itself it is
a number in the **rootDSE**, the entry with no name that any client can read before logging in and that
describes the server: its naming contexts, its levels, whether it is a Global Catalog.

**The schema** is the blueprint: every object class (`user`, `computer`, `group`) and every attribute
AD can store. It is forest-wide, lives in its own naming context, and carries a version
(`objectVersion`) that rises with each Windows Server schema update. Windows shows it in the
Active Directory Schema snap-in (`schmmgmt.msc`).

**The Global Catalog** (GC) is a DC that also keeps a partial, read-only copy of every object in the
forest, so one search finds an object in any domain. It answers on its own ports:

| Service | Port | Over TLS |
|---|---|---|
| LDAP | 389 | 636 |
| Global Catalog | 3268 | 3269 |

Clients don't hardcode DCs: they ask DNS for **SRV records** (`_ldap._tcp.<domain>`,
`_kerberos._tcp.<domain>`, `_gc._tcp.<forest>`), and each answer names a host and a port. A modern DC
also refuses a password (simple) bind over plain LDAP, because the password would cross the network
in clear text. TLS (636/3269) or Kerberos is required.

**FSMO roles.** Most changes can be made on any DC and replicate. A few must happen in one place, so
five **Flexible Single Master Operation** roles are assigned to specific DCs:

| Scope | Role | Does |
|---|---|---|
| Forest | Schema Master | The only DC that can change the schema |
| Forest | Domain Naming Master | Adds and removes domains |
| Domain | RID Master | Hands out pools of relative IDs, the last part of every SID |
| Domain | PDC Emulator | Time source of the domain; gets password changes first and has the final say on a wrong password |
| Domain | Infrastructure Master | Keeps references to objects in other domains up to date |

In a domain with a single DC, it holds all five. `netdom query fsmo` lists them on Windows.

**Why the SOC cares.** The DC holds the database with every password hash. Knowing what normally talks
to it (LDAP on 389, GC on 3268, Kerberos, DNS) and what doesn't (a workstation asking for replication:
DCSync) is how you recognise reconnaissance and credential theft in the logs.

**About this lab.** DC01 is a real AD domain controller: Samba 4 speaks the same LDAP, Kerberos, DNS and
replication protocols as Windows, and Windows clients can join it. There is no PowerShell AD module or
MMC, so you use the Samba and LDAP tools instead:

| Windows | Here |
|---|---|
| `Get-ADForest`, `Get-ADDomain` | `samba-tool domain info 127.0.0.1`, the rootDSE |
| `(Get-ADDomain).DomainMode` | `samba-tool domain level show` |
| `netdom query fsmo` | `samba-tool fsmo show` |
| `schmmgmt.msc` | `ldbsearch` on the schema naming context |
| `Test-NetConnection dc01 -Port 3268` | `nc -zv dc01 3268` |
| `Resolve-DnsName -Type SRV` | `dig @127.0.0.1 SRV` |
| AD Users and Computers | `samba-tool ou`, `samba-tool computer`, `samba-tool user` |

## Tasks

Start the lab with `./lab up ad-core-concepts`, open a shell with `./lab shell ad-core-concepts`. You
are root on **DC01**, the domain controller of Ridgeline Outfitters (`ridgeline.local`). The domain
Administrator's lab password is `Lab-AD-2026!`. Write the answers to `/root/answers.txt`, one
`KEY=value` per line (case doesn't matter).

1. **The hierarchy.**

   ```
   FOREST=<the forest's name>
   BOUNDARY=<the level of the hierarchy that is the true security boundary>
   NETBIOS=<the domain's NetBIOS name>
   OU_TERM=<the abbreviation for the container used to organise objects and link Group Policy>
   ```

2. **Functional level.**

   ```
   FUNCTIONAL_LEVEL=<the Windows Server functional level of the domain>
   LEVEL_NUMBER=<the number the rootDSE uses for it (domainFunctionality)>
   ```

3. **The schema.**

   ```
   SCHEMA=<the name of the forest-wide definition of all classes and attributes>
   SCHEMA_VERSION=<its objectVersion>
   ```

4. **Global Catalog and LDAP.**

   ```
   GC_PORT=<the Global Catalog's TCP port>
   GC_TLS_PORT=<the same over TLS>
   GC_SRV=<the DNS name a client looks up to find a Global Catalog for this forest>
   BIND_RESULT=<the LDAP result code when Administrator binds with a password over plain ldap://>
   ```

5. **FSMO roles.**

   ```
   FSMO_COUNT=<how many FSMO roles AD defines, digits only>
   FSMO_HOLDER=<the DC that holds all of them here>
   FSMO_LISTED=<how many roles samba-tool fsmo show lists>
   TIME_ROLE=<the role that is the domain's time source>
   ```

6. **Organising objects.** One computer was joined without an OU.

   ```
   MISPLACED=<its name>
   ```

   Create an OU named **Contractors** under `OU=Ridgeline`, and move that computer into
   `OU=Workstations`, where its policies apply.

Check your work from the host: `./lab check ad-core-concepts`

<details>
<summary>Hints</summary>

- `samba-tool --help` lists the command groups; most have `list`, `show` and `--help`
- `ldapsearch -x -s base -b ""` reads the rootDSE anonymously; add attribute names to see more than the
  defaults (`schemaNamingContext`, `domainFunctionality`, ...)
- `ldbsearch -H /var/lib/samba/private/sam.ldb` reads the directory database directly, as root
- For the bind, ask `ldapsearch` for a simple bind as `Administrator@ridgeline.local` with the password;
  try `ldap://` and `ldaps://` (`LDAPTLS_REQCERT=never` accepts the lab's self-signed certificate)
- `samba-tool fsmo show` lists more lines than five: look at what the extra roles are named
- `-s one -b CN=Computers,...` lists only what sits directly in the default container

</details>

## My notes

<!-- Screenshots: ./lab shot ad-core-concepts ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [powershell-basics](../powershell-basics/): querying AD users and groups with Get-ADUser
- [dns-resolution](../dns-resolution/): how names and records are resolved
- MITRE ATT&CK T1087.002 (Account Discovery: Domain Account), T1482 (Domain Trust Discovery), T1003.006 (DCSync)
