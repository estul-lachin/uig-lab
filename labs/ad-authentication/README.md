# ad-authentication

## Concepts

This is where the Windows and AD fundamentals meet the SOC. Two questions: how does Windows prove who
you are, and what does that leave behind in the Security log for an analyst to read?

**Two authentication protocols.**

- **Kerberos** — the default in Active Directory. You authenticate once to the **KDC** (on the domain
  controller) and get a **TGT** (Ticket-Granting Ticket). To reach a service you present the TGT and
  get a **service ticket** (**TGS**) for it, without sending your password again. `klist` shows the
  tickets cached for your session.
- **NTLM** — the older challenge-response protocol, still there for local logons, connections by IP,
  and non-domain cases. It is weaker, and it is the basis of **Pass-the-Hash**: a stolen password hash
  is replayed to authenticate without ever cracking it.

**Logon types.** Every logon is tagged with a number saying how the session was created:

| Type | Meaning | Why it matters |
|---|---|---|
| 2 | Interactive (at the console) | someone physically / RDP-console logged on |
| 3 | Network (a share or service over the network) | the most common, and what Pass-the-Hash produces |
| 10 | RemoteInteractive (RDP) | a Remote Desktop session |

**Account lockout.** The domain policy locks an account after too many bad passwords — here **5**
attempts, for **30** minutes. It blunts brute force, but also makes noise and self-inflicted outages, so
correlating lockouts is routine. (The built-in Administrator is exempt.)

**The Event IDs every analyst memorises** (Security log):

| Event ID | Meaning |
|---|---|
| 4624 | Successful logon |
| 4625 | Failed logon |
| 4768 | Kerberos TGT requested (AS-REQ) — an authentication |
| 4769 | Kerberos service ticket requested (TGS-REQ) — access to a service |
| 4740 | Account locked out |

**How attacks show up in them.**

- **Brute force / password spray** — a burst of **4625**, often ending in **4740** (lockout) or a
  **4624** if a password finally works.
- **Pass-the-Hash / lateral movement** — **4624** with **Logon Type 3** using **NTLM** from a host
  that has no business authenticating there.
- **Kerberoasting** — a spike of **4769** for an account that has a **Service Principal Name** (SPN),
  especially requested with weak **RC4** encryption (`0x17`, versus AES `0x12`). The attacker asks the
  KDC for that service's ticket and cracks it offline to recover the service account's password.
  Knowing which accounts have SPNs tells you what is at risk; here `svc_sql` runs MSSQL and carries
  `MSSQLSvc/sql.ridgeline.local`.

**About this lab.** DC01 is a real AD domain controller (Samba 4). Kerberos is real: `kinit` gets you a
TGT, `klist` shows it, `kvno <SPN>` requests a service ticket — exactly the request a Kerberoast makes.
`svc_sql` really carries the SPN. Windows writes the Security log as EVTX; here the morning's events are
provided as a text log in the same shape (`/var/log/dc01/security.log`,
`<time> EventID=<id> Field=Value ...`) so you can triage them with the shell.

## Tasks

Start the lab with `./lab up ad-authentication`, open a shell with `./lab shell ad-authentication`. You
are root on **DC01** (`ridgeline.local`); the domain Administrator's lab password is `Lab-AD-2026!`.
The Security event log is `/var/log/dc01/security.log`. Write the answers to `/root/answers.txt`, one
`KEY=value` per line (case doesn't matter).

1. **The two protocols.**

   ```
   AUTH_DEFAULT=<the default authentication protocol in Active Directory>
   LEGACY_PROTOCOL=<the older challenge-response protocol behind Pass-the-Hash>
   TICKET_CMD=<the command that lists your cached Kerberos tickets>
   ```

2. **The Event IDs.**

   ```
   EVT_LOGON_SUCCESS=<successful logon>
   EVT_LOGON_FAIL=<failed logon>
   EVT_TGT=<Kerberos TGT requested (AS-REQ)>
   EVT_TGS=<Kerberos service ticket requested (TGS-REQ)>
   EVT_LOCKOUT=<account locked out>
   RDP_LOGON_TYPE=<the Logon Type number for a Remote Desktop logon>
   ```

3. **The Kerberoastable account.** Find the service account with an SPN on the live DC.

   ```
   KERBEROASTABLE_ACCOUNT=<its name>
   SPN=<its MSSQL Service Principal Name>
   ```

   For the real thing: `kinit` as a user, then `kvno <SPN>` to request the service ticket, and see it
   appear in `klist` — that request is what a Kerberoast sends.

4. **Triage the morning's Security log.** Three things in it are not normal traffic.

   ```
   ATTACKER_IP=<the address behind the brute force, the lockout and the Kerberoasting>
   BRUTE_ACCOUNT=<the account the 4625 burst targeted>
   BRUTE_FAILS=<how many 4625 it got from the attacker>
   LOCKOUT_ACCOUNT=<the account the 4740 names>
   KROAST_COUNT=<how many 4769 requested the MSSQL service>
   KROAST_ENC=<the ticket encryption on those requests, the weak one>
   PTH_ACCOUNT=<the account in the NTLM Type-3 4624 from the attacker>
   ```

Check your work from the host: `./lab check ad-authentication`

<details>
<summary>Hints</summary>

- `samba-tool spn list svc_sql`, or `samba-tool user list` to find the service accounts first
- `kinit mreyes@RIDGELINE.LOCAL` (password above), then `kvno MSSQLSvc/sql.ridgeline.local`, then `klist`
- `grep EventID=4625 /var/log/dc01/security.log | grep -oE 'TargetUser=[^ ]+' | sort | uniq -c | sort -rn`
- The attacker's IP is the one common to the 4625 burst, the 4740 and the 4769 burst; the background
  logons come from other addresses
- `grep EventID=4769 ... | grep MSSQLSvc` — the ordinary service tickets are for HOST/LDAP/cifs, not MSSQLSvc
- `0x17` is RC4, `0x12` is AES256; the weak one is why the ticket can be cracked offline
- Pass-the-Hash: `grep EventID=4624 ... | grep AuthPackage=NTLM`

</details>

## My notes

<!-- Screenshots: ./lab shot ad-authentication ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [ad-core-concepts](../ad-core-concepts/): the domain, the KDC and the Global Catalog
- [ad-group-policy](../ad-group-policy/): where the lockout policy is set
- [splunk-bruteforce-response](../splunk-bruteforce-response/) and [wazuh-ssh-bruteforce](../wazuh-ssh-bruteforce/): the same brute force on the Linux side
- MITRE ATT&CK T1558.003 (Kerberoasting), T1550.002 (Pass the Hash), T1110 (Brute Force)
