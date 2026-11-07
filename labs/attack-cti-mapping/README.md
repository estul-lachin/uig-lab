# attack-cti-mapping

## Concepts

This is **ATT&CK operating** — the cyber-threat-intelligence (CTI) side. ATT&CK records *who* uses
behaviours, not just the behaviours:

- **Group (`G####`)** — a tracked adversary / intrusion set, often a named APT (e.g. APT29 / G0016).
- **Software (`S####`)** — malware and tools (Mimikatz, Cobalt Strike), mapped to the techniques they
  implement.
- **Campaign (`C####`)** — a time-bounded set of activity with shared objectives.

They interlink: *a Group uses Software that implements Techniques, observed during a Campaign.*

- **The core CTI skill — mapping.** Read a prose report and translate each behaviour into a
  **technique ID**: "sent a spearphishing attachment" → `T1566.001`; "executed PowerShell" →
  `T1059.001`; "dumped LSASS with Mimikatz" → `T1003.001`. Mapping turns unstructured intel into
  structured, comparable, machine-usable data, and lets intel, detection and red teams share one
  language.
- **Operational uses.** *Alert enrichment* (detections tagged with technique IDs), and *threat
  hunting* (form a hypothesis from a technique — "if T1059.001, hunt PowerShell in
  `wineventlog:security`" — and search proactively).
- **Adversary emulation (prove coverage).** **Atomic Red Team** (Red Canary's single-technique
  tests), **CALDERA** (MITRE's automated emulation platform), **ATT&CK Evaluations** (MITRE Engenuity
  vendor evals). Red (emulation) + blue (detection) on common ground = **purple teaming**.
- **Complementary frameworks & data.** **D3FEND** (MITRE's defensive-countermeasure graph),
  **MITRE Engage** (deception), and **STIX / TAXII** (the machine-readable format ATT&CK ships in).

## Tasks

Start the lab with `./lab up attack-cti-mapping`, then open a shell:
`./lab shell attack-cti-mapping`.

```
cat /opt/cti/report.txt       # a prose intrusion report, 10 numbered behaviours
cat /opt/cti/ecosystem.txt     # 5 ecosystem projects to name
```

Fill in **`/root/answers.txt`**:

- **A.** `MAP_1`…`MAP_10` — each behaviour's ATT&CK **technique ID** (the parent `T####` or the exact
  `T####.###` sub-technique is accepted).
- **B.** `ATOMIC`, `EMULATION`, `DEFENSE`, `PURPLE`, `STIX` — the ecosystem projects/terms.

Check your work from the host: `./lab check attack-cti-mapping`.

<details>
<summary>Hints</summary>

- Phishing is `T1566` (attachment = `.001`); PowerShell is `T1059.001`; scheduled task is `T1053.005`;
  LSASS dumping is `T1003.001`.
- Account discovery of a domain group is `T1087.002`; SMB admin-share lateral movement is `T1021.002`;
  web-protocol C2 is `T1071.001`.
- Exfil over the C2 channel is `T1041`; clearing Windows event logs is `T1070.001`; ransomware
  encryption is `T1486`.
- Ecosystem: single-technique tests = Atomic Red Team; automated emulation = CALDERA; defensive graph
  = D3FEND; red+blue = purple teaming; machine format = STIX/TAXII.

</details>

## My notes

<!-- Screenshots: ./lab shot attack-cti-mapping ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `attack-tactic-triage` — classify behaviours by tactic; `attack-structure-drill` — the object model.
- `ransomware-kill-chain` — map one intrusion to the Cyber Kill Chain and ATT&CK, refang its IoCs.
