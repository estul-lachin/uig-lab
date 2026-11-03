# lockbit-case-study

## Concepts

**LockBit** was, from about 2022 to 2024, the most active ransomware-as-a-service (RaaS) brand: a
core team built the encryptor, the affiliate panel and the leak site, and affiliates did the break-ins
for a share of the ransom.

| When | What changed |
|---|---|
| 2019 | First seen, before it had a name; researchers called it after the extension it put on files |
| Early 2020 | Named LockBit, affiliate program opens, the extension changes to match the name |
| 2021 | LockBit 2.0, with its own exfiltration tool, StealBit |
| 2022 | LockBit 3.0 ("Black"): a bug bounty for its own malware, and a guardrail: the encryptor only runs with the right argument |
| February 2024 | Operation Cronos: the UK's NCA and the FBI, with Europol and others, seize servers, the leak site and affiliate panels, and turn the leak site against the group |
| May 2024 | The leader, "LockBitSupp", is named and sanctioned; paying the ransom now risks breaking sanctions |

**Why it scaled**:
- Easy panels let many affiliates of uneven skill run attacks, so volume was high and tradecraft
  varied.
- Once it had a privileged foothold it could **spread itself** across the Windows network: SMB admin
  shares, PsExec, and Group Policy.
- **Double extortion**: steal first (StealBit, Rclone, cloud storage such as Mega), then encrypt.

**The usual path**, and what it leaves in the logs:

| Stage | Behaviour | Typical evidence |
|---|---|---|
| Initial access | Exposed RDP or VPN with stolen or guessed passwords; edge-device exploits; phishing | Security 4625 (failed logon), 4624 (logon; type 10 = RDP) |
| Discovery, credentials | Network scanners; dumping LSASS memory | Sysmon 1 (process creation) |
| Lateral movement | PsExec, admin shares, RDP with a stolen admin account | 4624 type 3 on the target, a `PSEXESVC` service |
| Exfiltration | Rclone or StealBit to a file-sharing service | Sysmon 1, Sysmon 3 (network connection) |
| Impact | Delete shadow copies, clear logs, encrypt, ransom note, wallpaper | Sysmon 1, 11 (file created), 13 (registry value set) |

**Shadow copies** (Volume Shadow Copy Service) are Windows' built-in snapshots. Ransomware deletes them
so that victims can't roll back. That's ATT&CK T1490, *Inhibit System Recovery*. It's one of the most
reliable signals there is, because legitimate software rarely does it. Common ways to do it:
- `vssadmin delete shadows`
- `wmic shadowcopy delete`
- `vssadmin resize shadowstorage` with a tiny maximum, which makes Windows discard them

Windows command lines are case-insensitive, and attackers use that.

**The evidence** in `/root/case/events.jsonl` is one JSON object per line: `RecordID`, `UtcTime`,
`Computer`, `Channel` (`Security` or `Sysmon`), `EventID`, plus the fields of that event type. With
`jq`:

```
jq -c 'select(.EventID == 4624 and .LogonType == 10)' events.jsonl
jq -r 'select(.EventID == 1) | .Image' events.jsonl | sort | uniq -c | sort -rn
```

## Tasks

Start the lab with `./lab up lockbit-case-study`, open a shell with `./lab shell lockbit-case-study`.
You are in `/root/case`. Write `KEY=value` answers to `/root/case/answers.txt`.

1. **LockBit in brief.** `EXFIL_TOOL=<a tool it used to steal data>`,
   `SPREAD_PROTOCOL=<the network protocol it spreads over>`, `FIRST_EXT=` and `SECOND_EXT=<its first
   two file extensions>`, `TAKEDOWN=<the name of the 2024 operation>`.
2. **The night at Harbor Lane Logistics** (fictional). Overnight on 18 October 2026, an affiliate
   using a LockBit 3.0-style kit hit HLL. Reconstruct it from the events:

   ```
   ATTACKER_IP=<where the intrusion came from>
   ENTRY_ACCOUNT=<the account it got in with>
   ENTRY_HOST=<the first host it got into>
   ADMIN_ACCOUNT=<the privileged account it moved with>
   EXFIL_DATA=<the folder it stole, as written in the log>
   ENCRYPTED_HOSTS=<how many hosts had files encrypted>
   SPARED_HOST=<the workstation in the log that was not encrypted>
   RANSOM_EXT=<the extension added to encrypted files>
   ```

   Not every failed logon or `vssadmin` in the log is the attacker.
3. **ATT&CK.** Write `map.csv` with the header `record,technique` and one row for each of these
   records, giving its ATT&CK technique ID (sub-techniques are welcome): 10172, 10236, 10272, 10346,
   10438, 10629, 10689, 10690, 10700, 10693.
4. **A detection.** Write `detect-shadow.sh`, an executable script that reads events like these (JSON
   Lines) on stdin and prints the `RecordID` of every **Sysmon process creation** that deletes shadow
   copies, one per line. It must catch the ways listed above, in any letter case. It must not fire on
   harmless uses of the same programs, or on events that merely mention the words. The check also runs
   it on events it hasn't seen.

Check your work from the host: `./lab check lockbit-case-study`

<details>
<summary>Hints</summary>

- Count failed RDP logons per source: `select(.EventID == 4625) | .IpAddress`, then `sort | uniq -c`
- The first successful logon from that address names the account and the host
- Follow the account: what did it run, and with whose credentials did it reach the other servers?
- The encryptor renames files (Sysmon 11); count the distinct `Computer` values
- ATT&CK: attack.mitre.org; search a behaviour such as "comsvcs MiniDump" or "Group Policy"
- In jq, `ascii_downcase` and `test("regex")`; match `.Image` and `.CommandLine` separately

</details>

## My notes

<!-- Screenshots: ./lab shot lockbit-case-study ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [ransomware-kill-chain](../ransomware-kill-chain/): IoCs, kill chain and ATT&CK for another RaaS intrusion
- [ransomware-drill](../ransomware-drill/): the impact stage, and recovering from it
- [wazuh-alert-triage](../wazuh-alert-triage/): the same kind of evidence, as SIEM alerts
- CISA advisory AA23-075A (LockBit 3.0), MITRE ATT&CK software S1202, NCA Operation Cronos materials
