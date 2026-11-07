# attack-tactic-triage

## Concepts

MITRE ATT&CK organises adversary behaviour into **tactics** (the *why* — the goal) and **techniques**
(the *how*). Read left-to-right, the tactics tell the story of an intrusion. When you triage an alert,
the first question is **"what tactic is this serving?"** — that tells you where in the lifecycle you
are and what the adversary likely does next.

**The 15 tactics (current v19, 2026):**

| # | Tactic (ID) | The goal |
|---|---|---|
| 1 | Reconnaissance (TA0043) | Gather info on the target |
| 2 | Resource Development (TA0042) | Build/buy infrastructure & tools |
| 3 | Initial Access (TA0001) | Get the first foothold |
| 4 | Execution (TA0002) | Run malicious code |
| 5 | Persistence (TA0003) | Survive reboots / credential changes |
| 6 | Privilege Escalation (TA0004) | Gain higher permissions |
| 7 | **Stealth (TA0005)** | Hide and look normal |
| 8 | **Defense Impairment (TA0112)** | Break/blind security tooling |
| 9 | Credential Access (TA0006) | Steal account credentials |
| 10 | Discovery (TA0007) | Learn the environment |
| 11 | Lateral Movement (TA0008) | Move to other systems |
| 12 | Collection (TA0009) | Gather target data |
| 13 | Command and Control (TA0011) | Communicate with compromised hosts |
| 14 | Exfiltration (TA0010) | Steal the data out |
| 15 | Impact (TA0040) | Disrupt, destroy, extort |

- **The v19 split (the currency point).** Until v18, tactic #7 was a single **Defense Evasion**
  tactic. In v19 (2026) it was split in two, because "evasion" meant two different things:
  - **Stealth (TA0005)** — hide and blend in (Masquerading, Indicator Removal, Process Injection,
    Hide Artifacts). The security tooling is **left intact**; the adversary just looks normal.
  - **Defense Impairment (TA0112)** — **break** security mechanisms and tooling (Disable or Modify
    Tools, Disable System Firewall, Modify Registry, Prevent Command History Logging) so defenders
    can't see or trust what's happening.
  Content that still says "Defense Evasion / Impair Defenses (T1562)" is out of date.
- **Not strictly linear.** Real intrusions loop — Discover, move Laterally, Discover again, escalate,
  and so on. The tactics are goals an adversary *may* pursue, not a fixed sequence.

## Tasks

Start the lab with `./lab up attack-tactic-triage`, then open a shell:
`./lab shell attack-tactic-triage`.

The folder **`/opt/triage/cases/`** holds 15 observed behaviours (`case-01.txt` … `case-15.txt`), one
per tactic. Read each and decide which **tactic** it serves:

```
cat /opt/triage/cases/case-01.txt
```

Record your answers in **`/root/answers.txt`** — `CASE_01` … `CASE_15` — using the tactic **name or
its TA id** (e.g. `CASE_01=Reconnaissance` or `CASE_01=TA0043`). Then fill in `V19_SPLIT` with the two
tactics the old Defense Evasion became.

Two of the cases deliberately test the v19 split: one is **Stealth** (blend in, tooling intact), one
is **Defense Impairment** (disable the tooling) — tell them apart.

Check your work from the host: `./lab check attack-tactic-triage`.

<details>
<summary>Hints</summary>

- Map the *behaviour* to the *goal*: a failed-logon spike is Credential Access; a new scheduled task
  is Persistence; mass encryption is Impact.
- Case 07 vs 08: renaming a binary to look legit = **Stealth**; turning off the EDR = **Defense
  Impairment**. (Both were "Defense Evasion" before v19 — don't use that retired name here.)
- Both the tactic name and the `TA00xx` id are accepted.

</details>

## My notes

<!-- Screenshots: ./lab shot attack-tactic-triage ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `ransomware-kill-chain` — map one intrusion to the Cyber Kill Chain and ATT&CK, refang its IoCs.
- `blackcat-case-study`, `conti-case-study`, `lockbit-case-study` — full intrusions you can label by tactic.
