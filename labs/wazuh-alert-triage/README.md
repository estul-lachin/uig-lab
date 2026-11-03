# wazuh-alert-triage

## Concepts

A SIEM rarely hands you one clean attack. At the start of a shift the alert index is a blend:
authentication, web and file-integrity alerts mixed together, plus the SIEM's own housekeeping.
**Triage** means slicing that blend before chasing any single thread:
1. How big is it?
2. Which categories are loud?
3. Who are the loudest sources?
4. Is anything in there not just noise, but a success?

**Wazuh** is an open-source SIEM/XDR. This lab runs a single-node Wazuh in Docker:

| Component | Role |
|---|---|
| `wazuh.manager` | Reads logs and watches files, decodes them, runs the rule set, writes alerts |
| `wazuh.indexer` | OpenSearch: stores the alerts in the `wazuh-alerts-4.x-YYYY.MM.DD` indices |
| `wazuh.dashboard` | OpenSearch Dashboards plus the Wazuh app: Discover, visualizations |

A shop server, `web-01`, sends its SSH log and web access log and has its web root watched by file
integrity monitoring (**FIM**, `syscheck` in Wazuh).

**What an alert carries**:

| Field | Meaning |
|---|---|
| `rule.id` | The rule that fired: the most precise way to pick one alert type |
| `rule.groups` | Category tags on the rule (`authentication_failed`, `syscheck`, `attack`, ...); several rules share a group |
| `rule.level` | Severity, 0 to 15 |
| `rule.description` | What the rule says happened |
| `data.srcip`, `data.srcuser`, `data.dstuser` | Fields the decoder pulled out of the log line |
| `syscheck.path`, `syscheck.event` | FIM: which file, and added / modified / deleted |

**One log line, one rule, and which one depends on details**:
- The same SSH brute force shows up as different rules. An unknown user is one rule, a wrong
  password for a real account is another. When enough of either arrive from one address, a third
  *frequency* (correlation) rule fires on top. Filtering on one `rule.id` and on a whole `rule.group`
  answers different questions.
- Web rules look at the request *and* the status code. The same injection attempt can land in
  different rules depending on what the server answered. The alert that matters most is the one
  saying the attack **succeeded**.
- FIM alerts only for changes after the first (baseline) scan. Modified and added files are
  different rules.

**Discover** (Wazuh menu > Explore > Discover):
- The **index pattern** is `wazuh-alerts-*`. The **time picker** decides which alerts count at all.
- The search bar takes **DQL**: `rule.id:5710`, `rule.groups:syscheck and not rule.id:550`,
  `data.srcip:203.0.113.*`.
- Click a field in the sidebar to see its **top values** (based on a sample of 500 documents; for
  exact numbers use a visualization, or check that the sample covers all hits).
- **Save** stores the query and columns as a saved search, for the next shift.

## Tasks

Start the lab with `./lab up wazuh-alert-triage`. It needs about 3 GB of memory and a few minutes the
first time. Stop other big labs (Splunk) first. Open **https://localhost:8443** (the certificate is the
lab's own; accept the browser warning) and log in as `admin` with the lab password `Lab-Wazuh-2026`.

`web-01` sends its activity once, a minute or two after start-up; the shell banner in
`./lab shell wazuh-alert-triage` tells you how to see that it's done. Pick a time range that covers
the whole session (for example *Last 24 hours*). Write `KEY=value` answers to `/root/answers.txt` in
that shell.

1. **The whole stream.** `TOTAL_ALERTS=<all alerts, no filter>`
2. **SSH.**

   ```
   TOP_INVALID_USER_SRC=<the data.srcip with the most rule.id 5710 alerts>
   TOP_AUTH_FAILED_SRC=<the data.srcip with the most rule.groups authentication_failed alerts>
   TOP_SSH_USERNAME=<the data.srcuser tried most often in rule.id 5710>
   BREACHED_ACCOUNT=<the account a brute-forcing address then logged in as>
   ```

   Why do the first two differ?
3. **File integrity.**

   ```
   FIM_MODIFIED=<alerts for modified files, rule.id 550>
   FIM_TOP_FILE=<the full path of the file modified most often>
   NEW_FILE=<the full path of the file added to the web root>
   ```

   Look at what that new file is called and where it is. Would you have expected it in a web root?
4. **Web attacks.**

   ```
   SQLI_ALERTS=<SQL injection alerts, rule.id 31103>
   SQLI_SUCCESS_SRC=<the source address of the web attack that returned 200>
   ```

5. **For the next shift.** In Discover, save a search named `ssh-invalid-users` whose query is
   `rule.id:5710`.

Check your work from the host: `./lab check wazuh-alert-triage`. When you're done,
`./lab down wazuh-alert-triage` frees the memory.

<details>
<summary>Hints</summary>

- The hit count sits at the top of Discover; `rule.id` in the field list shows what the blend is made of
- `rule.groups:authentication_failed`, then the `rule.id` field: there is more than 5710 in there
- A successful login is `rule.groups:authentication_success`; compare its `data.srcip` values with the failures
- `rule.groups:syscheck`, then `syscheck.event` and `syscheck.path`
- `rule.groups:attack`, then `rule.description`: one of them is about a 200
- No answer should come from guessing: if the top-values sample is smaller than the hit count,
  narrow the query until it covers all hits

</details>

## My notes

<!-- Screenshots: ./lab shot wazuh-alert-triage ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [syslog-collector](../syslog-collector/): getting logs into a SIEM, and parsing them per source
- [splunk-spl-fundamentals](../splunk-spl-fundamentals/): the same kind of slicing in SPL
- [ransomware-qr-phishing](../ransomware-qr-phishing/): following one thread once triage has found it
- Wazuh documentation: ruleset (rule IDs and groups), File integrity monitoring, Discover
