# siem-correlation-rules

## Concepts

A SIEM takes in thousands of events a second. **Rules** keep testing that stream for behaviour worth a
human's time. IBM QRadar describes its detection model in three layers:

| QRadar | What it is | Fires on its own? |
|---|---|---|
| **Building Block** | A reusable test that isn't malicious by itself: "is an authentication server", "is a privileged account" | No, it's a building piece for rules |
| **Rule** | Higher-level logic that uses building blocks: event patterns, **thresholds** (counts in a time window), **correlation** (several events in a pattern), plus response actions | Yes |
| **Offense** | The container QRadar opens when rules match: related events and flows, possibly across networks, grouped into one incident that an analyst owns | It is the result |

More on how QRadar handles them:
- **Writing rules**: in QRadar, rules are written in the **Rule Wizard**.
- **Ordering**: the Offenses tab lists offenses by **magnitude**, highest first. Magnitude blends
  *severity*, *relevance* and *credibility*, so it isn't severity alone.
- **Investigating**: an offense opens on the Offense Summary. **Events** lists everything in it, and
  double-clicking an event shows its payload.
- **Beyond static rules**: anomaly detection, threat intelligence feeds, behavioural analytics and risk
  scoring.

**The same ideas in Wazuh.** This lab runs a Wazuh manager on its own, without the indexer and the
dashboard. Its rule engine maps onto QRadar like this:

| QRadar | Wazuh |
|---|---|
| Building block test ("is privileged") | A **CDB list** looked up from a rule, and a base rule at **level 0** (it matches but never alerts) |
| Rule built on a building block | A child rule: `<if_sid>` names the parent rule |
| Threshold rule | `frequency` and `timeframe` attributes, `<if_matched_sid>`, and `<same_srcip />` to count per address |
| Correlation rule | A rule on the current event (`<if_sid>`) that also requires an earlier match of another rule (`<if_matched_sid>`) from the same address |
| Severity | `level`, 0–15 |
| Testing a rule | `wazuh-logtest`: paste log lines and see the decoder fields and the rule each line ends in |

Wazuh's own rules for sshd do most of the parsing already:

| Rule | Matches | Fields |
|---|---|---|
| **5760** | `Failed password for ...` | `srcip` |
| **5715** | `Accepted password ...` and `Accepted publickey ...` | `srcip` and the user |

Custom rules go in `/var/ossec/etc/rules/local_rules.xml` with IDs from 100000 up. Lists live in
`/var/ossec/etc/lists/`, one `key:` per line, and must be registered under `<ruleset>` in
`/var/ossec/etc/ossec.conf`. `wazuh-analysisd -t` validates the configuration, and
`/var/ossec/bin/wazuh-control restart` loads it.

## Tasks

Start the lab with `./lab up siem-correlation-rules` (the manager needs about a minute), then open a
shell with `./lab shell siem-correlation-rules`. You are root on the Wazuh manager.

1. **The vocabulary.** In `/root/answers.txt`: `BUILDING_BLOCK=<the reusable unit>`, `RULE=<the
   correlation logic>`, `OFFENSE=<the incident container>`, `ORDERED_BY=<what the Offenses tab sorts
   by>`, `RULE_TOOL=<where QRadar rules are written>`.
2. **A building block.** Create the CDB list `privileged-accounts` with `root`, `administrator` and
   `svc_backup`, and register it. Add rule **100100**: a successful SSH logon (a child of 5715) to an
   account in that list, at **level 0**.
3. **A threshold rule.** Rule **100110**, **level 10**: the 6th failed SSH password (5760) from the same
   address within 5 minutes.
4. **A correlation rule.** Rule **100120**, **level 14**: a logon that matches 100100, from an address
   that triggered 100110 in the 10 minutes before. This is the Wazuh version of an offense worth
   waking someone for: guessing that worked, on a privileged account.

Restart the manager after each change and try your rules with `wazuh-logtest` first. The check feeds
in attack sequences and decoys: a burst from one address and the login from another, a login without a
burst, an ordinary user, and five failures instead of six.

Check your work from the host: `./lab check siem-correlation-rules`

<details>
<summary>Hints</summary>

- `/var/ossec/bin/wazuh-logtest`, then paste `Accepted password for root from 192.0.2.9 port 50001 ssh2`
  after a syslog-style timestamp and host, for example `Nov  3 15:02:00 srv sshd[2999]: `
- The list lookup: `<list field="..." lookup="match_key">etc/lists/privileged-accounts</list>`. The
  decoder calls the field `dstuser`, but a list lookup only understands the static name **`user`**
- No restart, no change: logtest uses the rules the manager loaded
- A rule that uses `<if_matched_sid>` needs `frequency` and `timeframe` attributes too, even when it
  only waits for one earlier match; the smallest frequency Wazuh accepts is 2
- Several lines pasted into one logtest session share its memory, which is how frequency rules can be
  tested

</details>

## My notes

<!-- Screenshots: ./lab shot siem-correlation-rules ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [wazuh-alert-triage](../wazuh-alert-triage/): the alerts such rules produce, in a full Wazuh stack
- [syslog-collector](../syslog-collector/): getting logs in and parsing them
- [qradar-log-activity](../../projects/qradar-log-activity/) and
  [qradar-overview-ingestion](../../projects/qradar-overview-ingestion/): QRadar itself
- Wazuh documentation: rules syntax, CDB lists, wazuh-logtest
