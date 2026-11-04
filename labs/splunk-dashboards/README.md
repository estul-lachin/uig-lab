# splunk-dashboards

## Concepts

A search answers a question once. A **report** is a saved search: anyone can run it again, schedule it
or share it. A **dashboard** is a page of **panels**; each panel runs a search, or a report, and draws
it as a visualization.

**The chart has to fit the shape of the result**:

| You want to show | The search ends in | Visualization |
|---|---|---|
| One headline number | `stats count` | **Single value** |
| Shares of a whole, few categories | `stats count by field` (up to about 8 rows) | **Pie** |
| A ranking across many categories | `top field` or `stats count by field \| sort - count` | **Bar** (horizontal) or **column** (vertical) |
| A trend over time | `timechart span=10m count` (add `by field` for one line each) | **Line** |
| Raw rows | `table f1 f2` | **Statistics table** |

A pie of 40 client addresses is unreadable: pies are for a handful of categories.

**From search to dashboard**:
1. Run the search, then open the **Visualization** tab. Splunk picks a chart type; change it with the
   chart-type button.
2. **Save As > Report** keeps the search under a name. **Save As > New / Existing Dashboard** turns the
   current search and chart into a panel.
3. On a dashboard, **Add Panel > New from Report** places a report. Such a panel keeps pointing at the
   report, so if the report's search changes, the panel follows. A pasted search doesn't.

Splunk 10 offers **Classic** (Simple XML) and **Dashboard Studio** dashboards. Choose **Classic** for
this lab: the check reads the dashboard's source, and Classic is the format it has been tested
with. A Studio dashboard is recognised by its visualization types, but if a check fails on one,
rebuild it as Classic.

**Who owns a report**:
- A new report is **private**: only its owner sees it, and it runs as its owner.
- A team dashboard needs its reports shared, with the **app** (or globally), under *Edit Permissions*.
- A report that should outlive its owner's account is usually given the owner `nobody`.

**If a panel is empty**, run its search on the Search tab. The chart can only show what the search
returns, for the time range it was given.

## Tasks

Start the lab with `./lab up splunk-dashboards`. It's the same shop as in
[splunk-search-basics](../splunk-search-basics/), plus its second web server **web-02**, which had a
bad day on 30 October. The first start takes several minutes; stop other Splunk labs first, because
they share port 8000. Open **http://localhost:8000** and log in as `admin` with the lab password
`Lab-Splunk-2026`. Use **All time** throughout, for `index=main sourcetype=access_combined`. Write the
answers in the workstation container (`./lab shell splunk-dashboards`) to `/root/answers.txt`.

Build a dashboard titled **`SOC_Dashboard`** with these six panels, and note the number each one shows:

| Panel | What it shows | Answer |
|---|---|---|
| Single value | How many requests got 503 (service unavailable) | `SINGLE_503=` |
| Pie | Requests blocked with 403, by client address | `PIE_SLICES=<how many slices>` |
| Bar | Status codes other than 200 | `TOP_NON200=<the most common one>` |
| Column | Requests by HTTP method | `POST_COUNT=` |
| Line | The 503s over time, one line per host | `OUTAGE_HOST=<the web server that failed>` |
| Report | A report named **`Top Clients`** (`... \| top clientip`), shared with the app, placed as a report | `TOP_CLIENT_COUNT=<requests from the #1 client>` |

Finally, open the dashboard and check that all six panels show data: `ALL_PANELS=yes`.

Check your work from the host: `./lab check splunk-dashboards`. When you're done,
`./lab down splunk-dashboards` frees the memory.

<details>
<summary>Hints</summary>

- The count each visualization draws is also on the Statistics tab
- `status!=200 | stats count by status`, then Bar
- `| timechart span=10m count by host` on the 503s, then Line
- Save As > Report first; then Dashboards > SOC_Dashboard > Edit > Add Panel > New from Report
- Settings > Searches, reports, and alerts > Top Clients > Edit > Edit Permissions > This app only
- A panel saved from a search that already ends in a chart type keeps that type; check each one

</details>

## My notes

<!-- Screenshots: ./lab shot splunk-dashboards ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [splunk-search-basics](../splunk-search-basics/) and [splunk-spl-fundamentals](../splunk-spl-fundamentals/):
  the searches these panels are built from
- [wazuh-alert-triage](../wazuh-alert-triage/): the same kind of slicing in another SIEM
- Splunk docs: Visualization reference, Dashboards and Visualizations manual, Dashboard Studio
