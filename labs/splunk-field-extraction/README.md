# splunk-field-extraction

## Concepts

`access_combined` arrives with `clientip`, `status`, `uri_path` and the rest already extracted,
because its sourcetype ships with extraction rules. `linux_secure` in this lab doesn't: an sshd line
is one long string, and there is no `user` or `src` field until you make one:

```
... bastion-01 sshd[4120]: Failed password for invalid user backup from 10.30.5.17 port 51022 ssh2
```

**Regular expressions in one table**:

| Pattern | Matches |
|---|---|
| `\d` `\w` `\s` `\S` | A digit, a word character, white space, anything but white space |
| `+` `*` `?` `{1,3}` | One or more, zero or more, optional, 1 to 3 times |
| `[^ ?]` | Any character except space and `?` |
| `(?:...)` | A group that is not captured |
| `(?<name>...)` | A **named capture group**: in Splunk it becomes the field `name` |
| `^` `\.` | Start of the value, a literal dot |

**Extracting at search time**:
- **`erex`** extracts by example. You give it sample values
  (`| erex field examples="value1, value2"`) and it writes the regex itself. **Job > Inspect Job**
  shows the regex it came up with, so you can reuse it with `rex`. `| windbag` makes about 100
  multilingual sample events to practise on.
- **`rex`** applies your own regex: `| rex "from (?<src>...)"`. Anchor on text that never changes
  (`for`, `from`, `port`), and look at the variants: sshd writes `for invalid user NAME from` when
  the account doesn't exist.
- **`rex mode=sed`** rewrites text: `| rex field=src mode=sed "s/\.\d+$/.x/"` masks the last octet.
  Useful before sharing results.
- **`regex`** *filters* events by pattern: `| regex src="^10\."` keeps internal addresses, and
  `regex src!="..."` drops them. Inside `eval` or `where`, `match(field, "regex")` does the same.

**Saving an extraction**: an inline `rex` lasts for one search.
1. In the **Extract New Fields** wizard (fields sidebar, at the bottom), pick a sample event and
   choose *Regular Expression*.
2. Highlight the value and name it.
3. Save it.

Splunk stores it as an `EXTRACT-` rule on the sourcetype, and every later search of that sourcetype
gets the field automatically. It is private to you until you share it.

## Tasks

Start the lab with `./lab up splunk-field-extraction`. It's the shop from
[splunk-search-basics](../splunk-search-basics/) plus its SSH jump host **bastion-01** (30 October).
Stop other Splunk labs first, because they share port 8000. Open **http://localhost:8000** and log in
as `admin` with the lab password `Lab-Splunk-2026`. Use **All time**. Write the answers in the
workstation container (`./lab shell splunk-field-extraction`) to `/root/answers.txt`.

1. **erex and rex.**

   ```
   ERX_DISTINCT=<distinct values of firstwords after | windbag | erex firstwords examples="Unë, Կրնամ">
   URI_PATHS=<distinct URL paths, extracted with your own rex from the request line of access_combined>
   ```

   Compare the second answer with Splunk's own `uri_path` field.
2. **Failed SSH logons** (`index=main sourcetype=linux_secure "Failed password"`), with fields you
   extract:

   ```
   TOP_USER=<the user name with the most failed attempts>
   TOP_USER_FAILS=<how many it had>
   INTERNAL_FAILS=<failed attempts from 10.0.0.0/8>
   DISTINCT_ATTACKERS=<distinct source addresses>
   INSIDER_IP=<the internal machine trying names that don't exist>
   ```

   Make sure your user pattern handles both forms of the line.
3. **A saved extraction.** With the Extract New Fields wizard, save an extraction on `linux_secure`
   for `src`, `user` or `portNum`. Search `linux_secure` again without `rex` and confirm the field is in
   the sidebar: `WIZARD_FIELDS=yes`.

Check your work from the host: `./lab check splunk-field-extraction`. When you're done,
`./lab down splunk-field-extraction` frees the memory.

<details>
<summary>Hints</summary>

- `\"[A-Z]+ ` matches the quote and method before the path; stop the path at a space or `?`
- `for (?:invalid user )?(?<user>\S+) from`; compare the top user with and without the `(?:...)?`
- An IPv4 address: `\d{1,3}(?:\.\d{1,3}){3}`
- `| regex src="^10\."` after the `rex` that creates `src`
- The wizard lists its result under Settings > Fields > Field extractions

</details>

## My notes

<!-- Screenshots: ./lab shot splunk-field-extraction ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [splunk-spl-fundamentals](../splunk-spl-fundamentals/): searching before extracting
- [splunk-dashboards](../splunk-dashboards/): putting the extracted fields on panels
- [syslog-collector](../syslog-collector/): parsing at collection time instead of search time
- Splunk docs: rex, erex, regex, Field extractor
