# wazuh-ssh-bruteforce

## Concepts

A **brute force** guesses passwords until one works. Against SSH every guess is logged, so the auth
log holds both the wall of failures and, somewhere inside it, the one success that turns "blocked
attack" into "active breach". The analyst's questions: who is attacking, did anything get in, on
which account, and is the attacker still using it?

What sshd writes, and where Wazuh files it (`0095-sshd_rules.xml`, `0280-attack_rules.xml`):

| sshd line | Rule | Level | Fields |
|---|---|---|---|
| `Invalid user admin from IP port N` | **5710** | 5 | `data.srcuser`, `data.srcip` |
| `Failed password for invalid user admin from IP ...` | **5710** | 5 | the same guess again: one guess, two alerts |
| `Failed password for deploy from IP ...` (the user exists) | **5760** | 5 | `data.dstuser`, `data.srcip` |
| `Accepted password\|publickey for deploy from IP ...` | **5715** | 3 | `data.dstuser`, `data.srcip` |
| 8 or more 5710 from one IP in 2 min | 5712 | 10 | replaces the 5710 that tipped it over |
| 8 or more 5760 from one IP in 2 min | 5763 | 10 | replaces the 5760 that tipped it over |
| A success from an IP that just had a 5712/5763 | **40112** | 12 | **replaces 5715** for that login |
| `pam_unix(sshd:session): session opened` | 5501 | 3 | in `authentication_success` too, but no IP |

What that means for counting:

- 5710 is "**non-existent user**", not "failed login". A guess at a real account is 5760, so the
  failures that matter most (against an account that exists) aren't in 5710 at all.
- Both groups help: `authentication_failed` holds 5710 and 5760, `authentication_failures` the
  frequency rules.
- A filter on 5715 shows the baseline of normal logins, but **not the breach**: Wazuh has already
  correlated it into 40112.
- A stolen password is often used again from a different address, with no failures before it. Only
  a baseline helps there: where do this server's users normally log in from, and how (key or
  password)?

**This lab has no dashboard.** The manager writes every alert as one JSON object per line to
`/var/ossec/logs/alerts/alerts.json`, and `jq` answers what Discover would:

```
jq -r 'select(.rule.groups | index("sshd")) | .rule.id' /var/ossec/logs/alerts/alerts.json | sort | uniq -c
jq -c 'select(.data.srcip == "192.0.2.1") | {id: .rule.id, user: (.data.dstuser // .data.srcuser), log: .full_log}' /var/ossec/logs/alerts/alerts.json
```

## Tasks

Start the lab with `./lab up wazuh-ssh-bruteforce`, then open a shell with `./lab shell wazuh-ssh-bruteforce`. You are root on the Wazuh manager. A minute or two
after start-up it reads one morning of bastion-01's sshd log (`/var/lib/lab-feed-done` appears when
that is done). Staff reach bastion-01 from the internal network `10.0.0.0/8`. Write `KEY=value`
answers to `/root/answers.txt`.

1. **The course questions.**

   ```
   FAILED_5710=<rule-5710 alerts>
   TOP_SRC=<the source IP with the most of them>
   TOP_SRC_5710=<how many of them are that address>
   COMPROMISED=<the account that address logged in as>
   SUCCESS_5715=<rule-5715 alerts in total>
   ```

2. **What the course questions miss.**

   ```
   BREACH_RULE=<the rule id the attacker's login got instead of 5715>
   DISTINCT_USERS=<how many different non-existent usernames the attacker tried>
   DEPLOY_GUESSES=<alerts for the attacker's wrong passwords against the compromised account>
   REUSE_IP=<the second address that logged in as the compromised account>
   ```

3. **A rule for external logins.** In `/var/ossec/etc/rules/local_rules.xml`, add rule **100340**,
   **level 12**, for a successful SSH login from any address **outside `10.0.0.0/8`**, with a key or
   a password. Logins from the internal network stay 5715, and failures never raise it. Validate with
   `/var/ossec/bin/wazuh-analysisd -t`, restart with `/var/ossec/bin/wazuh-control restart`, and try
   it with `wazuh-logtest`.

Check your work from the host: `./lab check wazuh-ssh-bruteforce`

<details>
<summary>Hints</summary>

- `.rule.id`, `sort`, `uniq -c` shows what the stream is made of; `wc -l` counts lines
- `select(.rule.id == "5710" and .data.srcip == "...")`
- The compromised account isn't in 5715 for that address: list every rule id and `.full_log` it has
- For the guesses, look at the account name in `data.dstuser`, and count every alert, the frequency
  rule included
- For the second address: logins for the same account, minus the attacker, minus the internal network
- `<srcip>` takes a CIDR; to match everything outside it, `negate="yes"` on the tag (a leading `!` is not enough there)

</details>

## My notes

<!-- Screenshots: ./lab shot wazuh-ssh-bruteforce ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [wazuh-alert-triage](../wazuh-alert-triage/): SSH brute force among other alerts, in a full Wazuh stack with Discover
- [wazuh-sudo-abuse](../wazuh-sudo-abuse/): the next step on a host like this, privilege escalation
- [siem-correlation-rules](../siem-correlation-rules/): writing and testing Wazuh rules
- MITRE ATT&CK T1110.001 (Password Guessing), T1110.003 (Password Spraying), T1078 (Valid Accounts)
