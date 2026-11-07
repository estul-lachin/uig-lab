# wazuh-fim-intrusion

## Concepts

**File integrity monitoring (FIM)** keeps a baseline of watched files (hashes, size, owner,
permissions) and raises an alert whenever one changes. In Wazuh the engine is called **syscheck**.
An intruder almost always touches the disk: they weaken a config, drop a tool or a persistence hook,
and delete logs to cover their tracks. FIM turns that into a change log the analyst can read later.

| Rule | Level | Event (`syscheck.event`) |
|---|---|---|
| **550** | 7 | A watched file was **modified** (its checksum changed) |
| **554** | 5 | A file was **added** |
| **553** | 7 | A file was **deleted** |

All three are in the group `syscheck`. Useful alert fields:

| Field | Meaning |
|---|---|
| `syscheck.path` | Full path of the file |
| `syscheck.event` | `added`, `modified` or `deleted` |
| `syscheck.diff` | With `report_changes`: the lines that changed, in `diff` format (`<` old, `>` new) |
| `syscheck.mode` | `scheduled` (found by a periodic scan) or `realtime` (inotify) |

How it is configured, in the `<syscheck>` block of `ossec.conf`:

```
<directories realtime="yes" report_changes="yes">/etc/ssh,/etc/cron.d</directories>
```

- The **first scan only builds the baseline**: no alerts. Only later changes alert.
- Without `realtime="yes"` changes are found only at the next scheduled scan (default every 12 h).
- `report_changes` keeps a copy of each text file, so a modification alert carries the diff. An
  **added** file has no diff: you have to look at the file itself.
- The stock config ignores `*.log` files. Fine for noise, but then deleted logs never alert.

**Persistence through cron** (MITRE ATT&CK T1053.003): any file in `/etc/cron.d/` (or a script in
`/etc/cron.daily/`, `/etc/cron.hourly/`, ...) is run by cron with the user named in the line,
usually root, and survives a reboot. A new file there is worth a high-level alert of its own, and
FIM rules can be extended like any other rule: a child of 554 with a match on the `file` field.

**This lab has no dashboard.** The manager writes every alert as one JSON object per line to
`/var/ossec/logs/alerts/alerts.json`, and `jq` answers what Discover would:

```
jq -r 'select(.rule.groups | index("syscheck")) | .rule.id' /var/ossec/logs/alerts/alerts.json | sort | uniq -c
jq -c 'select(.syscheck.event == "deleted") | .syscheck.path' /var/ossec/logs/alerts/alerts.json
```

## Tasks

Start the lab with `./lab up wazuh-fim-intrusion`, then open a shell with `./lab shell wazuh-fim-intrusion`. You are root on web-server-01, which runs a Wazuh
manager that watches its own SSH, sudo, cron, web root, web log and `/usr/local/bin` directories in
real time. A minute or two after start-up an intruder goes to work on it; when they are done,
`/var/lib/lab-intrusion-done` appears. Answer about the intruder's changes (anything you change
yourself afterwards doesn't count). Write `KEY=value` answers to `/root/answers.txt`.

1. **The core questions.**

   ```
   MODIFIED_550=<files modified, rule 550>
   ADDED_554=<files added, rule 554>
   DELETED_553=<files deleted, rule 553>
   PERSISTENCE_FILE=<full path of the file added under /etc/cron.d>
   FIM_TOTAL=<all FIM events of the intrusion: modified + added + deleted>
   ```

2. **What the diffs say.** Counting is not an investigation. Read what changed:

   ```
   SSHD_SETTING=<the sshd_config setting the intruder changed, e.g. Port>
   EXFIL_HOST=<the IP address the modified backup script now uploads to>
   WEBSHELL=<full path of the added file that the modified index.php now loads>
   CRON_RUNS=<full path of the program the new cron job runs>
   ```

3. **A rule for new cron jobs.** In `/var/ossec/etc/rules/local_rules.xml`, add rule **100310**,
   **level 12**, for a file **added** in `/etc/cron.d`, `/etc/cron.daily`, `/etc/cron.hourly`,
   `/etc/cron.weekly` or `/etc/cron.monthly`. Files added anywhere else must stay ordinary 554
   alerts. Validate with `/var/ossec/bin/wazuh-analysisd -t` and restart with
   `/var/ossec/bin/wazuh-control restart`. The check drops test files into the watched directories
   (and removes them again) to see which rule fires.

Check your work from the host: `./lab check wazuh-fim-intrusion`

<details>
<summary>Hints</summary>

- `.rule.id`, `sort`, `uniq -c` shows what the stream is made of; `wc -l` counts lines
- For one change type, print `.syscheck.path` as well as the count: which directories were hit?
- `jq -r` prints a diff with real line breaks; `>` lines are what the file says now
- Two of the answers in part 2 come from chaining: a modified file points at an added one
- The rule is a child of the "file added" rule; the path is the `file` field, and a `pcre2` match
  anchored with `^` keeps `/var/www/...` out
- Real-time FIM needs a few seconds after a restart before it watches again

</details>

## My notes

<!-- Screenshots: ./lab shot wazuh-fim-intrusion ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [wazuh-alert-triage](../wazuh-alert-triage/): FIM alerts among others, in a full Wazuh stack with Discover
- [wazuh-sudo-abuse](../wazuh-sudo-abuse/): the same jq-on-alerts.json approach for sudo
- [siem-correlation-rules](../siem-correlation-rules/): writing and testing Wazuh rules
- MITRE ATT&CK T1053.003 (Cron), T1070.002 (Clear Linux or Mac System Logs), T1505.003 (Web Shell)
