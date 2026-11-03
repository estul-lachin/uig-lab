# private-data (local only)

Files you put here are **never committed** (see the repo's `.gitignore`), never built into an image
and never published on the site. Use it for data you're allowed to use yourself but not to share, such
as the events from a course's lab environment.

When `./lab up` starts this lab's Splunk, it indexes these files, if present, into a
separate index named **`private`**, next to the lab's own data in `main`. Expected names, one per
sourcetype:

| File | Sourcetype |
|---|---|
| `access_combined.log` | `access_combined` |
| `linux_secure.log` | `linux_secure` |
| `modsecurity_audit.log` | `modsecurity:audit` |
| `suricata.log` | `suricata` |

How to export them from a Splunk you can log in to:

1. Run `index=main sourcetype=<sourcetype>` with the time picker on **All time**.
2. Click **Export** (the arrow icon above the results), choose **Raw Events**, leave the number of
   results empty (all), and save the file under the name above in this folder.
3. Repeat for each sourcetype. Splunk watches this folder and indexes new files within a minute; no
   restart needed. Check with `| tstats count where index=private by sourcetype`.

Raw export keeps each event's text and timestamp. The original `host` and `source` become this lab's
(`private-export` and the file path).
