# splunk-spl-fundamentals

## Concepts

[splunk-search-basics](../splunk-search-basics/) was about finding your way around Splunk Web. This lab
is about the language: SPL (Search Processing Language). It uses the same local Splunk and the same five
days of shop logs.

**Anatomy**: a search reads left to right. Before the first `|` is the **base search**, which decides
*which events* to pull. After it come **commands**, which decide *what to do* with them. Every command
gets the output of the previous one.

```
index=main sourcetype=access_combined status>=400   <- base search
| table _time clientip status uri_path               <- commands
| sort -_time
```

**Terms and phrases**:
- A bare word is a **term**, matched anywhere in the raw text, case-insensitively: `failed` also matches
  `Failed`.
- Quotes make a **phrase**: `"failed password for root"` matches those words in that order. Quote any
  value that contains a space, `*` or a backslash.

**Boolean logic**:
- A space between terms is an implicit **AND**.
- `OR` and `NOT` must be **upper case**, or they are just more terms to match. Group with parentheses:
  `(status=200 OR status=304)`.
- `NOT status=200` also keeps events that have no `status` field at all, while `status!=200` only keeps
  events that have one.

**Field filters**: once a sourcetype extracts fields, you can compare them:

| Form | Meaning |
|---|---|
| `status=404` | Equals |
| `status!=200` | Not equals (the field must exist) |
| `bytes>=20000` | Numeric comparison |
| `user=*` | The field exists |

`access_combined` extracts `clientip`, `status`, `bytes`, `method`, `uri_path`, `useragent` and more.
`linux_secure` here has no extracted fields; search its text as terms.

**Shaping the output**:

| Command | Does |
|---|---|
| `table f1 f2` | Only these columns, in this order |
| `fields f1 f2` / `fields - f3` | Keep / drop fields (cheaper than `table` early on) |
| `rename old AS new` | Rename a field |
| `dedup field` | Keep the first event per distinct value |
| `sort -count`, `sort _time` | Descending / ascending; `sort 0` removes the default limit of 10,000 |
| `head N` | The first N results |
| `stats count`, `stats dc(field)`, `stats count by field` | Count, distinct count, count per value |

## Tasks

Start the lab with `./lab up splunk-spl-fundamentals`. The first start takes a few minutes: Splunk runs
through Rosetta on an Apple Silicon Mac and needs about 2 GB of memory. Stop other Splunk labs first,
because they share port 8000. Open **http://localhost:8000** and log in as `admin` with the lab
password `Lab-Splunk-2026`. Set the time picker to **All time**. Write the answers in the workstation
container (`./lab shell splunk-spl-fundamentals`) to `/root/answers.txt` as `KEY=value` lines.

1. **Terms, phrases and booleans.** All within `index=main`:

   ```
   TERM_FAILED=<linux_secure events containing the term failed>
   PHRASE_ROOT=<linux_secure events containing the phrase "failed password for root">
   OK_OR_NOT_MODIFIED=<access_combined events with status 200 or 304>
   LOWERCASE_OR=<the same search, but with a lower-case or>
   NOT_200=<access_combined events that are not status 200>
   ```

   Explain to yourself why `LOWERCASE_OR` is what it is.
2. **Field filters.**

   ```
   COUNT_404=<access_combined events with status 404>
   BIG_RESPONSES=<access_combined events of 20000 bytes or more>
   DISTINCT_CLIENTS=<how many distinct clientip values access_combined has>
   ```

3. **Shaping results.**
   - `FIRST_ERROR_PATH=<the uri_path of the earliest 5xx response>`. Get there with `table` and `sort`,
     not by scrolling.
   - Save a **report** named `web-errors`: all 4xx and 5xx responses counted per path, with the path
     column renamed to `path`, largest count first, over All time.

Check your work from the host: `./lab check splunk-spl-fundamentals`. When you're done,
`./lab down splunk-spl-fundamentals` frees the memory.

<details>
<summary>Hints</summary>

- The count is shown above the events; or end any search with `| stats count`
- `index=main sourcetype=linux_secure failed`
- `(status=200 OR status=304)` vs `status=200 or status=304`
- `| stats dc(clientip)`, or `| dedup clientip | stats count`
- `status>=500 | table _time uri_path | sort _time | head 1`
- `status>=400 | stats count by uri_path | rename ... AS path | sort -count`, then Save As > Report

</details>

## My notes

<!-- Screenshots: ./lab shot splunk-spl-fundamentals ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [splunk-search-basics](../splunk-search-basics/): Splunk Web, search modes and the time picker
- [syslog-collector](../syslog-collector/): how logs get into a SIEM in the first place
- Splunk Search Reference: `search`, `table`, `fields`, `rename`, `dedup`, `sort`, `stats`
