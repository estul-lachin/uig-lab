# splunk-transforming-commands

## Concepts

Filtering tells you *which* events exist. **Transforming commands** tell you how many, which values
are most and least common, and what the numbers add up to. Their results are tables, and they show up
on the **Statistics** tab.

**`top`**: the most common values, with a count and a percent, largest first.

```
index=main sourcetype=access_combined | top clientip
... | top limit=5 uri_path          (limit=0 shows them all)
... | top limit=1 status, method    (the most common combination)
```

**`rare`**: the same, upside down: the least common values first. This is a hunting tool. A noisy
client sits at the top of `top`. A visitor who makes a handful of careful requests ("low and slow")
disappears at the bottom, but `rare` brings it to the top. Volume isn't danger. `rare` shows 10
values by default; widen it with `limit=N`.

**`stats`**: the general tool that `top` and `rare` are shortcuts for:

```
... | stats count by status
... | stats count AS hits, dc(uri_path) AS paths, values(method) AS methods by clientip
... | stats avg(bytes) AS avg_bytes by status
```

| Function | Returns |
|---|---|
| `count` | Events in the group |
| `count(f)` | Events in the group that have field `f` |
| `dc(f)` | Distinct values of `f` |
| `sum(f)` `avg(f)` `min(f)` `max(f)` | Numeric summaries |
| `values(f)` / `list(f)` | Distinct values / all values |

- `by` sets the grouping: one row per combination.
- `AS` renames a result column.
- **`stats` doesn't sort**, unlike `top`. Add `| sort - hits`.

## Tasks

Start the lab with `./lab up splunk-transforming-commands`. It's the shop from
[splunk-search-basics](../splunk-search-basics/) plus its admin portal **web-03** (30 October). Stop
other Splunk labs first, because they share port 8000. Open **http://localhost:8000** and log in as
`admin` with the lab password `Lab-Splunk-2026`. Use **All time** and
`index=main sourcetype=access_combined`. Write the answers in the workstation container
(`./lab shell splunk-transforming-commands`) to `/root/answers.txt`.

1. **`top` and `rare`.**

   ```
   BUSIEST_CLIENT=<the clientip with the most requests>
   BUSIEST_PATHS=<how many distinct uri_path values it requested>
   RAREST_CLIENT=<the clientip with the fewest requests>
   RARE_DOWNLOAD=<the uri_path of the largest response that client received>
   ```

   Look at what each of them is: which one would you investigate first?
2. **`stats`.**

   ```
   SERVER_ERRORS=<events with status 500 or higher>
   TOP_403_CLIENT=<the clientip blocked with 403 most often>
   ```

3. **A profile per client.** Save a report named **`client-profile`**: one row per `clientip` with the
   columns `hits` (requests), `paths` (distinct `uri_path`) and `methods` (the methods it used), most
   hits first, over all time.

Check your work from the host: `./lab check splunk-transforming-commands`. When you're done,
`./lab down splunk-transforming-commands` frees the memory.

<details>
<summary>Hints</summary>

- `| top limit=3 clientip` and `| rare limit=3 clientip`
- `clientip=<address> | table _time uri_path status bytes useragent`
- `status>=500` compares numbers
- `status=403 | stats count by clientip | sort - count`
- `count AS hits` names the column; `values(method)` lists the distinct methods

</details>

## My notes

<!-- Screenshots: ./lab shot splunk-transforming-commands ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [splunk-spl-fundamentals](../splunk-spl-fundamentals/): searching and shaping results
- [splunk-field-extraction](../splunk-field-extraction/): making fields to count by
- [splunk-dashboards](../splunk-dashboards/): drawing these tables as panels
- Splunk docs: top, rare, stats and its functions
