# blackcat-case-study

## Concepts

**BlackCat**, also called **ALPHV** (and tracked as Noberus), was a high-end ransomware-as-a-service
operation from late 2021 to early 2024. Many of its people are thought to have come from the
DarkSide/BlackMatter crews. The FBI tied it to over a thousand victims.

What set it apart technically:
- **Written in Rust**, one of the first big families to be: fast, memory-safe, and built for Windows,
  Linux and **VMware ESXi** from one code base. On a hypervisor, one run takes out every virtual machine
  at once.
- **Configurable per affiliate**: command-line options, an access token per build, and an encrypted
  file extension that differs per build and victim. No single extension identifies it.
- 2023's rewrite, "Sphynx", added more evasion.
- **Multi-extortion**: steal (its own ExMatter, Rclone, Mega), encrypt, publish on a polished leak site,
  and sometimes DDoS victims or contact their customers.

**How it ended**:
- **December 2023**: the US DOJ disrupted it and released a decryptor. BlackCat "unseized" its site and
  told affiliates to go after hospitals.
- **February 2024**: an affiliate hit **Change Healthcare** through a remote-access portal without MFA,
  and US healthcare payments stalled for weeks. A ransom of about US$22 million was reportedly paid.
- **March 2024**: the operators kept the money, cheated the affiliate, and put up a *fake*
  law-enforcement seizure banner: an exit scam.

**Valid accounts and legitimate tools.** BlackCat affiliates mostly *logged in* rather than broke in:
- Purchased credentials, and VPN or Citrix portals without MFA.
- The help desk talked into resetting a password or MFA. Scattered Spider did this to MGM Resorts.
- **MFA fatigue** (push bombing): sending push after push until a tired user taps *Approve*.
- Once inside: AnyDesk or Splashtop, PsExec, AD recon scripts, Rclone. All of these are tools that
  admins use too.

Signatures don't help much against that. What does help is **behaviour and context**:

| Signal | Where it shows |
|---|---|
| A help-desk reset that skipped identity verification | Ticketing system |
| A sign-in from an unusual country or a new device, right after a reset | Identity provider (IdP) |
| Many denied pushes, then an approval | IdP |
| Remote-access software on a host where it isn't approved | EDR plus an allowlist |
| Gigabytes going to cloud storage from a file server | Proxy / egress logs |
| VMs force-killed and disk files renamed on a hypervisor | ESXi shell and vmkernel logs |

**Exfiltrate first, then encrypt.** Good backups undo encryption, not theft. The leak threat remains,
so catching the upload matters as much as catching the encryptor.

**The evidence** in `/root/case`:

| File | Format |
|---|---|
| `idp-signins.jsonl` | One sign-in per line: `time` (UTC), `user`, `ip`, `country`, `app`, `result`, `mfa` |
| `helpdesk-tickets.csv` | `ticket,time,claimed_user,action,verified_by_callback,note` |
| `edr-process.jsonl` | One process start per line: `time`, `host`, `user`, `image`, `command_line` |
| `proxy.csv` | `time,host,dest,bytes_out,bytes_in` |
| `esx01-shell.log` | The ESXi host's shell and vmkernel lines |
| `approved-remote-tools.csv` | `host,tool`: where remote-access software is allowed |

## Tasks

Start the lab with `./lab up blackcat-case-study`, open a shell with `./lab shell blackcat-case-study`.
You are in `/root/case`. Write `KEY=value` answers to `/root/case/answers.txt`.

1. **BlackCat in brief.** `LANGUAGE=<what it was written in>`, `FIXED_EXTENSION=<yes or no>`,
   `EXFIL_TOOL=<a tool affiliates used to steal data>`, `C2_SOFTWARE=<what they used for beacons>`.
2. **Pinecrest Health Partners** (fictional), the week of 5 October 2026:

   ```
   ENTRY_TICKET=<the help-desk ticket that let them in>
   ENTRY_USER=<the account they took over>
   ATTACKER_IP=<where they then signed in from>
   ROGUE_TOOL_HOST=<the host where remote-access software appeared without approval>
   ADMIN_ACCOUNT=<the privileged account they moved with>
   EXFIL_HOST=<the host the data left from>
   EXFIL_GB=<how much it uploaded to cloud storage, in whole GB (10^9 bytes)>
   MINUTES_EXFIL_TO_IMPACT=<minutes from the last upload to the first VM being killed>
   VMS_ENCRYPTED=<how many virtual machines were encrypted>
   RANSOM_EXT=<the extension this build added>
   RANSOM_NOTE=<the ransom note's file name>
   FATIGUE_VICTIM=<the user who gave in to push bombing>
   ```

   AnyDesk on its own isn't the finding, and neither is a burst of denied pushes.
3. **An MFA-fatigue detection.** Write `mfa-fatigue.sh`, an executable script that reads sign-ins like
   these on stdin and prints `user,ip` once for each case where a user **approved** a push and the same
   user and IP had **at least 5 denied pushes in the 10 minutes before** that approval. The check also
   runs it on sign-ins it hasn't seen.

Check your work from the host: `./lab check blackcat-case-study`

<details>
<summary>Hints</summary>

- `awk -F,` works on these CSVs as long as you only need the columns before `note`
- After the ticket, follow that user in `idp-signins.jsonl`: what changes in `country` and `mfa`?
- Remote-access software per host in the EDR events, then compare with the allowlist
- `awk -F, '$3 ~ /mega/ {s += $4} END {print s}' proxy.csv`
- In the container, `date -u -d 2026-10-07T02:16:00Z +%s` gives seconds since 1970
- In jq, `fromdateiso8601` turns `time` into seconds; `jq -s` gives you all lines as one array to
  compare against

</details>

## My notes

<!-- Screenshots: ./lab shot blackcat-case-study ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [lockbit-case-study](../lockbit-case-study/) and [conti-case-study](../conti-case-study/): the other
  RaaS case studies, with shadow-copy and beacon detections
- [wazuh-alert-triage](../wazuh-alert-triage/): the same signals as SIEM alerts
- [linux-authentication](../linux-authentication/): authentication logs on Linux
- CISA advisory AA23-353A (ALPHV/BlackCat), MITRE ATT&CK S1068
