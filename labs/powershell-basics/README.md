# powershell-basics

## Concepts

Clicking through consoles doesn't scale to the tenth host of an investigation. On Windows, the
analyst's first minutes on a box happen in a terminal: the classic **Command Prompt** (CMD) for quick
orientation, and **PowerShell** for everything that needs filtering, sorting or exporting.

**Orientation: four CMD staples.** Before touching anything, find out where you are and who you are:

| Question | CMD | What you get on a domain controller |
|---|---|---|
| Who am I running as? | `whoami` | `DOMAIN\user`, e.g. `corp\administrator` |
| Which machine is this? | `hostname` | The computer name |
| How is it connected? | `ipconfig` (`/all` for DNS, MAC, DHCP) | IPv4 address, mask, gateway |
| What is it? | `systeminfo` | OS name and build, install date, patches, domain, boot time |

The `DOMAIN\user` form matters: a local account shows `COMPUTER\user`, a domain account shows the
domain's short (NetBIOS) name. That difference is often the first clue that an attacker created a
local account instead of using a stolen domain one.

**PowerShell: Verb-Noun and objects.** Every cmdlet is named **Verb-Noun**: `Get-Process`,
`Stop-Service`, `New-Item`, `Get-ADUser`. The verbs come from a fixed list (`Get-Verb`), so once
you know the noun, the commands are guessable. Two helpers make them discoverable:

- `Get-Command *keyword*` (or `-Verb` / `-Noun`) finds commands, and its **Source** column tells you
  which module brings each one
- `Get-Help <cmdlet> -Examples` shows how a cmdlet is meant to be used

`Get-Service` is the terminal version of `services.msc`, `Get-Process` the one of Task Manager. Many
familiar names are just **aliases** (`dir`, `ls`, `cat`), which `Get-Alias` resolves to the real cmdlet.

Unlike CMD, PowerShell passes **objects**, not text, down the pipeline. `Where-Object` filters them,
`Select-Object` picks columns, `Sort-Object` sorts, and `Export-Csv` turns the result into a file a
colleague can open. Properties keep their types: a date compares as a date, `$true` and `$false` are
booleans, not strings.

**Active Directory from the terminal.** The ActiveDirectory module (on a domain controller, or any
Windows machine with RSAT) exposes the directory as cmdlets:

```
Get-ADUser -Identity <sam> -Properties Department,Title     # one account, two extra properties
Get-ADUser -Filter * -SearchBase "OU=Sales,DC=corp,DC=local" # everybody in one OU
Get-ADUser -Filter 'Enabled -eq $false'                      # every disabled account
Get-ADGroupMember 'Domain Admins'                            # direct members of a group
```

Without `-Properties`, `Get-ADUser` returns only a small default set (name, SamAccountName, Enabled,
SID ...); everything else has to be asked for. `-Filter` can test any attribute, asked for or not.

**Why the SOC cares.** Account hygiene is a recurring hunt:

- **Disabled** accounts should stay disabled; one that comes back to life is an incident
- **Stale** accounts (enabled, but nobody logged on for months) belong to people who left: a
  password that still works and that nobody would miss
- **PasswordNeverExpires** is normal for some service accounts, a finding on a person
- **Privileged groups through nesting**: `Get-ADGroupMember 'Domain Admins'` lists the direct
  members only. A group inside the group gives its members the same rights, and only `-Recursive`
  shows who they are. This is a classic way for excess rights to hide

**About this lab.** It runs PowerShell 7 on Linux, so some things are different from a Windows
server: `whoami`, `hostname` and `dir` exist, `ipconfig`, `systeminfo` and `Get-Service` don't
(their tasks use what PowerShell and .NET offer instead). The real ActiveDirectory module needs
Windows and a domain controller, so the lab ships **LabAD**: a stand-in with the same cmdlet names,
parameters and default output, over a seeded directory. The same commands work on a real domain.

## Tasks

Start the lab with `./lab up powershell-basics`, open a shell with `./lab shell powershell-basics`
and type `pwsh`. You are on **rdg-fs01**, a file server of Ridgeline Outfitters (domain
`ridgeline.local`, NetBIOS name `RIDGELINE`), sent there by a ticket asking for an account review.
Write the answers to `/root/answers.txt`, one `KEY=value` per line (case doesn't matter).

1. **Orientation.** Find out who and where you are.

   ```
   WHOAMI=<what whoami prints>
   COMPUTER=<the computer name>
   IDENTITY=<the same account in DOMAIN\user form, as .NET reports it>
   OS_NAME=<the operating system and release, as PowerShell reports it>
   IPV4=<the server's IPv4 address on its network interface>
   ```

2. **The cmdlet model.**

   ```
   NAMING=<the two-part naming convention of every cmdlet>
   SERVICE_CMDLET=<the cmdlet that lists services and their status on Windows>
   PROCESS_CMDLET=<the cmdlet that lists running processes>
   DIR_ALIAS=<the cmdlet the alias dir runs>
   PS_VERSION=<the PowerShell version, e.g. 1.2.3>
   ```

3. **Query Active Directory.**

   ```
   AD_CMDLET=<the cmdlet that retrieves AD user accounts>
   AD_MODULE=<the module that provides it on this server>
   MREYES_TITLE=<the job title of the account mreyes>
   DISABLED_USER=<the SamAccountName of the disabled employee (not a built-in account)>
   ```

4. **Account hygiene.** The ticket asks for three more things.

   ```
   STALE_USER=<the enabled account with no logon in the 90 days before 2026-11-05>
   NEVER_EXPIRES_USER=<the person, not a service account, whose password never expires>
   HIDDEN_ADMIN=<the Domain Admin who doesn't work in IT>
   HIDDEN_VIA=<the group that puts that account in Domain Admins>
   ```

5. **Report.** Export every user in the Finance OU to `/root/reports/finance-users.csv` with exactly
   the columns `SamAccountName`, `Title` and `Enabled`.

Check your work from the host: `./lab check powershell-basics`

<details>
<summary>Hints</summary>

- `[Environment]` has static properties for the user and the domain: `[Environment] | Get-Member -Static`
- `$PSVersionTable` answers two questions
- `[System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()` lists the interfaces;
  each one has `GetIPProperties()`, and the network card is `eth0`
- `Get-Command *user*` and `Get-Help Get-ADUser -Examples`; `Get-Command` also shows the Source
- The default output of `Get-ADUser` has no Title; `-Properties *` shows everything there is
- The built-in disabled accounts have no Department
- `(Get-Date '2026-11-05').AddDays(-90)` in a variable works inside a `-Filter` string
- `Get-ADGroupMember` piped into `Get-ADUser -Properties Department` puts a department on each member
- `Get-ADDomain` gives the domain's distinguished name; an OU's DN is built from it,
  innermost OU first (`OU=Finance,OU=Staff,...`). `Get-ADUser -Filter * | Select-Object DistinguishedName`
  shows the real paths

</details>

## My notes

<!-- Screenshots: ./lab shot powershell-basics ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-cli-intro](../linux-cli-intro/): the same orientation on Linux
- [wazuh-sudo-abuse](../wazuh-sudo-abuse/): privilege escalation seen from the logs
- [splunk-bruteforce-response](../splunk-bruteforce-response/): what happens when a stale account's password still works
- MITRE ATT&CK T1078 (Valid Accounts), T1087.002 (Account Discovery: Domain Account), T1069.002 (Domain Groups)
