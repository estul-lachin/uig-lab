# ad-group-policy

## Concepts

Group Policy is how Windows pushes configuration to thousands of machines and users at once: password
rules, logon banners, lockdowns, scripts. It is also, for the same reason, one of the most powerful
things an attacker can get hold of in a domain.

**A GPO and its link are two different things.** A **Group Policy Object** (GPO) is a named bundle of
settings, with a computer side and a user side. On its own it does nothing. It takes effect only when
it is **linked** to a container — the domain, a site, or an OU — and the link is what defines the
**scope**: who the GPO applies to. One GPO can be linked in several places; one container can have
several GPOs. On Windows you manage all of this in the **Group Policy Management Console**
(`gpmc.msc`); the **Settings** tab of a GPO is a human-readable report of what it configures, the
**Scope** tab shows where it is linked.

The domain usually ships with two built-ins: **Default Domain Policy**, linked at the domain root,
which is where the **account policy** (password length, complexity, lockout) for the whole domain has
to live; and **Default Domain Controllers Policy**, linked to the Domain Controllers OU.

**Processing order: LSDOU.** When a computer or user applies policy, the GPOs are read in a fixed
order — **Local, Site, Domain, OU** (and nested OUs, parent before child). Later wins: the GPO linked
**closest** to the object is applied last and overrides the ones before it. That is **precedence**. So
a GPO linked to an OU of workstations can tighten — or loosen — a setting that a domain-level GPO also
configures, for those workstations only.

**Applying and verifying.** Policy refreshes on its own every ~90 minutes, but you don't wait:

| Windows | Here (a Samba domain member) |
|---|---|
| `gpupdate /force` — reapply now | `samba-gpupdate --force` |
| `gpresult /r` — Resultant Set of Policy: which GPOs actually applied | `samba-gpupdate --rsop` |

RSoP is how you *prove* a policy reached a host, or find out why it didn't.

**Why the SOC cares.** A GPO linked at the domain root reaches **every** machine in the domain,
domain controllers included. That makes Group Policy a favourite for domain-wide execution: an attacker
who can create and link a GPO (or edit an existing one) can push a **startup/logon script** or a
scheduled task to the whole estate at once — the technique behind ransomware that detonates everywhere
simultaneously. Defenders need to be able to list which GPOs are linked where, notice a GPO or a link
that shouldn't be there, and read what it would run. Scope and LSDOU are exactly the reasoning for
"could this policy have run on that host?".

**About this lab.** DC01 is a real AD domain controller (Samba 4); WS01 is a real domain member that
applies the GPOs with `samba-gpupdate` and writes the results to the system (`/etc/issue`, `/etc/motd`).
Samba keeps GPOs in the directory and sysvol exactly as Windows does, so `samba-tool gpo` reads and
changes the same links `gpmc.msc` would. Linux Client Side Extensions render a few Windows settings
onto their nearest Linux equivalent: a logon banner becomes `/etc/issue`, a startup script becomes a
`@reboot` line in `/etc/cron.d`.

## Tasks

Start the lab with `./lab up ad-group-policy`, open a shell with `./lab shell ad-group-policy`. You are
root on **WS01**, a workstation joined to `ridgeline.local`; the domain controller is **dc01**, and the
domain Administrator's lab password is `Lab-AD-2026!`. Read the GPOs with
`samba-tool gpo ... -H ldap://dc01.ridgeline.local -U Administrator`. Write the answers to
`/root/answers.txt`, one `KEY=value` per line (case doesn't matter).

1. **Read the Group Policy.**

   ```
   GPO_CONSOLE=<the .msc that opens the Group Policy Management Console on Windows>
   BANNER_GPO=<the domain-root GPO that sets the pre-logon legal notice>
   OU_GPO=<the GPO linked to OU=Workstations>
   PWPOLICY_GPO=<the built-in GPO that holds the domain password and lockout policy>
   MIN_PW_LEN=<the minimum password length it configures>
   FORCE_CMD=<the Windows command that reapplies policy immediately>
   RSOP_CMD=<the Windows command that shows which GPOs applied to you>
   PROCESSING_ORDER=<the acronym for Local, Site, Domain, OU>
   ```

2. **Apply policy and watch precedence.** Run `samba-gpupdate --force` on WS01, then look at
   `/etc/issue`. Both the domain-root banner GPO and the Workstations GPO set it; one of them wins.

   ```
   EFFECTIVE_BANNER_GPO=<the GPO whose banner actually ends up in /etc/issue on WS01>
   MAX_PW_AGE=<the maximum password age, in days, the Default Domain Policy sets>
   ```

3. **A GPO an attacker added.** Three GPOs are linked at the domain root; only two are Ridgeline's.

   ```
   ROGUE_GPO=<the extra one>
   ROGUE_LINK=<where it is linked, so that it reaches every machine>
   ROGUE_SCRIPT=<the startup script it pushes>
   ```

4. **Cut its link.** Remove the attacker's GPO from the domain root (unlinking is enough; deleting it
   works too). Leave the two legitimate domain-root GPOs linked.

Check your work from the host: `./lab check ad-group-policy`

<details>
<summary>Hints</summary>

- `samba-tool gpo listall -H ldap://dc01.ridgeline.local -U Administrator` lists every GPO; add
  `getlink <container-DN>` to see what is linked to the domain, an OU, etc.
- The domain's DN is `DC=ridgeline,DC=local`; OU=Workstations is `OU=Workstations,OU=Ridgeline,DC=ridgeline,DC=local`
- `samba-tool gpo manage security list <GUID>` prints a GPO's password and lockout settings
- After `samba-gpupdate --force`, read `/etc/issue` and `/etc/motd`, and look in `/etc/cron.d`
- `samba-tool gpo manage scripts startup list <GUID>` shows the boot script a GPO carries
- `samba-tool gpo dellink <container-DN> <GUID> -U Administrator` removes one link
- `samba-gpupdate --rsop` prints the Resultant Set of Policy, newest-winning GPO last

</details>

## My notes

<!-- Screenshots: ./lab shot ad-group-policy ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [ad-core-concepts](../ad-core-concepts/): the forest, domain and OUs these GPOs are linked to
- [windows-ntfs-acls](../windows-ntfs-acls/): another way rights are granted and misconfigured
- MITRE ATT&CK T1484.001 (Domain Policy Modification: Group Policy Modification), T1037 (Boot or Logon Initialization Scripts)
