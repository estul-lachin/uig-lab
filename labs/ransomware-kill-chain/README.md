# ransomware-kill-chain

## Concepts

Modern ransomware is less a piece of malware than a business with suppliers. An analyst's first job with
a new report is to turn its prose into things tools can use: indicators to block and hunt for, and
behaviour mapped to a common vocabulary. Both are done here on a fictional incident, from
`/root/intel/report.txt` and `/root/intel/timeline.csv`.

**The ecosystem**:
- **RaaS** (ransomware-as-a-service): developers build the locker, the payment portal and the leak
  site; **affiliates** carry out intrusions and share the ransom.
- **Initial access brokers** (IABs) break in, or collect stolen logins, and sell the access to
  affiliates. VPN, RDP and cloud admin accounts are their stock.
- **Extortion layers**:
  - *Single*: encryption only.
  - *Double*: data stolen first, with a threat to publish it.
  - *Triple*: adds pressure on third parties, such as DDoS or contacting customers and partners.
  - *Quadruple*: also harassment.

**IoCs and TTPs**: indicators of compromise (IPs, domains, hashes) are evidence of something specific,
and attackers change them cheaply. TTPs (tactics, techniques and procedures) describe *how* they work,
which changes slowly. That's why detections based on behaviour last longer.

**Defanged indicators**: reports write `203.0.113[.]14` and `hxxps://` so that nobody clicks or
resolves them by accident. To use them, extract and *refang*:
- `grep -oE 'pattern'` prints only the matching part of each line, one match per line.
- `sed 's/\[\.\]/./g'` turns `[.]` back into `.`; brackets and dots need escaping in regular
  expressions.
- `sort -u` removes duplicates.
- A careless pattern also catches file names (`a.ps1`) or version numbers, so check the result.

**Two lenses on one attack**:
- **Cyber Kill Chain** (Lockheed Martin), seven stages from the attacker's point of view:
  Reconnaissance, Weaponization, Delivery, Exploitation, Installation, Command and Control, Actions on
  Objectives. It's a strategic, linear picture. Everything after the attacker settles in, including
  credential theft, lateral movement, exfiltration and encryption, falls into the last stage.
- **MITRE ATT&CK**: *tactics* (the why, e.g. Persistence) each holding *techniques* (the how, e.g.
  T1053 Scheduled Task/Job) and sub-techniques (T1053.005). Two tactics come before the intrusion
  itself: Reconnaissance and Resource Development, which includes buying access. ATT&CK is the detailed,
  operational view, and the basis for detections.

## Tasks

Start the lab with `./lab up ransomware-kill-chain`, open a shell with `./lab shell ransomware-kill-chain`.
The shell is `root` in `/root/intel`. Write `KEY=value` answers to `/root/intel/answers.txt`.

1. **IoCs, refanged.** From `report.txt`, extract every indicator, refang it, and write one per line,
   without duplicates:
   - `iocs/ips.txt`: the IPv4 addresses
   - `iocs/domains.txt`: the domain names (including the `.onion` one, not file names)
   - `iocs/sha256.txt`: the file hashes
2. **Mapping the intrusion.** Write `map.csv` with the header `id,killchain,tactic,technique` and one row
   for each of the 12 events in `timeline.csv`:
   - `killchain`: its Cyber Kill Chain stage.
   - `tactic`: its ATT&CK tactic, by name.
   - `technique`: an ATT&CK technique ID; sub-techniques are welcome.

   Names are case-insensitive, and spaces or hyphens are both fine.
3. **The business behind it.** Write `EXTORTION_MODEL=<single, double, triple or quadruple>`,
   `AFFILIATE=<the name of who carried out the intrusion>`, `BROKER_EVENT=<the timeline id that shows an
   initial access broker>` and `C2_DOMAIN=<the command-and-control domain>`.

Check your work from the host: `./lab check ransomware-kill-chain`

<details>
<summary>Hints</summary>

- A defanged IPv4 may mix `.` and `[.]`; match either separator: `(\.|\[\.\])`. Then keep only matches
  that contain `[.]`, refang, and `sort -u`
- A domain ends with `[.]` plus a label that starts with a letter
- A SHA-256 is exactly 64 hex characters, so anchor it with `\b` on both sides
- ATT&CK: attack.mitre.org/tactics/enterprise/ lists the tactics in order; search a behaviour
  (e.g. "lsass") on the site to find its technique
- Which kill chain stage does everything after the foothold belong to?

</details>

## My notes

<!-- Screenshots: ./lab shot ransomware-kill-chain ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [ransomware-qr-phishing](../ransomware-qr-phishing/): finding the facts in logs before mapping them
- [ransomware-drill](../ransomware-drill/): the impact stage, and recovering from it
- MITRE ATT&CK (attack.mitre.org), Lockheed Martin Cyber Kill Chain
