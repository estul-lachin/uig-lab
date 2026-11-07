# wazuh-rootcheck-trojans

## Concepts

**Rootcheck** is the host-based anomaly scanner inside every Wazuh agent. Every 12 hours (by
default) it looks for signs that someone with root has tampered with the system itself:

| Check | What it looks for | Example message |
|---|---|---|
| Trojans (`rootkit_trojans.txt`) | System binaries (`ls`, `login`, `sudo`, `ps`, ...) that contain strings known from trojaned builds | `Trojaned version of file '/usr/bin/ls' detected. Signature used: ...` |
| Rootkit files (`rootkit_files.txt`) | Files that known rootkits install | `Rootkit 'X' detected by the presence of file '...'` |
| `/dev` | Regular files in `/dev`, a classic hiding place | `File '/dev/.lib/x' present on /dev. Possible hidden file.` |
| Processes, ports | PIDs or listening ports the system tools don't show | `Process '4242' hidden from /proc. ...`, `Port '31337'(tcp) hidden. ...` |
| Interfaces, directories | Promiscuous NICs; link counts that don't match the files `ls` shows | `Interface 'eth0' in promiscuous mode.` |

Swapping a binary like `login` or `sudo` for a trojaned one gives the attacker a hidden backdoor or
a password logger. That makes a trojan finding a hands-on-keyboard indicator, not noise.

**Wazuh's rootcheck rules** (in `0015-ossec_rules.xml`; every alert has `location` `rootcheck`, the
host is `agent.name`, the decoder fills `data.title` and, for files, `data.file`):

| Rule | Level | Event |
|---|---|---|
| 509 | 0 | Any rootcheck message (the parent, never alerts by itself) |
| **510** | 7 | **Host-based anomaly detection event**: almost every finding ends here |
| **521** | 11 | A child of 510 for messages that say **"Possible kernel level rootkit"** (hidden processes). It *replaces* 510 for that event |
| 515 | 0 | Scan start/end messages, ignored |

So "how many rootcheck findings does this host have" is not the same question as "how many rule-510
alerts". The group `rootcheck` covers them all.

**Counting is ranking, not triage.** Some hosts are noisy for harmless reasons: build runners and
databases keep lock files in `/dev/shm`, and a NIC used for monitoring is in promiscuous mode on
purpose. Others are quiet and compromised. The title of a finding matters more than how many there are.

**This lab has no dashboard.** The manager writes every alert as one JSON object per line to
`/var/ossec/logs/alerts/alerts.json`, and `jq` answers what Discover would:

```
jq -r 'select(.location == "rootcheck") | .rule.id' /var/ossec/logs/alerts/alerts.json | sort | uniq -c
jq -c 'select(.agent.name == "some-host") | {id: .rule.id, title: .data.title, file: .data.file}' /var/ossec/logs/alerts/alerts.json
```

## Tasks

Start the lab with `./lab up wazuh-rootcheck-trojans`, then open a shell with `./lab shell wazuh-rootcheck-trojans`. You are root on the Wazuh manager. A minute or two
after start-up it receives the latest rootcheck results of seven fleet hosts (`/var/lib/lab-feed-done`
appears when that is done). Write `KEY=value` answers to `/root/answers.txt`.

1. **The core questions.**

   ```
   RC_TOTAL=<rootcheck detections, rule 510, all hosts>
   WORST_HOST=<the host (agent.name) with the most of them>
   WORST_COUNT=<rule-510 detections on that host>
   TROJAN_FILE=<full path of the trojaned binary on that host>
   SECOND_HOST=<the host in second place>
   ```

2. **What the 510 count doesn't show.**

   ```
   KERNEL_RULE=<the rule id hidden processes get instead of 510>
   WORST_ALL=<every rootcheck alert on the worst host, 510 and its children>
   TROJAN_HOSTS=<how many hosts have at least one trojaned binary>
   QUIET_TROJAN_HOST=<the infected host near the bottom of the ranking>
   QUIET_TROJAN_FILE=<full path of its trojaned binary>
   ```

3. **A rule for trojaned binaries.** In `/var/ossec/etc/rules/local_rules.xml`, add rule **100320**,
   **level 12**, for rootcheck's trojaned-binary findings. Every other rootcheck finding must keep its
   rule (510, or 521 for hidden processes). Validate with `/var/ossec/bin/wazuh-analysisd -t` and
   restart with `/var/ossec/bin/wazuh-control restart`. The check hands the manager a few rootcheck
   messages from a probe host to see which rule fires.

Check your work from the host: `./lab check wazuh-rootcheck-trojans`

<details>
<summary>Hints</summary>

- `jq -r '.agent.name'` on the 510 alerts, then `sort | uniq -c | sort -rn`, is the ranking
- Print `.data.title` next to `.data.file`: only one kind of title names a trojan
- For part 2, count rule ids per host without filtering on 510 first
- A ranking by count puts the quiet infection near the bottom; filter on the title, then list hosts
- The rule is a child of 510 with a `<match>` on the start of the message (`^...`); a match on just
  `trojaned` would also catch the hidden-port message, which mentions a trojaned netstat
- Rule 521 is also a child of 510: a rule that matches too broadly takes those events away from it

</details>

## My notes

<!-- Screenshots: ./lab shot wazuh-rootcheck-trojans ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [wazuh-fim-intrusion](../wazuh-fim-intrusion/): the file-change side of the same kind of intrusion (syscheck)
- [wazuh-sudo-abuse](../wazuh-sudo-abuse/): the same jq-on-alerts.json approach for sudo
- [siem-correlation-rules](../siem-correlation-rules/): writing and testing Wazuh rules
- MITRE ATT&CK T1554 (Compromise Host Software Binary), T1014 (Rootkit)
