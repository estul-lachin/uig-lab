# conti-case-study

## Concepts

**Conti** was a ransomware-as-a-service operation from about 2020 to mid-2022, run by the Russia-linked
group **Wizard Spider** (MITRE G0102), which had earlier run Ryuk and the TrickBot botnet. US agencies
tied it to more than a thousand attacks, many on hospitals, schools and governments.

What set it apart:
- **The loader chain.** A phishing document starts a loader (TrickBot, BazarLoader, IcedID). The
  loader brings in Cobalt Strike, and only at the very end comes the encryptor. Each hop is a place
  to catch it.
- **Speed.** The encryptor used many threads at once, so once it started there was little time to
  react.
- **A company.** The 2022 "Conti Leaks" were published after the group sided with Russia over
  Ukraine: tens of thousands of chat messages, plus source code. They showed salaries, managers,
  playbooks and tooling, which handed defenders the adversary's own manuals.
- **Double extortion.** Files got the `.CONTI` extension, a `readme.txt` note pointed to Tor, and
  stolen data went on the **Conti News** leak site.
- **Costa Rica, 2022.** The attack on government systems led to a national emergency.

It broke up in mid-2022, but its people went on to Black Basta, Royal/BlackSuit, Karakurt and others.
Brands die; tradecraft doesn't, which is why detections built on behaviour last.

**Detection opportunities**: the earlier a stage is caught, the cheaper the response. Each stage leaves
its own evidence:

| Stage | Conti-style behaviour | Evidence |
|---|---|---|
| Delivery | A user opens a document from email | Sysmon 1: Office started from Outlook |
| Execution | The document's macro starts a loader | Sysmon 1: an Office **parent** with an odd child (`rundll32`, `powershell`) |
| Command and control | The loader calls home on a timer (a **beacon**) | Sysmon 3: one process, one address, regular gaps |
| Credential access | Memory of `lsass.exe` is read | Sysmon 10: process access to `lsass.exe` |
| Privilege escalation | Zerologon (CVE-2020-1472) resets the domain controller's own machine account | Security 4742 on the DC by `ANONYMOUS LOGON` |
| Lateral movement | Admin logons and PsExec to other hosts | Security 4624 type 3, `PSEXESVC.exe` |
| Exfiltration | Rclone to Mega | Sysmon 1 and 3 |
| Impact | Encryptor, shadow copies deleted, services stopped, files renamed | Sysmon 1 and 11 |

**Beacons**: implants call home at a set interval with some random **jitter**, so the gaps between
connections cluster around one value. Plenty of legitimate software does the same (sync clients,
updaters, uploads), so a beacon detector finds *candidates*, and an analyst decides which are bad: by
the process, where it lives, who started it, and where it connects to.

**The evidence** in `/root/case/events.jsonl` is one JSON object per line: `RecordID`, `UtcTime`
(UTC), `Computer`, `Channel` (`Security` or `Sysmon`), `EventID`, and that event type's fields. Some
`jq` to start with:

```
jq -c 'select(.EventID == 1 and (.ParentImage | test("WINWORD")))' events.jsonl
jq -r 'select(.EventID == 3) | [.Computer, .Image, .DestinationIp] | join(" ")' events.jsonl | sort | uniq -c | sort -rn | head
jq -rs 'map(.UtcTime | strptime("%Y-%m-%d %H:%M:%S") | mktime) | ...' events.jsonl
```

## Tasks

Start the lab with `./lab up conti-case-study`, open a shell with `./lab shell conti-case-study`. You
are in `/root/case`. Write `KEY=value` answers to `/root/case/answers.txt`.

1. **Conti in brief.** `GROUP=<the threat group>`, `EXTENSION=<what it appended to files>`,
   `RANSOM_NOTE=<the note's file name>`, `LEAK_SITE=<the name of its leak site>`.
2. **Mercy Ridge Clinic** (fictional). On Monday 14 September 2026, a Conti-style crew got in.
   Reconstruct it:

   ```
   LURE=<the file name of the document that started it>
   PATIENT_ZERO=<the host it ran on>
   C2_IP=<the command-and-control address>
   BEACON_SECONDS=<the loader's call-back interval, in seconds>
   ESCALATION=<the name of the vulnerability used to become domain admin>
   EXFIL_DATA=<the folder that was stolen, as written in the log>
   ENCRYPTED_HOSTS=<how many hosts had files encrypted>
   SPARED_HOST=<the workstation in the log that was not encrypted>
   HOURS_TO_IMPACT=<whole hours from opening the document to the encryptor starting>
   ```

   Not every Word document opened that morning is the lure.
3. **The earliest chance to catch it.** Write `opportunities.csv` with the header `stage,record` and
   one row per stage in the table above, in that order (`delivery`, `execution`,
   `command-and-control`, `credential-access`, `privilege-escalation`, `lateral-movement`,
   `exfiltration`, `impact`). For each stage, give the `RecordID` of the **first** event that shows it.
4. **A beacon detector.** Write `find-beacons.sh`, an executable script that reads events like these
   on stdin and prints one line `Computer,Image,DestinationIp` for every series of Sysmon network
   connections (same computer, image and destination) that:
   - has at least 8 connections,
   - has a median gap between connections of 30 seconds to 1 hour,
   - has every gap within 25% of that median.

   Run it on the case file, and look at each line it prints: which one is the C2, and what are the
   others? The check also runs it on traffic it hasn't seen.

Check your work from the host: `./lab check conti-case-study`

<details>
<summary>Hints</summary>

- An Office process that *starts another process* is the signal; just opening a document isn't
- Follow that child process's network connections; the median of the gaps is the interval
- 4742 by `ANONYMOUS LOGON` on a DC is the classic Zerologon trace
- `.CONTI` files per `Computer`; then which workstation never shows up?
- `jq -s` reads all lines into one array; `group_by([.Computer, .Image, .DestinationIp])` makes the
  series; `strptime(...) | mktime` turns `UtcTime` into seconds
- Gaps: `[range(1; length) as $i | .[$i] - .[$i - 1]]` on the sorted times

</details>

## My notes

<!-- Screenshots: ./lab shot conti-case-study ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [lockbit-case-study](../lockbit-case-study/): another RaaS, with a shadow-copy detection
- [ransomware-kill-chain](../ransomware-kill-chain/): IoCs, kill chain and ATT&CK
- [wazuh-alert-triage](../wazuh-alert-triage/): triaging the same kind of signals in a SIEM
- CISA advisory AA21-265A (Conti), MITRE ATT&CK S0575 and G0102, The DFIR Report's Conti cases
