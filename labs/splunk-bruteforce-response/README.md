# splunk-bruteforce-response

## Concepts

A **use case** is a detection with a purpose: what to look for, how to tell an attempt from an
incident, and what happens when it fires. For SSH brute force, sshd writes two kinds of line:

```
Failed password for root from 203.0.113.9 port 51234 ssh2                  ← a guess (real user)
Failed password for invalid user pi from 203.0.113.9 port 51240 ssh2       ← a guess (no such user)
Accepted password for deploy from 203.0.113.9 port 51302 ssh2              ← a login
```

**Extract carefully.** `rex "for (?<user>\S+) from"` silently skips every `invalid user` line,
because "for" isn't followed by the name there. Make the prefix optional: `for (?:invalid user )?(?<user>\S+) from`.
Anchor the address the same way: `from (?<src>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})`.

**Failures alone are an attempt; failures and a success from the same address are an incident.**
Both can be counted in one pass, one row per address:

```
... | stats count(eval(searchmatch("Failed password"))) AS fails
            count(eval(searchmatch("Accepted password"))) AS successes by src
```

**Volume isn't impact.** The account with the most failures is nearly always `root` or another
default name hammered by internet noise. The incident is the account that someone got into.

**A threshold is a blind spot.** `fails > 50` finds the loud attacker and nothing else:

| Pattern | What it looks like per source | What finds it |
|---|---|---|
| Loud brute force | Hundreds of failures in minutes from one address | `fails > N` by `src` |
| Low and slow | A guess every half hour, for a day | A lower N over a longer window, plus `successes > 0` |
| **Password spray** | Many addresses, a few guesses each, one account | Group **by user**: `dc(src)`, guesses per source |
| Staff typos | Two wrong passwords, then the right one, from the office | Excluded on purpose: `NOT cidrmatch("10.0.0.0/8", src)` |

**Response.** Saved as a scheduled alert that fires *for each result*, throttled on `src`, the
detection can hand every breaching address to a SOAR or firewall through a webhook (see
[splunk-alerts](../splunk-alerts/) for alert types, cron, triggers and throttling). Triggered
Alerts is the SOC's queue for the same events.

## Tasks

Start the lab with `./lab up splunk-bruteforce-response`. It has its own data: four days (27 to 30
October 2026) of **bastion-01**'s sshd log in `index=main sourcetype=linux_secure`. The first start
takes several minutes; stop other Splunk labs first, because they share port 8000. Open
**http://localhost:8000** and log in as `admin` with the lab password `Lab-Splunk-2026`. Use
**All time**. Staff work from `10.0.0.0/8`.

The workstation (`./lab shell splunk-bruteforce-response`) also plays the **SOAR**: it accepts
webhooks at `http://soar:8088/ban` and logs every request to `/var/log/soar/requests.jsonl`. Write
the answers there, to `/root/answers.txt`.

1. **The course questions.**

   ```
   ATTACKER=<the source with more than 50 failed passwords>
   BURST=<its failed passwords>
   COMPROMISED=<the account it then logged in as>
   SUCCESSES=<its successful password logins>
   MOST_TARGETED=<the username with the most failed passwords, invalid users included>
   ```

2. **What `fails > 50` misses.**

   ```
   SLOW_BREACH=<the other address with more than 10 failures and a success>
   SPRAY_USER=<the account sprayed from many addresses, a few guesses each, that was then breached>
   SPRAY_SOURCES=<how many distinct addresses failed against it>
   SPRAY_WINNER=<the address that got into it>
   FALSE_POSITIVES=<office addresses (10.0.0.0/8) with failures and a success>
   ```

3. **Respond.** Save an alert named **`SSH Brute Force - Successful Authentication`** whose search
   returns one row per address **outside `10.0.0.0/8`** that had at least one failure **and** at
   least one success, with a `src` field. Scheduled on cron, **every 15 minutes**, time range
   **All time**; trigger when the number of results is greater than 0, **for each result**;
   throttle on `src` for **1 hour**. Two trigger actions: **Add to Triggered Alerts**, and a
   **Webhook** to `http://soar:8088/ban`. After its first run (the next quarter hour):

   ```
   BANNED=<how many distinct addresses the SOAR received>
   ```

Check your work from the host: `./lab check splunk-bruteforce-response`. When you're done,
`./lab down splunk-bruteforce-response` frees the memory.

<details>
<summary>Hints</summary>

- `"Failed password" | rex ... | stats count by src | where count>50`
- The successes are spread over the whole range: All time, not the burst's minutes
- For the most targeted user, compare the plain `for (?<user>\S+) from` with the anchored version
- The spray: `stats dc(src) AS sources count AS fails by user`, then `eval per_source=fails/sources`
- `cidrmatch("10.0.0.0/8", src)` is true for office addresses; `NOT` in front for the alert
- The alert's search must end in rows with a `src` field: the webhook sends each row as `result`
- `jq -r .body.result.src /var/log/soar/requests.jsonl | sort -u`

</details>

## My notes

<!-- Screenshots: ./lab shot splunk-bruteforce-response ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [splunk-alerts](../splunk-alerts/): alert types, cron, triggers, throttling and webhooks
- [splunk-field-extraction](../splunk-field-extraction/): `rex` and the invalid-user variant
- [wazuh-ssh-bruteforce](../wazuh-ssh-bruteforce/): the same attack, detected by Wazuh rules
- MITRE ATT&CK T1110.001 (Password Guessing), T1110.003 (Password Spraying), T1078 (Valid Accounts)
