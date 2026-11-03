# syslog-collector

## Concepts

Before a SIEM can correlate anything, logs have to arrive, be attributed to the right source and be
parsed into fields. In QRadar that front end is the event collector:
- It listens for **syslog on 514/udp** by default.
- It recognises each **log source** by its address and payload.
- It parses each source type with a **DSM** (Device Support Module).

A source with no matching DSM produces unparsed events. This lab builds the same front end with
**rsyslog**, the syslog daemon on most Linux systems, for four devices that are already sending:

| Device | Address | Sends |
|---|---|---|
| `fw-01`, firewall | 10.253.80.21 | iptables-style lines over UDP: `FW DROP SRC=... DST=... DPT=...` |
| `web-01`, nginx | 10.253.80.22 | access-log lines over **TCP** |
| `dc-01`, domain controller | 10.253.80.23 | Windows logon events over UDP: `EventID=4625 Account=...` |
| (one more device) | ? | Something nobody registered |

**Syslog in one paragraph**: each message starts with a priority `<PRI>` (facility × 8 + severity),
then a timestamp, a host and a tag, then free text. RFC 3164 is the old BSD format and RFC 5424 the
structured one. UDP is the classic transport: cheap, unordered, lost silently if nobody listens. TCP
(often with TLS on 6514) is reliable. Senders decide which they use, so a collector that only opens UDP
quietly misses TCP devices.

**rsyslog configuration** (RainerScript), in `/etc/rsyslog.d/*.conf`:

```
module(load="imudp")                  # input modules: imudp, imtcp
input(type="imudp" port="514")

if $fromhost-ip == "192.0.2.1" then {  # properties: $fromhost-ip, $programname, $msg, ...
    action(type="omfile" file="/var/log/x.log")
    stop                               # don't let later rules see this message
}
```

- Files load in **name order**, and Ubuntu's own rules sit in `50-default.conf`, which writes everything
  to `/var/log/syslog`. A file sorting after it is too late to keep remote logs out of there.
- **Templates** shape what an action writes. A `type="list"` template mixes `constant(...)` text with
  `property(...)` values, and a property can be cut down with a regular expression
  (`regex.expression`, `regex.submatch`). That is enough to turn a raw line into JSON: a tiny DSM.
- `rsyslogd -N1` checks the configuration. This container has no init system, so restart with
  `pkill rsyslogd; rsyslogd`.

**Why fields matter**: "how many DROPs per source address" is a one-liner on parsed fields
(`jq ... | sort | uniq -c`) and painful on raw text. Normalising every source to the same field
names is what makes a SIEM searchable.

## Tasks

Start the lab with `./lab up syslog-collector`, open a shell with `./lab shell syslog-collector`. The
shell is `root` on the collector; the devices start sending immediately, and rsyslog is running with
Ubuntu's default (local-only) configuration. Put your configuration in one file in `/etc/rsyslog.d/`.
Write `KEY=value` answers to `/root/answers.txt`.

1. **Listening.** Receive syslog on port 514, over UDP and over TCP. The configuration must pass
   `rsyslogd -N1`.
2. **One file per log source.** Route by sender address:

   | File | Gets |
   |---|---|
   | `/var/log/siem/firewall.log` | Everything from the firewall |
   | `/var/log/siem/web.log` | Everything from the web server |
   | `/var/log/siem/windows.log` | Everything from the domain controller |
   | `/var/log/siem/unknown.log` | Everything else from the network, with the sender's address in each line |

   None of the remote logs may also land in `/var/log/syslog`.
3. **A DSM for the firewall.** Also write every firewall message to `/var/log/siem/firewall.json`, one
   JSON object per line: `{"src":"…","dst":"…","dpt":443,"action":"DROP"}` (`dpt` as a number).
4. **Using the parsed data.** From your JSON and logs, write:

   ```
   SCANNER_IP=<the source with the most DROPs>
   SCANNED_PORTS=<how many distinct destination ports it has hit so far>
   WEB_TRANSPORT=<udp or tcp: how the web server sends>
   UNKNOWN_SOURCE=<the address of the unregistered device>
   ```

Check your work from the host: `./lab check syslog-collector`. The check looks at what is arriving
now, so keep the lab running while you check.

<details>
<summary>Hints</summary>

- `ss -ulnp`, `ss -tlnp`; `rsyslogd -N1`; `pkill rsyslogd; rsyslogd`
- Name your file so it sorts before `50-default.conf`, e.g. `10-siem.conf`
- One `if $fromhost-ip == "..." then { action(...) stop }` per device, then a final catch-all for
  `$fromhost-ip != "127.0.0.1"`
- A template for the unknown file that starts with `%fromhost-ip%`
- A `type="list"` template alternates `constant(value="...")` text (escape the JSON quotes as `\"`)
  with `property(name="msg" regex.type="ERE" regex.expression="DPT=([0-9]+)" regex.submatch="1")`
  pieces; check with `tail -n 3 /var/log/siem/firewall.json | jq .`
- `open error: Permission denied`: rsyslog drops its privileges and writes as user `syslog`
- `jq -r 'select(.action == "DROP") | .src' /var/log/siem/firewall.json | sort | uniq -c | sort -rn`

</details>

## My notes

<!-- Screenshots: ./lab shot syslog-collector ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [splunk-search-basics](../splunk-search-basics/): the search side of a SIEM
- [logs-journald](../logs-journald/): logs on a single host
- [tcp-connections](../tcp-connections/): `ss` and listening sockets
- `man rsyslogd`, rsyslog docs (RainerScript, templates, imudp/imtcp), RFC 3164 and RFC 5424
