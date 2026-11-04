# wazuh-sudo-abuse

## Concepts

`sudo` lets an ordinary user run commands as root, and it logs every attempt, failed or not, to the
auth log. That makes it the place to see **privilege escalation**: the step between "an attacker has a
user account" and "an attacker owns the machine". Many failures from one user is a warning. The same
user then succeeding is an incident.

**Wazuh's sudo rules** (in `0020-syslog_rules.xml`; the user is `data.srcuser`, the target
`data.dstuser`, the command `data.command`):

| Rule | Level | Line |
|---|---|---|
| **5401** | 5 | `user : 1 incorrect password attempt ; ...` (and 2) |
| **5404** | 10 | `user : 3 incorrect password attempts ; ...` |
| 5405 | 5 | `user : user NOT in sudoers ; ...` |
| 5406 | | `user : command not allowed ; ...`: in sudoers, but not for this command |
| **5402** | 3 | A successful sudo **to root** |
| **5403** | 4 | **The first time** a user runs sudo successfully, to *any* target user. It *replaces* 5402 (or 5407) for that event |
| 5407 | | A successful sudo to another user (for example `-u www-data`) |
| 5902 | 8 | `useradd: new user ...` |

So "how many successful escalations" can't be answered with 5402 alone. Rule 5403 can hide exactly
the moment that matters most: a user's first time.

**Allowed is not safe.** A sudoers line such as `dkim ALL=(root) /usr/bin/vim /etc/nginx/nginx.conf`
looks harmless. But inside vim, `:!/bin/bash` starts a shell, and it is a root shell. The **GTFOBins**
project lists the programs that can do this (`vim`, `less`, `more`, `find`, `awk`, `python`, `perl`,
...). Neither the shell nor anything run in it appears as a sudo line afterwards. What follows shows
up only as effects, such as a new account with UID 0.

**This lab has no dashboard.** A Wazuh manager writes every alert as one JSON object per line to
`/var/ossec/logs/alerts/alerts.json`, and `jq` answers the same questions Discover would:

```
jq -r 'select(.rule.id == "5401") | .data.srcuser' /var/ossec/logs/alerts/alerts.json | sort | uniq -c
jq -c 'select(.data.srcuser == "someone") | {id: .rule.id, cmd: .data.command}' /var/ossec/logs/alerts/alerts.json
```

## Tasks

Start the lab with `./lab up wazuh-sudo-abuse`, then open a shell with `./lab shell wazuh-sudo-abuse`. You are root on the Wazuh manager. A minute or two after start-up it
reads one afternoon of web-server-01's auth log (`/var/lib/lab-feed-done` appears when that is done).
Write `KEY=value` answers to `/root/answers.txt`.

1. **The course questions.**

   ```
   FAILED_5401=<failed sudo attempts, rule 5401>
   TOP_FAILER=<the user with the most of them>
   FAILER_5401=<how many of them are that user's>
   SUCCESS_5402=<successful sudo to root, rule 5402>
   FAILER_5402=<rule-5402 alerts for that user>
   ```

2. **What rule 5402 doesn't show.**

   ```
   FIRST_TIME_RULE=<the rule a user's first successful sudo gets instead of 5402>
   FAILER_ROOT_TOTAL=<all successful sudo to root by that user>
   ESCALATION_BINARY=<the program sudo let that user run as root, e.g. name>
   BACKDOOR_USER=<the account created right after the breakthrough>
   ```

3. **A rule for it.** In `/var/ossec/etc/rules/local_rules.xml`, add rule **100300**, **level 12**:
   - a successful sudo to root (a child of 5402 and 5403),
   - whose command is one of `vi`, `vim`, `less`, `more`, `find`, `awk`, `perl`, `python`, `python3`,
     `bash` or `sh`.

   Match the program being run, not just any word in the command line. Validate with
   `/var/ossec/bin/wazuh-analysisd -t`, restart with `/var/ossec/bin/wazuh-control restart`, and try
   it with `wazuh-logtest`.

Check your work from the host: `./lab check wazuh-sudo-abuse`

<details>
<summary>Hints</summary>

- `jq -r '.rule.id' alerts.json | sort | uniq -c` shows what the stream is made of
- `select(.rule.id == "5401" and .data.srcuser == "...")`; `wc -l` counts lines
- For the top failer, list every `rule.id` with its `data.command`, in order: where does the first
  success sit?
- `select(.rule.id == "5902") | .full_log`
- One `<if_sid>` that lists both parent rules, comma-separated, and a
  `<field name="command" type="pcre2">` match; anchor on the path: `^\S*/(vim?|less|...)(\s|$)`
- A logtest session remembers sudo users, so a repeat in the same session is 5402, not 5403
- 5403 also covers a first `sudo -u www-data`: the rule must check that the target is root too.
  `dstuser` is a static field, so `<field name="dstuser">` is refused; static fields have their own
  options (the target user is `<user>`)

</details>

## My notes

<!-- Screenshots: ./lab shot wazuh-sudo-abuse ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [wazuh-alert-triage](../wazuh-alert-triage/): the same alerts in a full Wazuh stack with Discover
- [siem-correlation-rules](../siem-correlation-rules/): writing and testing Wazuh rules
- [users-sudo](../users-sudo/): sudo and sudoers on the host itself
- GTFOBins (gtfobins.github.io), MITRE ATT&CK T1548.003 (Sudo and Sudo Caching)
