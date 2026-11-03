# ransomware-qr-phishing

## Concepts

Most ransomware incidents don't start with a clever exploit. They start with a way in that should have
been closed: an unpatched service, a VPN account without MFA, a helpdesk that believes a phone call, a
supplier's access nobody watched. An investigation answers the same four questions every time:
1. How did they get in?
2. What did they do, in ATT&CK terms?
3. Which control failed?
4. What do we change?

**The scenario.** Lumen Logistics, 2026-10-21. Six employees get an urgent "benefits enrollment"
mail whose only content is a picture with a QR code. Phones scan it, and phones sit outside the mail
filter's link checks and the company's web proxy. That's why QR phishing ("quishing") works. Over the
next day the security tools flag suspicious PowerShell and a large upload. The logs of five systems are
in `/root/case/logs`, one JSON object per line:

| File | System | Interesting fields |
|---|---|---|
| `mail.jsonl` | Mail gateway | `from`, `to`, `subject`, `qr_code_url` |
| `idp.jsonl` | Identity provider (SSO + MFA) | `user`, `event`, `src_ip`, `country` |
| `directory.jsonl` | Directory audit log | `actor`, `action`, `target`, `group` |
| `endpoint.jsonl` | EDR process events | `host`, `user`, `process`, `command_line` |
| `proxy.jsonl` | Web proxy | `host`, `dest`, `method`, `bytes_out` |

**jq** filters JSON lines:
- `jq 'select(.event == "mfa_push_sent")' idp.jsonl` keeps matching objects, `jq -r .field` prints one
  field, `jq -c` prints compactly.
- `jq -s '[.[] | .bytes_out] | add' file` slurps all lines into one array to sum them.
- Combine with `sort | uniq -c` for counts.

**MFA fatigue**: with a password in hand, the attacker triggers push notification after push notification
until the user taps *Approve*, just to make it stop. Signs of it are many `mfa_push_sent` events in a
few minutes from one unusual address, mostly denied or timed out, then one approval. Phishing-resistant
MFA (FIDO2 keys, passkeys) and number matching stop it.

**Encoded PowerShell**: `powershell -enc <text>` (`-EncodedCommand`) takes **base64 of UTF-16LE**
text. It's a classic way to hide a command line from casual review. Decode it with
`base64 -d | iconv -f UTF-16LE -t UTF-8`.

**MITRE ATT&CK** names attacker behaviour with IDs: a *technique* such as `T1566` (Phishing), and
*sub-techniques* such as `T1566.002` (Spearphishing Link). Mapping each step to an ID makes reports
comparable and points at the detections and mitigations ATT&CK lists for it. The site attack.mitre.org
has every technique.

## Tasks

Start the lab with `./lab up ransomware-qr-phishing`, open a shell with
`./lab shell ransomware-qr-phishing`. The shell is `root` in `/root/case`. Write `KEY=value` answers to
`/root/case/answers.txt`. Times as they appear in the logs, e.g. `2026-10-21T08:00:00Z`.

1. **The phishing mail.** `PHISH_SENDER=<its sender address>`,
   `QR_DOMAIN=<the domain the QR code leads to>`, `PHISH_RECIPIENTS=<how many people received it>`.
2. **Initial access and MFA fatigue.** `ATTACKER_IP=<the address that logged in as the victim>`,
   `MFA_PUSHES=<how many pushes were sent, the approved one included>`,
   `APPROVED_AT=<when the victim approved>`.
3. **Persistence.** `NEW_ADMIN=<the account the attacker created>`, `ADMIN_GROUP=<the group it was
   added to>`, `CREATED_BY=<the account that did it>`.
4. **Execution.** `PS_HOST=<the host where the encoded PowerShell ran>`. Decode its command into
   `/root/case/decoded.txt`, then write `STAGING_FILE=<the archive it created>`.
5. **Exfiltration.** `EXFIL_DOMAIN=<where the data went>` and `EXFIL_MB=<how much was uploaded there, in
   MiB, rounded down>`.
6. **Mapping to ATT&CK.** One technique ID (sub-techniques welcome) for each step: `ATT_INITIAL_ACCESS`
   (the mail), `ATT_MFA` (the push flood), `ATT_LOGIN` (using the stolen credentials),
   `ATT_PERSISTENCE` (the new admin), `ATT_EXECUTION` (the PowerShell) and `ATT_EXFIL` (the upload).
7. **Immediate response.** Write `/root/case/response.md` with at least five actions, one bullet each.
   Contain the attacker's accounts, the victim's account and sessions, the affected machine and the
   outside infrastructure, using the names you found.
8. **Four public cases.** For each of these well-known incidents, give the ATT&CK ID of its initial
   access, as publicly reported:
   - `CASE_WANNACRY`: the 2017 worm that spread through a Windows SMB vulnerability on unpatched hosts.
   - `CASE_COLONIAL`: Colonial Pipeline, 2021, entered through a VPN account with a leaked password and
     no MFA.
   - `CASE_MGM`: MGM Resorts, 2023, where attackers phoned the IT helpdesk posing as an employee.
   - `CASE_CHANGE`: Change Healthcare, 2024, entered through a remote-access portal with stolen
     credentials and no MFA.

   For each one, also think about which control would have stopped it.

Check your work from the host: `./lab check ransomware-qr-phishing`

<details>
<summary>Hints</summary>

- `jq -c 'select(.qr_code_url != null)' logs/mail.jsonl`
- `jq -c 'select(.user == "priya.n" and .country != "DE")' logs/idp.jsonl`
- `jq -c 'select(.action == "account_created" or .group == "Domain Admins")' logs/directory.jsonl`
- `jq -r 'select(.command_line | test("-enc")) | .command_line' logs/endpoint.jsonl`, then take the last word
- `jq -s '[.[] | select(.dest == "<domain>") | .bytes_out] | add / 1048576 | floor' logs/proxy.jsonl`
- ATT&CK techniques to look up: Phishing, Multi-Factor Authentication Request Generation, Valid Accounts,
  Create Account, Command and Scripting Interpreter, Exfiltration Over Web Service, Exploitation of
  Remote Services, External Remote Services, Impersonation

</details>

## My notes

<!-- Screenshots: ./lab shot ransomware-qr-phishing ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [logs-journald](../logs-journald/) and [splunk-search-basics](../splunk-search-basics/): the same kind of
  timeline from Linux and SIEM data
- [users-sudo](../users-sudo/): auditing who can become an admin
- MITRE ATT&CK: attack.mitre.org; CISA's #StopRansomware advisories
