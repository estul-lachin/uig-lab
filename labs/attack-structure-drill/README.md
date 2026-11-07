# attack-structure-drill

## Concepts

**ATT&CK** — *Adversarial Tactics, Techniques, and Common Knowledge* — is a free, globally-used
knowledge base of real-world adversary behaviour, curated by **MITRE** from observed intrusions.
Instead of cataloguing vulnerabilities or signatures, it catalogues **what attackers actually do**,
giving every behaviour a stable ID so the whole industry speaks one language. Its philosophy is
**threat-informed defense**: prioritise defenses around how real adversaries behave, not a generic
checklist. (Three domains: Enterprise, Mobile, ICS.)

- **The Pyramid of Pain.** Indicators ranked by how much pain it causes the adversary to change them
  once you detect on them — from trivial at the bottom to expensive at the top:
  ```
  TTPs                 <- hardest to change (most pain)   ATT&CK lives here
  Tools
  Network/Host Artifacts
  Domain Names
  IP Addresses
  Hash Values          <- trivial to change (least pain)
  ```
  Hashes and IPs are cheap to swap; **TTPs** (how an adversary operates) are expensive — which is why
  detecting at that level is so durable.
- **The object model** — layers of *what* and *how*:
  - **Tactic** — the goal, the *why* (e.g. Persistence); the matrix **columns**.
  - **Technique** — *how* a tactic is achieved (e.g. Command and Scripting Interpreter, T1059); the
    **cells**.
  - **Sub-technique** — a more specific variant (e.g. PowerShell, T1059.001).
  - **Procedure** — a real-world implementation by an actual actor or tool (the "Procedure Examples").
- **The ID scheme & supporting objects:**

  | Object | Prefix | Example |
  |---|---|---|
  | Tactic | `TA` | TA0002 (Execution) |
  | Technique / Sub-technique | `T` | T1059 / T1059.001 |
  | Software (malware/tools) | `S` | S0154 (Cobalt Strike) |
  | Group (adversary) | `G` | G0016 (APT29) |
  | Campaign (time-bounded activity) | `C` | C0001 |
  | Mitigation | `M` | M1049 |

- **Related models:** the **Cyber Kill Chain** (7 linear phases) and the **Diamond Model** (Adversary,
  Capability, Infrastructure, Victim). ATT&CK is more granular than the Kill Chain and complements the
  Diamond Model.
- **The v18 detection model.** Before v18, a technique had a vague "Detection" paragraph and a list of
  "Data Sources". v18 retired that for a modular chain —
  **Technique → Detection Strategy → Analytic → Log Sources / Data Components**:
  - **Detection Strategy (`DET####`)** — the **plan**: what behaviour to look for.
  - **Analytic (`AN####`)** — the **implementation**: platform-specific detection logic (one per
    platform) pointing at the exact telemetry.
  - **Data Component** (e.g. Process Creation) — the specific data a system produces; in v18 **Log
    Sources live inside Data Components**, named like `wineventlog:security` or `auditd:SYSCALL`.

## Tasks

Start the lab with `./lab up attack-structure-drill`, then open a shell:
`./lab shell attack-structure-drill`.

Read the three reference files, then fill in **`/root/answers.txt`**:

```
cat /opt/attack/ids.txt       # A. classify each ID by object type
cat /opt/attack/pyramid.txt   # B. the top and bottom of the Pyramid of Pain
cat /opt/attack/levels.txt    # C. tactic vs technique vs procedure
cat /opt/attack/detection.txt # E. the v18 detection model
```

- **A.** `ID_A`…`ID_G` — the object type of each ID (tactic, technique, sub-technique, software,
  group, campaign, mitigation).
- **B.** `PAIN_MOST` / `PAIN_LEAST` — the top (most pain) and bottom (least pain) pyramid levels.
- **C.** `LEVEL_1`…`LEVEL_3` — the object-model level of each item.
- **D.** `ACRONYM`, `MAINTAINER`, `PHILOSOPHY` — the foundations.
- **E.** `PLAN`, `IMPLEMENTATION`, `DET_PREFIX`, `AN_PREFIX`, `LOGSOURCE_HOME`, `WIN_SECURITY` — the
  v18 detection model.

Check your work from the host: `./lab check attack-structure-drill`.

<details>
<summary>Hints</summary>

- The ID prefix gives it away: `TA`→tactic, `T`→technique, `T….001`→sub-technique, `S`→software,
  `G`→group, `C`→campaign, `M`→mitigation.
- Pyramid: hashes are easiest for the attacker to change (least pain); TTPs are hardest (most pain).
- A matrix **column** is a tactic (why); a **cell** is a technique (how); a named real-actor example
  is a procedure.

</details>

## My notes

<!-- Screenshots: ./lab shot attack-structure-drill ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `attack-tactic-triage` — classify observed behaviours by the 15 tactics (the matrix columns).
- `ransomware-kill-chain` — map one intrusion to the Cyber Kill Chain and ATT&CK.
