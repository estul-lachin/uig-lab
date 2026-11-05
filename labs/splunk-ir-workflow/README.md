# splunk-ir-workflow

## Concepts

An incident is a workflow, not a single search. A common shape is **PICERL**: Preparation,
Identification, Containment, Eradication, Recovery, Lessons learned. In the SIEM it comes down to:

| Step | Question | In Splunk |
|---|---|---|
| **Triage** | Is the alert real? | Run the alert's search yourself, over the right time range, and look at the events |
| **Scope** | How far does it go? | **Pivot** on each indicator: the address, the host name, the account, on every source |
| **Identify** | What happened, in what order? | A **timeline**: every related event, `table _time sourcetype ...`, `sort _time` |
| Contain, eradicate | Stop it, remove it | Outside Splunk (EDR, firewall, AD, ticket); afterwards, rerun the searches to confirm |
| **Document** | Can the next shift pick it up? | Save the searches as reports, shared, with the ticket in them |

**Windows logon events** (Security log):

| EventID | Meaning | Useful fields |
|---|---|---|
| **4624** | Successful logon | `TargetUserName`, `LogonType`, `IpAddress`, `WorkstationName` (the source) |
| **4625** | Failed logon | the same, plus `Status`/`SubStatus` (`0xC000006A`: wrong password) |
| 4672 | Special privileges assigned to the new logon (an admin) | `SubjectUserName`, `PrivilegeList` |
| **4688** | A process was created | `NewProcessName`, `ParentProcessName`, `CommandLine` |
| 5140 | A network share was accessed | `ShareName`, `IpAddress` |

`LogonType` 2 is at the keyboard, **3 over the network** (SMB, a mapped drive, `psexec`), 10 remote
desktop. A domain admin logging on to a domain controller from an ordinary workstation is worth a
look: admins should come from the other DCs or an admin host.

**Pivot on every name a thing has.** A workstation is an IP address in firewall logs and in the
`IpAddress` of logons it makes, but its *own* events (processes it starts, users at its keyboard)
carry only its name. And with Windows Event Forwarding, `host` is the **collector**; the machine that
logged the event is in `Computer`. A timeline built on the address alone misses the half of the story
that happened on the machine itself.

**Document as you go.** `eval` can stamp a search with the ticket, so everyone who opens the report
sees who owns it:

```
... | eval ir_status="under_investigation", ir_ticket="INC-0000"
```

Every ticket should hold: when it was first observed, the indicators, the affected assets, what was
done to contain it, and the open questions.

## Tasks

Start the lab with `./lab up splunk-ir-workflow`. It has its own data: 3 November 2026 at a small
company, `index=main`, Windows events in `sourcetype=wineventlog:json` (collected by `wec-01`) and
the firewall in `sourcetype=fw:traffic`. The domain controllers are **DC-01** and **DC-02**
(10.40.0.11). The first start takes several minutes; stop other Splunk labs first, because they
share port 8000. Open **http://localhost:8000** and log in as `admin` with the lab password
`Lab-Splunk-2026`. Use **All time**; times are UTC. Write the answers in the workstation container
(`./lab shell splunk-ir-workflow`) to `/root/answers.txt`.

An alert fired: *it_admin logged on to DC-01 from a host that is not a domain controller.*

1. **Triage.**

   ```
   SUSPICIOUS_SRC=<the non-DC address it_admin logged on to DC-01 from>
   SUSPICIOUS_LOGONS=<how many such logons>
   LOGON_TYPE=<their LogonType>
   ```

2. **Pivot.**

   ```
   SRC_WORKSTATION=<the name of the machine behind that address>
   IP_SOURCETYPES=<how many sourcetypes mention the address at all>
   HOST_ONLY_EVENTS=<events that name the workstation but not its address>
   C2_IP=<the destination the workstation contacts every minute>
   ```

3. **The timeline.** Put everything about the workstation in time order and read it top to bottom.

   ```
   PATIENT_ZERO_USER=<who was logged on at the workstation's keyboard>
   PHISH_FILE=<the file name of the document that started it>
   FIRST_OBSERVED=<the time of that first malicious event, HH:MM:SS>
   BRUTE_FAILS=<failed logons for it_admin from the workstation>
   LATERAL_HOST=<the other server it_admin logged on to from there>
   STAGED_ARCHIVE=<the full path of the archive that was built>
   EXFIL_IP=<where it was uploaded>
   ```

4. **Document.** Save the timeline as a report named **`ir_<your initials>`** (two to four lowercase
   letters, for example `ir_ab`), shared with the app (Permissions: This app only), with:
   - every event that mentions the workstation's address **or** its name,
   - `_time` and `sourcetype` among the fields, oldest first,
   - `ir_status="contained"` and `ir_ticket="INC-2026-1103"` on every row.

Check your work from the host: `./lab check splunk-ir-workflow`. When you're done,
`./lab down splunk-ir-workflow` frees the memory.

<details>
<summary>Hints</summary>

- `EventID=4624 TargetUserName=it_admin Computer=DC-01*`, then `stats count by IpAddress WorkstationName LogonType`
- `index=* "<address>" | stats count by sourcetype` is the triage map
- `"WS-..." NOT "<address>"`: what kinds of event are those?
- The beacon: `stats count avg(bytes_out) by dest_ip` for the workstation; small and regular
- `EventID=4688` on the workstation: `table _time ParentProcessName NewProcessName CommandLine`
- The upload is the connection with by far the largest `bytes_out`
- `sort _time` (no minus) is oldest first; `sort 0` keeps more than 10,000 rows

</details>

## My notes

<!-- Screenshots: ./lab shot splunk-ir-workflow ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [splunk-bruteforce-response](../splunk-bruteforce-response/): detecting and responding to brute force
- [splunk-search-basics](../splunk-search-basics/): saving a report
- [wazuh-intrusion-capstone](../wazuh-intrusion-capstone/): correlating stages of one intrusion in Wazuh
- MITRE ATT&CK T1566.001 (Spearphishing Attachment), T1110 (Brute Force), T1021.002 (SMB/Windows
  Admin Shares), T1560.001 (Archive via Utility), T1048 (Exfiltration Over Alternative Protocol)
