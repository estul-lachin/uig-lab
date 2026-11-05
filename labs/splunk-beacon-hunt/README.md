# splunk-beacon-hunt

## Concepts

Once malware runs on a host, it has to get its orders from somewhere: **command and control** (C2).
Most implants don't keep a connection open. They **beacon**: check in on a timer ("anything for
me?"), get an empty answer almost every time, and a real task now and then. **Threat hunting** means
going looking for that without an alert, on the assumption that something already got in.

What gives a beacon away:

| Trait | Why |
|---|---|
| One internal host, one external destination | Fan-in of 1: nobody else in the company talks to it |
| A regular gap between connections | People and apps are bursty; a timer isn't |
| All day long | A one-off call isn't C2 |
| Small, similar sizes | The check-in is a few hundred bytes; only a task makes the answer bigger |
| An odd port, a young or unknown network | 8443 or a high port instead of 443; a hosting provider nobody else uses |

**Two ways to measure regularity in SPL.**

*Minute bins*: count connections per pair per minute, then compare the spread of those counts
with their mean (the **coefficient of variation**, `stdev / avg`):

```
... | bin span=1m _time | stats count by _time src_ip dest_ip
    | stats count AS minutes avg(count) AS avg stdev(count) AS sd by src_ip dest_ip
```

It's cheap, but it measures the *count per minute*, not the timer. Anything that calls at most once
a minute scores as perfectly regular.

*Gaps*: sort by time, take the difference to the previous connection of the same pair, and look at
the coefficient of variation of the **gaps**:

```
... | sort 0 _time | streamstats current=f last(_time) AS prev by src_ip dest_ip
    | eval delta=_time-prev | stats count avg(delta) stdev(delta) by src_ip dest_ip
```

Below about 0.05 is a machine on a strict timer. Real implants add **jitter** (a random 10 to 30% on
each sleep) to look less mechanical, which lifts the value to 0.1 to 0.2: a threshold of 0.1 misses
them, 0.3 still catches them. `timechart span=1m count` on one pair shows the rhythm at a glance.

**The look-alikes.** Operating-system telemetry, update checks, sync clients and push channels are
just as regular. They differ in **fan-in**: dozens of hosts talk to the same destination (and its
name is one you know). `eventstats dc(src_ip) by dest_ip` puts that number on every row.

**Enrichment.** For the hand-off, an address alone is thin. A **lookup** adds context from a CSV
file, here the network (ASN) each external address belongs to:
`| lookup asn_lookup ip AS dest_ip OUTPUT asn org`.

## Tasks

Start the lab with `./lab up splunk-beacon-hunt`. It has its own data: the web proxy's day,
4 November 2026 08:00 to 16:00 UTC, in `index=main sourcetype=web_proxy` (`src_ip`, `dest_host`,
`dest_ip`, `dest_port`, `bytes_out`, `bytes_in`, ...), and a lookup named `asn_lookup`. The first
start takes several minutes; stop other Splunk labs first, because they share port 8000. Open
**http://localhost:8000** and log in as `admin` with the lab password `Lab-Splunk-2026`. Use
**All time**; times are UTC. Write the answers in the workstation container
(`./lab shell splunk-beacon-hunt`) to `/root/answers.txt`.

1. **Profile and periodicity.** Count connections per `src_ip`, `dest_ip`, `dest_port`; find the
   pair that calls every minute; chart it with `timechart span=1m`; measure its gaps.

   ```
   BEACON_SRC=<the internal host>
   BEACON_DST=<the destination address>
   BEACON_PORT=<the destination port>
   BEACON_GAP=<the average gap between its connections, in whole seconds>
   RECIPE_PAIRS=<how many pairs the minute-bin recipe flags with minutes > 60 and stdev/avg < 0.3>
   ```

2. **Separate C2 from look-alikes.**

   ```
   FP_HOST=<the dest_host behind most of those recipe rows, which is not C2>
   FP_SOURCES=<how many internal hosts talk to it>
   JITTER_SRC=<the second implanted host: regular gaps, but not to the minute>
   JITTER_DST=<where it calls>
   JITTER_GAP=<its average gap, in whole seconds>
   ```

3. **Hand-off.**

   ```
   C2_ASN=<the ASN of BEACON_DST, from asn_lookup>
   TASK_TIME=<when that C2 sent a task, HH:MM>
   ```

4. **Save the hunt** as a report named **`beacon_hunt`** that returns one row per implanted pair
   (fields `src_ip` and `dest_ip`): both implants, and neither the telemetry nor any browsing.

Check your work from the host: `./lab check splunk-beacon-hunt`. When you're done,
`./lab down splunk-beacon-hunt` frees the memory.

<details>
<summary>Hints</summary>

- `stats count dc(src_ip) by dest_ip` is a fan-in table; what talks to only one host, hundreds of times?
- `streamstats` needs the events in time order: `sort 0 _time` first (searches return newest first)
- Gaps of a few seconds within a browsing session make its stdev huge: regular pairs stand out by `cv`
- The second implant uses 443 and a harmless-sounding name; its gaps vary by about a quarter
- `| makeresults | eval dest_ip="..." | lookup asn_lookup ip AS dest_ip OUTPUT asn org` tries the lookup on one address
- A task makes `bytes_in` jump; the next check-ins send the results back
- For the saved hunt: gap statistics by pair, a `where` on count and cv, then
  `eventstats dc(src_ip) AS fanin by dest_ip` and a `where` on fanin

</details>

## My notes

<!-- Screenshots: ./lab shot splunk-beacon-hunt ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [splunk-ir-workflow](../splunk-ir-workflow/): a beacon as one step of a full incident
- [splunk-transforming-commands](../splunk-transforming-commands/): stats, top and rare
- MITRE ATT&CK T1071.001 (Application Layer Protocol: Web Protocols), T1571 (Non-Standard Port)
