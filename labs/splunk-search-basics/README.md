# splunk-search-basics

## Concepts

A SIEM collects the logs of many systems in one place so an analyst can search them together. Splunk
is the most common one. This lab runs **Splunk Enterprise locally**, with five days of logs from a
small online shop: web requests, SSH and sudo, IDS alerts, and ordinary system noise. One night in
those logs went badly. Before hunting, you need to know your way around the search screen.

**Every event has metadata**:
- `_time` is the event's time. It's stored in UTC and shown in your user's time zone; this lab's
  Splunk runs in UTC.
- `host` is where the event came from.
- `source` is the file or stream.
- `sourcetype` is the format, which decides how fields are extracted.
- `index` is where Splunk stored the event.

Start every search with `index=...`: without it, Splunk searches your role's default indexes, which
is slower and easy to get wrong.

**Searches and results**: a search such as `index=main sourcetype=access_combined status=404` returns
**events**. A **transforming command** turns them into a **table**: `stats`, `top`, `chart`,
`timechart`. Useful starters:
- `| stats count by host` counts per host, and `| stats dc(field)` counts distinct values.
- `| top limit=5 field` shows the most common values.
- `| metadata type=sourcetypes index=main` lists the sourcetypes in an index, and `| tstats count where
  index=main by sourcetype` counts quickly from index-time data.
- `| rex "from (?<ip>\S+) port"` extracts a field with a regular expression when none exists.
- Field names are case-sensitive.

**Search modes** (the dropdown under the search bar):

| Mode | Does | Use for |
|---|---|---|
| Fast | Skips field discovery; only what the search names | Dashboards, heavy searches |
| Smart (default) | Events tab for plain searches; **Statistics** tab when there's a transforming command | Everyday work |
| Verbose | Discovers all fields and fills every tab | Exploring unfamiliar data |

**The Fields sidebar**: the Events tab lists *selected* fields and *interesting* fields, meaning those
in at least 20% of results. Click one to see its top values and coverage. **All Fields** lists every
field with its distinct-count.

**The time picker** (top right) applies to every search, and it's the most common reason for "no
results":
- *Presets* (Last 24 hours, All time).
- *Relative* windows (e.g. `-7d@d`).
- *Real-time*.
- *Date Range*, and *Date & Time Range* for an exact incident window.

Clicking or dragging on the timeline above the events zooms into a burst. In SPL itself,
`earliest=` and `latest=` override the picker.

**Reports**: *Save As > Report* stores a search, with its time range, under a name. Others can rerun it,
schedule it, or put it on a dashboard. It's how a hunt becomes repeatable.

## Tasks

Start the lab with `./lab up splunk-search-basics`. The first start takes a few minutes: Splunk is an
amd64 image, so on an Apple Silicon Mac it runs through Rosetta (Docker Desktop: *Use Rosetta for
x86/amd64 emulation* must be on). It needs about 2 GB of memory. When it's up, open
**http://localhost:8000** and log in as `admin` with the lab password `Lab-Splunk-2026`. It listens on
your Mac only.

Work in Search & Reporting. Write the answers in the workstation container (`./lab shell
splunk-search-basics`) to `/root/answers.txt` as `KEY=value` lines.

1. `COUNT_ACCESS=<the number of access_combined events over All time>`
2. `SOURCETYPES=<how many sourcetypes feed the main index>`
3. `STATUS_VALUES=<how many distinct values status has in access_combined>` (use the Fields sidebar
   and All Fields)
4. `SMART_TAB=<the results tab that Smart Mode fills for a search ending in | stats count>`
5. `COUNT_SECURE=<the number of linux_secure events over All time>`
6. **An exact window.** With the time picker's *Date & Time Range*, write
   `WINDOW_COUNT=<the number of access_combined events from 2026-10-29 03:00:00 to 03:30:00>`.
   Then look at the timeline: what happened then?
7. **The hunt.**
   - `BRUTE_IP=<the address that guessed SSH passwords>`
   - `BREACHED_USER=<the account it then logged in as>`
   - `SCANNER_IP=<the address that probed /wp-login.php>`
   - `SCANNER_SIGNATURE=<the IDS signature that fired most often for that scanner>`

   Then save a search of the failed SSH passwords counted per source address, largest first, over All
   time, as a **report** named `ssh-failures-by-src`. Its first row must be the brute-force source.

8. **Optional: your own course data.** If you have exported data you may use but not share (for example
   from a course's lab), put it in [`private-data/`](private-data/README.md). It stays on your machine,
   is indexed into a separate index `private`, and adds answers `PRIVATE_COUNT_ACCESS`, `PRIVATE_SOURCETYPES`,
   `PRIVATE_STATUS_VALUES` and `PRIVATE_COUNT_SECURE` (the same questions as 1, 2, 3 and 5, with
   `index=private`). Without it, this step is skipped.

Check your work from the host: `./lab check splunk-search-basics`. The check runs the same searches
through Splunk's REST API. When you're done, `./lab down splunk-search-basics` frees the memory.

<details>
<summary>Hints</summary>

- Set the time picker to *All time* first; the logs are from late October 2026
- `index=main sourcetype=access_combined` shows the count above the events
- `| metadata type=sourcetypes index=main`
- `| stats dc(status)`, or the status field in the sidebar
- `index=main sourcetype=linux_secure "Failed password"`, then `rex` the address out and
  `| stats count by <field> | sort - count`
- `"Accepted"` with that address; `sourcetype=suricata src_ip=... | top alert.signature`
- Save As > Report; check it under *Reports*

</details>

## My notes

<!-- Screenshots: ./lab shot splunk-search-basics ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [logs-journald](../logs-journald/): the same kind of investigation on a single host's journal
- [linux-cli-intro](../linux-cli-intro/): grep and counting on plain log files
- Splunk docs: Search Reference (`stats`, `rex`, `metadata`, `tstats`), Search Manual (time modifiers)
