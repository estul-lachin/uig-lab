# wazuh-web-attack-triage

## Concepts

A public web server is probed all day. The three classic techniques, and what each is after:

| Technique | Looks like (in the URL) | Goal |
|---|---|---|
| **SQL injection** | `id=1 union select ...`, `' or 1=1--` | Read or change the database |
| **Cross-site scripting (XSS)** | `<script>`, `<iframe`, `onload=` (URL-encoded: `%3Cscript%3E`) | Run script in other users' browsers, steal sessions |
| **Directory traversal** | `../../../../etc/passwd` | Read files outside the web root |

Wazuh decodes the access log (`web-accesslog` decoder: `data.srcip`, `data.url`, the status code as
`data.id`) and runs it through `0245-web_rules.xml`:

| Rule | Level | Meaning |
|---|---|---|
| 31100 | 0 | Any access-log line (the parent, never alerts by itself) |
| 31108 | 0 | A simple, harmless request (ignored) |
| **31101** | 5 | Status **4xx** that matched nothing more specific |
| **31103** | 7 | **SQL injection** attempt |
| **31104** | 6 | "Common web attack": **directory traversal** (`../..`, `%2E%2E`), `cmd.exe`, ... |
| **31105** | 6 | **XSS** attempt |
| **31106** | 6 | **A web attack that returned 200**. It *replaces* 31103/31104/31105 for that request |
| 31151, 31152 | 10 | Frequency rules: many 400s, or many SQL injections, from one IP in a short time. They replace the alert that tipped them over |

Things that matter when you count:

- A technique count (`rule.id: 31103`) only holds the **failed** attempts. The one that worked is
  31106, and that is the alert to escalate first.
- `rule.groups: attack` is wider than "the three techniques": it also holds every plain 4xx (31101).
  A scanner that only collects 404s can top that ranking without a single injection.
- An attacker who spreads their effort over several techniques is never first in any single one.
  Rank across all of them.
- Rules match patterns, and attackers vary the encoding. If a variant isn't in the list, the request
  is just a 4xx (or, with a 200, no alert at all). The raw log is still there to read.

**This lab has no dashboard.** The manager writes every alert as one JSON object per line to
`/var/ossec/logs/alerts/alerts.json`, and `jq` answers what Discover would:

```
jq -r 'select(.rule.groups | index("web")) | .rule.id' /var/ossec/logs/alerts/alerts.json | sort | uniq -c
jq -c 'select(.data.srcip == "192.0.2.1") | {id: .rule.id, url: .data.url, status: .data.id}' /var/ossec/logs/alerts/alerts.json
```

## Tasks

Start the lab with `./lab up wazuh-web-attack-triage`, then open a shell with `./lab shell wazuh-web-attack-triage`. You are root on the Wazuh manager. A minute or two
after start-up it reads one morning of web-server-01's nginx access log
(`/var/log/lab/web-server-01-access.log`; `/var/lib/lab-feed-done` appears when that is done).
Write `KEY=value` answers to `/root/answers.txt`.

1. **The core questions.**

   ```
   SQLI_31103=<SQL injection alerts, rule 31103>
   XSS_31105=<cross-site scripting alerts, rule 31105>
   TRAVERSAL_31104=<directory traversal alerts, rule 31104>
   TOP_ATTACKER=<the source IP with the most alerts across those three rules>
   TOP_ATTACKER_COUNT=<its alerts across those three rules>
   ```

2. **What the technique counts don't show.**

   ```
   SUCCESS_RULE=<the rule id an attack that got status 200 ends in>
   SUCCESS_IP=<the source IP of that attack>
   GROUP_TOP=<the source IP that rule.groups attack ranks first>
   ENCODED_400=<traversal attempts with URL-encoded slashes that were filed only as 31101>
   LEAKED_FILE=<the file an encoded traversal fetched with status 200, as an absolute path>
   ```

3. **A rule for encoded traversal.** In `/var/ossec/etc/rules/local_rules.xml`, add rule **100330**,
   **level 10**, for a URL that climbs directories with URL-encoded separators: `..%2F`, `..%5C`,
   `%2e%2e%2f`, ... in any letter case, **whatever the status code**. Plain `../..` must stay 31104,
   and SQL injection and normal requests keep their rules. Validate with
   `/var/ossec/bin/wazuh-analysisd -t`, restart with `/var/ossec/bin/wazuh-control restart`, and try
   it with `wazuh-logtest`.

Check your work from the host: `./lab check wazuh-web-attack-triage`

<details>
<summary>Hints</summary>

- `.rule.id`, `sort`, `uniq -c` shows what the stream is made of; `wc -l` counts lines
- For the ranking, one select with the three rule ids, then `.data.srcip | sort | uniq -c | sort -rn`
- Compare the top attacker's count per rule id with the leader of each single technique
- For the group ranking, print the rule ids of the IP in first place
- `.data.url` of the 31101 alerts; `%2F` is `/` and `%5C` is `\`
- The request that leaked a file left no alert; `grep` the access log for the same pattern, then
  look at the status column
- Paste a 404 and a 200 line into `wazuh-logtest`: they leave 31100 through different children,
  so the rule needs more than one parent in `<if_sid>`. `<url type="pcre2">` takes `(?i)`

</details>

## My notes

<!-- Screenshots: ./lab shot wazuh-web-attack-triage ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [wazuh-alert-triage](../wazuh-alert-triage/): web attacks among other alerts, in a full Wazuh stack with Discover
- [wazuh-sudo-abuse](../wazuh-sudo-abuse/): the same jq-on-alerts.json approach for sudo
- [siem-correlation-rules](../siem-correlation-rules/): writing and testing Wazuh rules
- OWASP: SQL Injection, Cross Site Scripting, Path Traversal; MITRE ATT&CK T1190 (Exploit Public-Facing Application)
