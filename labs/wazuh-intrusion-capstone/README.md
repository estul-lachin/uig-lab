# wazuh-intrusion-capstone

## Concepts

A real intrusion is not one alert but a **chain** of them: reconnaissance, an attack, access, then
persistence. Each step lands in a different data source (web logs, authentication, file integrity),
and normal traffic and unrelated attacks fill the gaps. **Correlation** means finding the thread that
ties the steps into one actor's story. Usually that thread is the source address, then **time** for
the evidence that has no address (a file appearing on disk).

The rules this lab meets (see [wazuh-web-attack-triage](../wazuh-web-attack-triage/),
[wazuh-ssh-bruteforce](../wazuh-ssh-bruteforce/) and [wazuh-fim-intrusion](../wazuh-fim-intrusion/)):

| Stage | Rule | Meaning |
|---|---|---|
| Recon | **31103** | SQL injection attempt (failed) |
| | **31106** | A web attack that returned 200: *replaces* 31103 for that request |
| Brute force | **5710** | Login attempt with a non-existent user |
| | 5712 | Frequency rule: 8 or more 5710 from one address within 2 minutes, then quiet for a while |
| Access | **5715** | Successful login (`data.dstuser` is the account) |
| | 40112 | A success right after a frequency alert from the same address: replaces 5715 |
| Persistence | **554** | FIM: a file was added (`syscheck.path`, no address) |

**Low and slow.** Frequency rules (5712, 5763) and the correlation built on them (40112) only see
bursts. An attacker who guesses a few names, waits, and disconnects before trying a password never
reaches the threshold: each guess is one `Invalid user` line (5710), and the disconnect
(`Connection closed by invalid user ... [preauth]`) is rule 5722, level 0. Their eventual login is
an ordinary 5715, among the staff's. The defence is a rule that remembers further back:
`<if_matched_sid>` plus `<same_srcip />` and a long `timeframe` on the rule makes a child of 5715
that only fires when the same address failed earlier.

**Persistence with systemd.** A unit file in `/etc/systemd/system/` with `Restart=always` and
`WantedBy=multi-user.target` starts its `ExecStart` program at every boot and restarts it when it
dies (MITRE ATT&CK T1543.002). A new unit there, or a new program in `/usr/local/sbin`, is exactly
what FIM is for.

**This lab has no dashboard.** The manager writes every alert as one JSON object per line to
`/var/ossec/logs/alerts/alerts.json`, and `jq` answers what Discover would:

```
jq -r 'select(.rule.id == "5710") | .data.srcip' /var/ossec/logs/alerts/alerts.json | sort -u > /tmp/a
comm -12 /tmp/a /tmp/b                           # lines that are in both sorted files
jq -c 'select(.data.srcip == "192.0.2.1") | {t: .timestamp, id: .rule.id}' /var/ossec/logs/alerts/alerts.json
```

## Tasks

Start the lab with `./lab up wazuh-intrusion-capstone`, then open a shell with `./lab shell wazuh-intrusion-capstone`. You are root on web-server-01, which runs the shop,
its sshd and a Wazuh manager that reads both logs (`/var/log/lab/`) and watches
`/etc/systemd/system` and `/usr/local/sbin` with FIM. A minute or two after start-up the morning
plays out; `/var/lib/lab-feed-done` appears when it is over. Write `KEY=value` answers to
`/root/answers.txt`.

1. **The core questions.**

   ```
   ATTACKER_IP=<the one data.srcip found in 31103, 5710 and 5715 alike>
   RECON_31103=<its SQL injection alerts>
   BRUTE_5710=<its rule-5710 alerts>
   BREACHED_ACCOUNT=<the account it logged in as>
   PERSISTENCE_FILE=<full path of the systemd unit it dropped>
   NOISE_5710=<rule-5710 alerts from every source>
   ```

2. **The rest of the story.**

   ```
   LEAK_RULE=<the rule id of the attacker's web request that worked>
   LEAK_TABLE=<the database table that request read>
   STORM_RULE=<the frequency rule the noisy brute force triggered, and the attacker never did>
   PERSIST_RUNS=<full path of the program the unit starts>
   C2_PORT=<the port that program connects back to>
   ```

   Put the stages in order with their timestamps. Which part of the story has no alert with the
   attacker's address, and how do you still tie it to them?

3. **A rule for the low-and-slow login.** In `/var/ossec/etc/rules/local_rules.xml`, add rule
   **100350**, **level 12**: a successful SSH login (5715) from an address that had a rule-5710
   alert **within the last hour**. A login from any other address, or with no failure before it,
   stays 5715. Validate with `/var/ossec/bin/wazuh-analysisd -t`, restart with
   `/var/ossec/bin/wazuh-control restart`, and try it with `wazuh-logtest`: paste the failure, then
   the login, in the same session.

Check your work from the host: `./lab check wazuh-intrusion-capstone`

<details>
<summary>Hints</summary>

- Three sorted lists of `.data.srcip` (one per rule id) and `comm -12` twice give the common address
- One address has 31103 and 5710 but never logged in: it is not the attacker
- A 554 alert has no address: compare its `timestamp` with the attacker's login
- `.data.url` of the 31106 alert is URL-encoded: `%20` is a space
- `rule.groups` contains `authentication_failures` for the frequency rules; count the attacker's
  5710 alerts and compare with the threshold
- The persistence files are still on disk: `cat` them
- `timeframe` is an attribute of `<rule>`; `<same_srcip />` is an empty element

</details>

## My notes

<!-- Screenshots: ./lab shot wazuh-intrusion-capstone ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [wazuh-web-attack-triage](../wazuh-web-attack-triage/), [wazuh-ssh-bruteforce](../wazuh-ssh-bruteforce/),
  [wazuh-fim-intrusion](../wazuh-fim-intrusion/): each stage on its own
- [siem-correlation-rules](../siem-correlation-rules/): writing and testing Wazuh rules
- MITRE ATT&CK T1190 (Exploit Public-Facing Application), T1110 (Brute Force), T1078 (Valid
  Accounts), T1543.002 (Systemd Service)
