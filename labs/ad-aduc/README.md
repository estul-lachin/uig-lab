# ad-aduc

## Concepts

Active Directory Users and Computers (**ADUC**, `dsa.msc`) is the console where day-to-day identity
lives: users, the groups that organise them, and computer accounts. Half of AD investigation is just
reading these objects correctly.

**A user.** Each account has a few fields that matter in an investigation:

- **UPN** (User Principal Name) — the modern `user@domain` login, e.g. `alice@ridgeline.local`.
- **SID** (Security Identifier) — the unique, immutable ID Windows actually uses. Names and group
  memberships change; the SID does not. It is generated per domain, so it is **different on every
  build of this lab** — read it from the live box, don't memorise it.
- **Enabled / disabled** — a disabled account (shown with a down-arrow in ADUC) still exists but can't
  log on. Keeping a leaver disabled rather than deleted preserves the audit trail; here `ivan`, a
  former intern, is disabled.
- **Member Of** — the groups the user belongs to, which is where privilege comes from.

**A group has a type and a scope.**

- **Type** — **Security** (can be granted permissions) or **Distribution** (an email list, no
  permissions). Real access groups must be Security.
- **Scope** — **Global** (holds members from its own domain; used to group people by role or
  department), **Domain Local** (used to grant access to a resource), or **Universal** (forest-wide).
  The department groups here (`IT-Admins`, `HR-Staff`, `Finance-Team`, `Sales-Team`) are **Global
  Security** groups.

**Group nesting.** A group can contain another group. `All-Staff` holds the four department groups,
not individual people, so adding someone to their department group automatically makes them part of
`All-Staff`. This "group-in-group" model is how real directories stay manageable — and it is also how
privilege is often inherited indirectly, through a nested group rather than direct membership.

**Computers are objects too.** `WS01`, `WS02` (Workstations), `FILE01` (Servers) and the DC itself all
have accounts in the directory.

**Why the SOC cares.** The recurring questions are exactly these: is this account enabled? What groups
is it in? Is it **unexpectedly in a privileged group**? An ordinary user who suddenly appears in
**Domain Admins** is one of the most important detections in AD — whether added directly or inherited
through a nested group. Recognising "this member doesn't belong here" is the whole game.

**About this lab.** DC01 is a real AD domain controller (Samba 4). ADUC and the Attribute Editor are
Windows GUIs; here you read the same objects and attributes with `samba-tool user`, `samba-tool group`
and `samba-tool computer`, which show the real UPN, SID, group type/scope and memberships.

## Tasks

Start the lab with `./lab up ad-aduc`, open a shell with `./lab shell ad-aduc`. You are root on
**DC01** (`ridgeline.local`), the Corp directory of Ridgeline Outfitters; the domain Administrator's
lab password is `Lab-AD-2026!`. Write the answers to `/root/answers.txt`, one `KEY=value` per line
(case doesn't matter).

1. **The console and a user.**

   ```
   ADUC_CONSOLE=<the .msc that opens Active Directory Users and Computers on Windows>
   ALICE_UPN=<alice's User Principal Name>
   ALICE_SID=<alice's SID, read from this box>
   ```

2. **Groups.**

   ```
   GROUP_SCOPE=<the scope of the Sales-Team group>
   GROUP_TYPE=<the type of the Corp groups, so they can hold permissions>
   NESTING_COUNT=<how many groups are nested inside All-Staff>
   ```

3. **Accounts.**

   ```
   FRANK_TITLE=<the Title attribute on user frank>
   FINANCE_HEADCOUNT=<how many user accounts are in the Finance OU>
   DISABLED_USER=<the disabled account (the former intern)>
   PRIVILEGED_ACCOUNT=<the IT admin who is meant to be in Domain Admins>
   ```

4. **Find the account that doesn't belong.** Someone added a second account straight into Domain
   Admins. It isn't an IT admin.

   ```
   ROGUE_ADMIN=<its name>
   ```

   Remove it from Domain Admins, and leave the legitimate members alone.

Check your work from the host: `./lab check ad-aduc`

<details>
<summary>Hints</summary>

- `samba-tool user show alice --attributes=userPrincipalName,objectSid,title`
- `samba-tool user list --full-dn` prints every user's DN, so you can count a single OU
- `samba-tool group listmembers All-Staff` — the members are groups, not people
- `samba-tool group listmembers "Domain Admins"` — compare it with `samba-tool group listmembers Sales-Team`
- A disabled account's `userAccountControl` has the 0x2 bit set (514 instead of 512)
- `samba-tool group removemembers "Domain Admins" <user>`

</details>

## My notes

<!-- Screenshots: ./lab shot ad-aduc ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [powershell-basics](../powershell-basics/): the same accounts and groups through Get-ADUser / Get-ADGroupMember
- [ad-core-concepts](../ad-core-concepts/): the forest, domain and OUs these objects live in
- [ad-authentication](../ad-authentication/): what a logon by one of these accounts leaves in the Security log
- MITRE ATT&CK T1098 (Account Manipulation), T1078.002 (Valid Accounts: Domain Accounts), T1069.002 (Permission Groups Discovery: Domain Groups)
