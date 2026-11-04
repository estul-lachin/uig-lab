# splunk-alerts

## Concepts

A Splunk **alert** is a saved search with three extra parts: *when* it runs, *when* it counts as
triggered, and *what* it does then. Reports wait for someone to open them; alerts act on their own.

**When it runs:**

| Type | How | Cost | Use for |
|---|---|---|---|
| **Scheduled** | On a cron schedule, over a time range you choose | One search per run | Almost everything |
| **Real-time** | A search that never ends and watches events **as they are indexed** (`rt`) | Holds a search slot and CPU all the time | Only when seconds matter |

A real-time search only sees events that arrive after it starts. Events that are already indexed
never reach it, whatever their timestamps say.

**Cron** has five fields, `minute hour day-of-month month day-of-week`:

```
*/2 * * * *      every 2 minutes
0 * * * *        at the top of every hour
30 6 * * 1       06:30 every Monday (Sunday is 0)
0 9-17 * * *     on the hour from 09:00 to 17:00
```

**When it triggers:**

| Condition | Fires |
|---|---|
| Number of Results (`> 0`, `> 10`, ...) | When the whole result set meets the condition |
| Number of Hosts, Number of Sources | On distinct hosts or sources in the results |
| Custom | When an extra SPL condition returns results |
| Real-time **Per-Result** | For every single event |

and then either **Once** (one action for the whole run) or **For each result** (one action per row).

**Throttling** (suppression) stops the same alert repeating. Plain throttling mutes the whole alert
for a period. **Field-based** throttling mutes it *per value* of a field: throttle an SSH alert on
`src` and every attacker is reported once per period, while a new one still gets through at once.
The scheduler logs each run to `index=_internal sourcetype=scheduler`, including `result_count`,
`alert_actions` and `suppressed`.

**What it does:** *Add to Triggered Alerts* (Activity > Triggered Alerts, with a severity: 1 Info,
2 Low, 3 Medium, 4 High, 5 Critical), *Send email*, *Webhook* (an HTTP POST of JSON to a URL: the
search name, a link, and the first result or, per result, that result), or a script / custom action.
A webhook is how an alert reaches a firewall, WAF or SOAR that blocks the address automatically.

## Tasks

Start the lab with `./lab up splunk-alerts`. It's the shop from
[splunk-search-basics](../splunk-search-basics/). The first start takes several minutes; stop other
Splunk labs first, because they share port 8000. Open **http://localhost:8000** and log in as `admin`
with the lab password `Lab-Splunk-2026`. The shop's data is from the end of October, so searches
need **All time**.

The workstation (`./lab shell splunk-alerts`) also plays the shop's **WAF**: it accepts webhooks at
`http://waf:8088/ban` and logs every request it gets to `/var/log/waf/requests.jsonl`. Write the
answers there, to `/root/answers.txt`.

1. **The course questions.**

   ```
   CRON_2MIN=<the cron expression for every 2 minutes>
   ALERT_TYPE=<the alert type that runs on a fixed interval: Scheduled or Real-time>
   TRIGGER=<one action for every matching event: Number-of-Results or Per-Result>
   THROTTLE_FIELD=<the field to suppress Server Error alerts on, so each broken endpoint alerts once>
   ERROR_EVENTS=<events with status 500 or above, All time>
   ```

2. **An SSH brute-force alert.** Search for sources with more than 10 failed SSH passwords:

   ```
   index=main sourcetype=linux_secure "Failed password"
   | rex "from (?<src>\S+)" | stats count by src | where count>10
   ```

   Save it as an alert named **`SSH Brute Force`** (private is fine): **Scheduled**, on the cron
   schedule for every 2 minutes, time range **All time**; trigger when the number of results is
   greater than 0, **for each result**; **throttle** on `src` for an hour. Two trigger actions:
   **Add to Triggered Alerts** with severity **Medium**, and a **Webhook** to `http://waf:8088/ban`.
   Then watch the WAF log through two runs.

3. **A server-error alert.** Save `index=main sourcetype=access_combined status>=500` as an alert
   named **`Server Error`**: **Real-time**, trigger **Per-Result**, **Add to Triggered Alerts** with
   severity **High**. Then edit it (Settings > Searches, reports, and alerts) and throttle it on
   `uri_path` for **10 minutes**.

4. **What the alerts really did.**

   ```
   BANNED_IPS=<how many distinct addresses the WAF received>
   RUN_SUPPRESSED=<how many results a throttled scheduled run of SSH Brute Force suppressed>
   RT_TRIGGERED=<how many times Server Error has fired so far>
   ENDPOINTS_MAX=<if all ERROR_EVENTS arrived at once, the most actions Server Error could take in 10 minutes>
   CRON_BUSINESS=<cron for every 15 minutes, 08:00 to 17:59, Monday to Friday>
   ```

   Why is `RT_TRIGGERED` what it is, when `ERROR_EVENTS` isn't 0?

Check your work from the host: `./lab check splunk-alerts`. When you're done,
`./lab down splunk-alerts` frees the memory.

<details>
<summary>Hints</summary>

- Save As > Alert; "Run on Cron Schedule" is under Scheduled; the time range has its own picker
- "For each result" is the Trigger setting under the condition; Throttle appears once you tick it
- The webhook URL must be exactly `http://waf:8088/ban`
- `jq -r .body.result.src /var/log/waf/requests.jsonl | sort -u`
- `index=_internal sourcetype=scheduler savedsearch_name="SSH Brute Force"`, then
  `table _time result_count alert_actions suppressed`
- Throttling on a field allows one action per distinct value in the period: count the distinct values
- Ranges in cron use a dash; days of the week count from Sunday = 0

</details>

## My notes

<!-- Screenshots: ./lab shot splunk-alerts ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [splunk-search-basics](../splunk-search-basics/): the same shop data, and the first saved report
- [splunk-dashboards](../splunk-dashboards/): reports and dashboards from the same searches
- [splunk-field-extraction](../splunk-field-extraction/): the `rex` behind `src`
- [wazuh-ssh-bruteforce](../wazuh-ssh-bruteforce/): the same attack, detected by Wazuh rules
